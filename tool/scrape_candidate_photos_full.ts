// Comprehensive candidate-photo scraper.
//
// For every candidate without a photo, walks a priority list of sources:
//   1. Ballotpedia individual page → image-candidate-thumbnail filename
//      contains last name. Auto-trusted (high precision).
//   2. Bing Images with `"First Last" Missouri Democrat candidate` query,
//      requiring BOTH first AND last name to appear in the result tile's
//      title/desc. Auto-trusted (Bing's own indexing keys).
//   3. DuckDuckGo Images with the same name-verification.
//   4. Campaign website og:image — requires AI VISION validation that
//      the image is a single-person headshot of the candidate.
//   5. Social handles (linkedin, twitter, instagram, facebook) → unavatar.io
//      proxy → AI VISION validation.
//
// Validated image is downloaded, uploaded to the `candidate-photos` Supabase
// storage bucket as `{candidateId}.jpg`, and `candidates.photo_url` updated
// to the resulting public URL.
//
// Run: bun run comprehensive.ts
//
// Required env / hardcoded constants below — keep in sync with Obsidian
// Credentials-and-Secrets.md.

import { chromium, type Page } from 'playwright';
import { createClient } from '@supabase/supabase-js';

// ---- secrets (from .env / Obsidian vault) ------------------------------
const SUPABASE_URL = 'https://faajpcarasilbfndzkmd.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SR_KEY!;
const AI_KEY = process.env.AI_KEY!;
const AI_BASE = 'https://ai.hartzler.app/v1';

if (!SUPABASE_SERVICE_ROLE_KEY || !AI_KEY) {
  console.error('Missing SR_KEY or AI_KEY env vars.');
  process.exit(1);
}

const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface Candidate {
  id: string;
  name: string;
  first_name: string | null;
  last_name: string | null;
  ballotpedia_url: string | null;
  campaign_website: string | null;
  social_facebook: string | null;
  social_twitter: string | null;
  social_instagram: string | null;
  social_linkedin: string | null;
}

interface Hit {
  url: string;
  source: string;
  needsAi: boolean;
}

// ---- helpers -----------------------------------------------------------

function nameKey(c: Candidate) {
  return {
    first: (c.first_name || c.name.split(/\s+/)[0] || '').toLowerCase().trim(),
    last: (c.last_name || c.name.split(/\s+/).pop() || '').toLowerCase().trim(),
  };
}

function extractHandle(socialUrl: string | null, kind: 'twitter'|'instagram'|'facebook'|'linkedin'): string | null {
  if (!socialUrl) return null;
  // Already a handle?
  if (socialUrl.startsWith('@')) return socialUrl.slice(1);
  if (!/[\.\/]/.test(socialUrl)) return socialUrl;
  // Domain-style URL — pull last path segment
  try {
    const u = new URL(socialUrl.startsWith('http') ? socialUrl : 'https://' + socialUrl);
    const parts = u.pathname.split('/').filter(Boolean);
    if (kind === 'linkedin' && parts[0] === 'in' && parts[1]) return parts[1];
    return parts[parts.length - 1] || null;
  } catch {
    return null;
  }
}

async function fetchAsBase64(url: string): Promise<{b64: string; mime: string} | null> {
  try {
    const r = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'image/*,*/*;q=0.8',
      },
      redirect: 'follow',
    });
    if (!r.ok) return null;
    const buf = await r.arrayBuffer();
    if (buf.byteLength < 1024) return null; // sub-1KB usually a placeholder
    if (buf.byteLength > 8 * 1024 * 1024) return null; // > 8MB — skip
    const mime = r.headers.get('content-type') || 'image/jpeg';
    if (!mime.startsWith('image/')) return null;
    const b64 = Buffer.from(buf).toString('base64');
    return { b64, mime };
  } catch {
    return null;
  }
}

async function aiIsCandidatePhoto(b64: string, mime: string, name: string): Promise<boolean> {
  try {
    const r = await fetch(`${AI_BASE}/chat/completions`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${AI_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gemma4:latest',
        max_tokens: 8,
        messages: [{
          role: 'user',
          content: [
            {
              type: 'text',
              text: `Look at this image. Is it a portrait/headshot photo of a SINGLE person whose face is visible (not a logo, not a group, not a building, not a graphic)? The image is supposed to be of "${name}". You don't need to verify identity — just whether it is a real-person headshot suitable to use as a profile photo. Reply ONLY "yes" or "no".`,
            },
            { type: 'image_url', image_url: { url: `data:${mime};base64,${b64}` } },
          ],
        }],
      }),
    });
    if (!r.ok) return false;
    const data = await r.json() as any;
    const ans = (data.choices?.[0]?.message?.content || '').toLowerCase().trim();
    return ans.startsWith('yes');
  } catch {
    return false;
  }
}

// ---- scrapers ----------------------------------------------------------

async function tryBallotpedia(page: Page, c: Candidate): Promise<Hit | null> {
  if (!c.ballotpedia_url) return null;
  try {
    await page.goto(c.ballotpedia_url, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.waitForTimeout(1500);
    const { last } = nameKey(c);
    const url = await page.evaluate((lastName) => {
      const imgs = Array.from(document.querySelectorAll('img'));
      const candidates = imgs
        .map((img) => img.getAttribute('src') || '')
        .filter((s) => /s3\.amazonaws\.com\/ballotpedia-api4\/files\/thumbs\//.test(s))
        .filter((s) => !/SubmitPhoto|Silhouette|placeholder/i.test(s))
        .filter((s) => s.toLowerCase().includes(lastName));
      if (candidates.length === 0) return null;
      candidates.sort((a, b) => {
        const aw = parseInt(a.match(/thumbs\/(\d+)\//)?.[1] || '0', 10);
        const bw = parseInt(b.match(/thumbs\/(\d+)\//)?.[1] || '0', 10);
        return bw - aw;
      });
      return candidates[0];
    }, last);
    return url ? { url, source: 'ballotpedia', needsAi: false } : null;
  } catch {
    return null;
  }
}

async function tryBing(page: Page, c: Candidate): Promise<Hit | null> {
  try {
    const q = encodeURIComponent(`"${c.name}" Missouri candidate`);
    await page.goto(`https://www.bing.com/images/search?q=${q}&form=HDRSC2&safesearch=strict`, {
      waitUntil: 'domcontentloaded', timeout: 20000,
    });
    await page.waitForTimeout(2500);
    const { first, last } = nameKey(c);
    const url = await page.evaluate(({ first, last }) => {
      const anchors = Array.from(document.querySelectorAll('a.iusc'));
      for (const a of anchors.slice(0, 20)) {
        const m = a.getAttribute('m');
        if (!m) continue;
        try {
          const data = JSON.parse(m);
          const murl: string = data.murl || '';
          const hay = `${(data.desc || '').toLowerCase()} ${(data.t || '').toLowerCase()} ${(data.tt || '').toLowerCase()}`;
          if (!hay.includes(last) || !hay.includes(first)) continue;
          if (murl && /^https?:\/\//.test(murl) && /\.(jpg|jpeg|png|webp)/i.test(murl)) return murl;
        } catch {}
      }
      return null;
    }, { first, last });
    return url ? { url, source: 'bing', needsAi: false } : null;
  } catch {
    return null;
  }
}

async function tryDuckDuckGo(page: Page, c: Candidate): Promise<Hit | null> {
  try {
    const q = encodeURIComponent(`"${c.name}" Missouri candidate`);
    await page.goto(`https://duckduckgo.com/?q=${q}&iax=images&ia=images`, {
      waitUntil: 'domcontentloaded', timeout: 20000,
    });
    await page.waitForTimeout(3000);
    const { first, last } = nameKey(c);
    const url = await page.evaluate(({ first, last }) => {
      const anchors = Array.from(document.querySelectorAll('a[title]'));
      for (const a of anchors.slice(0, 30)) {
        const title = (a.getAttribute('title') || '').toLowerCase();
        if (!title.includes(last) || !title.includes(first)) continue;
        const img = a.querySelector('img');
        const src = img?.getAttribute('src') || '';
        if (!src || src.startsWith('data:')) continue;
        if (/duckduckgo|spice|ddg/i.test(src)) continue;
        if (/^https/.test(src)) return src;
      }
      return null;
    }, { first, last });
    return url ? { url, source: 'ddg', needsAi: false } : null;
  } catch {
    return null;
  }
}

async function tryCampaignWebsite(page: Page, c: Candidate): Promise<Hit | null> {
  if (!c.campaign_website) return null;
  let url = c.campaign_website;
  if (!url.startsWith('http')) url = 'https://' + url;
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.waitForTimeout(1500);
    // Try og:image first; fall back to the largest hero image on page.
    const found = await page.evaluate(() => {
      const og = document.querySelector('meta[property="og:image"]')?.getAttribute('content');
      if (og && /^https/.test(og)) return og;
      const tw = document.querySelector('meta[name="twitter:image"]')?.getAttribute('content');
      if (tw && /^https/.test(tw)) return tw;
      // Find the biggest image element near the page top
      const imgs = Array.from(document.querySelectorAll('img'))
        .map((i) => ({ src: i.currentSrc || i.getAttribute('src') || '', w: i.naturalWidth || i.width, h: i.naturalHeight || i.height }))
        .filter((x) => x.src && /^https/.test(x.src) && x.w >= 200 && x.h >= 200)
        .sort((a, b) => (b.w * b.h) - (a.w * a.h));
      return imgs[0]?.src || null;
    });
    return found ? { url: found, source: 'website', needsAi: true } : null;
  } catch {
    return null;
  }
}

function trySocial(c: Candidate): Hit | null {
  // unavatar.io serves a single avatar per platform handle.
  // Order: linkedin → twitter → instagram → facebook (most → least likely
  // to actually be the person).
  const handles: Array<[string, string | null]> = [
    ['linkedin', extractHandle(c.social_linkedin, 'linkedin')],
    ['twitter', extractHandle(c.social_twitter, 'twitter')],
    ['instagram', extractHandle(c.social_instagram, 'instagram')],
    ['facebook', extractHandle(c.social_facebook, 'facebook')],
  ];
  for (const [kind, handle] of handles) {
    if (!handle) continue;
    return { url: `https://unavatar.io/${kind}/${encodeURIComponent(handle)}`, source: `social:${kind}`, needsAi: true };
  }
  return null;
}

// ---- DB read/write -----------------------------------------------------

async function loadCandidates(): Promise<Candidate[]> {
  const all: Candidate[] = [];
  let page = 0;
  const pageSize = 1000;
  while (true) {
    const { data, error } = await sb
      .from('candidates')
      .select('id,name,first_name,last_name,ballotpedia_url,campaign_website,social_facebook,social_twitter,social_instagram,social_linkedin')
      .or('photo_url.is.null,photo_url.eq.')
      .order('name')
      .range(page * pageSize, (page + 1) * pageSize - 1);
    if (error) throw error;
    if (!data || data.length === 0) break;
    all.push(...(data as Candidate[]));
    if (data.length < pageSize) break;
    page++;
  }
  return all;
}

async function uploadAndAttach(c: Candidate, b64: string, mime: string): Promise<string | null> {
  const bytes = Buffer.from(b64, 'base64');
  const ext = mime.includes('png') ? 'png' : mime.includes('webp') ? 'webp' : 'jpg';
  const path = `${c.id}.${ext}`;
  const { error: upErr } = await sb.storage
    .from('candidate-photos')
    .uploadToSignedUrl
    ? // typescript narrowing — fall through to upload
      await sb.storage.from('candidate-photos').upload(path, bytes, {
        contentType: mime,
        upsert: true,
      })
    : await sb.storage.from('candidate-photos').upload(path, bytes, {
        contentType: mime,
        upsert: true,
      });
  if (upErr) {
    console.error(`upload error for ${c.name}:`, upErr.message);
    return null;
  }
  const { data: pub } = sb.storage.from('candidate-photos').getPublicUrl(path);
  const publicUrl = pub.publicUrl;
  const { error: updErr } = await sb
    .from('candidates')
    .update({ photo_url: publicUrl })
    .eq('id', c.id);
  if (updErr) {
    console.error(`update error for ${c.name}:`, updErr.message);
    return null;
  }
  return publicUrl;
}

// ---- main loop ---------------------------------------------------------

(async () => {
  const candidates = await loadCandidates();
  console.log(`loaded ${candidates.length} candidates without photos`);

  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    viewport: { width: 1280, height: 900 },
    locale: 'en-US',
  });
  const page = await ctx.newPage();

  let hits = 0;
  let misses = 0;
  let i = 0;

  for (const c of candidates) {
    i++;
    process.stdout.write(`[${i}/${candidates.length}] ${c.name} ... `);

    let chosen: Hit | null = null;

    chosen = await tryBallotpedia(page, c);
    if (!chosen) chosen = await tryBing(page, c);
    if (!chosen) chosen = await tryDuckDuckGo(page, c);
    if (!chosen) chosen = await tryCampaignWebsite(page, c);
    if (!chosen) chosen = trySocial(c);

    if (!chosen) {
      console.log('MISS');
      misses++;
      continue;
    }

    const dl = await fetchAsBase64(chosen.url);
    if (!dl) {
      console.log(`MISS (download failed: ${chosen.source} ${chosen.url.slice(0, 80)})`);
      misses++;
      continue;
    }

    if (chosen.needsAi) {
      const ok = await aiIsCandidatePhoto(dl.b64, dl.mime, c.name);
      if (!ok) {
        console.log(`MISS (AI rejected: ${chosen.source})`);
        misses++;
        continue;
      }
    }

    const publicUrl = await uploadAndAttach(c, dl.b64, dl.mime);
    if (!publicUrl) {
      console.log(`MISS (upload failed: ${chosen.source})`);
      misses++;
      continue;
    }
    console.log(`HIT [${chosen.source}] -> ${publicUrl.slice(-40)}`);
    hits++;
  }

  console.log(`\n=== DONE: ${hits} hits, ${misses} misses out of ${candidates.length} ===`);
  await browser.close();
})();
