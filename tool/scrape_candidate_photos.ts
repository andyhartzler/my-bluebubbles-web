// Headless scraper for missing Young Dem candidate photos.
//
// Strategy per candidate:
//   1. Try Ballotpedia individual page (`https://ballotpedia.org/{slug}`).
//      Look for an `image-candidate-thumbnail` <img> whose URL contains the
//      candidate's last name (filters out other candidates in the same race).
//      Filter out the SubmitPhoto silhouette placeholder.
//   2. If Ballotpedia is empty/silhouette, fall back to Google Images search
//      for "{name} Missouri Democrat candidate" and grab the first non-stock
//      result.
//
// Output: prints one line per hit as `{candidateId}\t{imageUrl}` to stdout.
// Apply with the supabase MCP `apply_migration` / `execute_sql` after review.

import { chromium, type Page } from 'playwright';

interface Candidate {
  id: string;
  name: string;
  ballotpediaUrl: string;
  lastName: string;
}

const CANDIDATES: Candidate[] = [
  { id: '028f2159-4f38-45f6-8737-111c270d7d3f', name: 'Amber Teson', ballotpediaUrl: 'https://ballotpedia.org/Amber_Teson', lastName: 'Teson' },
  { id: '7faa0336-4a19-49b3-be22-2270cc4a2bf3', name: 'Bradley Bos', ballotpediaUrl: 'https://ballotpedia.org/Bradley_Bos', lastName: 'Bos' },
  { id: '736def84-c334-4641-88b7-dcc45e73ed5c', name: 'Cat Clayton', ballotpediaUrl: 'https://ballotpedia.org/Cat_Clayton', lastName: 'Clayton' },
  { id: '60e6eb61-ff19-49a1-9927-afe8df382b67', name: 'Dustin Charles Lloyd', ballotpediaUrl: 'https://ballotpedia.org/Dustin_Charles_Lloyd', lastName: 'Lloyd' },
  { id: '839ed43b-4a75-4401-b9da-d2a438725d78', name: 'Eli Flowers', ballotpediaUrl: 'https://ballotpedia.org/Eli_Flowers', lastName: 'Flowers' },
  { id: 'cd35cd82-2418-4ad2-8ea8-fee7cc44aa6b', name: 'John Michael (Johnny) Chiles', ballotpediaUrl: 'https://ballotpedia.org/John_Michael_(Johnny)_Chiles', lastName: 'Chiles' },
  { id: '49b81cd6-8103-4a52-87ad-08cff805c990', name: 'K. Grant', ballotpediaUrl: 'https://ballotpedia.org/K._Grant', lastName: 'Grant' },
  { id: '8c39bb85-f1d3-44af-a1cb-73dd5059ee53', name: 'Karissa Marie Varga', ballotpediaUrl: 'https://ballotpedia.org/Karissa_Varga', lastName: 'Varga' },
  { id: 'd0923be7-c06a-475d-9db6-dd53e161c553', name: 'Kennedy Moore', ballotpediaUrl: 'https://ballotpedia.org/Kennedy_Moore', lastName: 'Moore' },
  { id: 'da781b05-1ef0-45be-9273-5ca2a6a482ca', name: 'Mike Sager', ballotpediaUrl: 'https://ballotpedia.org/Mike_Sager', lastName: 'Sager' },
  { id: '863264ad-4633-4f15-b746-ba3a88e3a640', name: 'Mitch Mullvain', ballotpediaUrl: 'https://ballotpedia.org/Mitch_Mullvain', lastName: 'Mullvain' },
  { id: 'dd548ec3-9b3c-450b-b1cb-5c94085d2a8a', name: 'Noah Worcester', ballotpediaUrl: 'https://ballotpedia.org/Noah_Worcester', lastName: 'Worcester' },
  { id: '5830099e-eb87-4c75-8c7f-f4698dee0923', name: 'Thomas D McBeth', ballotpediaUrl: 'https://ballotpedia.org/Thomas_D_McBeth', lastName: 'McBeth' },
  { id: '0fc4aa4b-a1ec-4648-ba4d-4de6183dae85', name: 'Trent Davis', ballotpediaUrl: 'https://ballotpedia.org/Trent_Davis', lastName: 'Davis' },
  { id: 'fda97e58-cb31-4a4b-939c-4055518b1dab', name: 'Trent Leslie', ballotpediaUrl: 'https://ballotpedia.org/Trent_Leslie', lastName: 'Leslie' },
  { id: 'aaa3aafd-cd14-4c89-b9e9-f9e713ec039b', name: 'Tristan Sutton', ballotpediaUrl: 'https://ballotpedia.org/Tristan_Sutton', lastName: 'Sutton' },
];

async function tryBallotpedia(page: Page, c: Candidate): Promise<string | null> {
  try {
    await page.goto(c.ballotpediaUrl, { waitUntil: 'domcontentloaded', timeout: 20000 });
    // Wait briefly for JS to settle
    await page.waitForTimeout(1500);

    const lastNameLower = c.lastName.toLowerCase();
    const url = await page.evaluate((lastName) => {
      // Look at every img whose src contains a Ballotpedia API thumbnail.
      // Filter out placeholder silhouettes. Prefer the LARGEST size dimension.
      const imgs = Array.from(document.querySelectorAll('img.image-candidate-thumbnail, img'));
      const candidates = imgs
        .map((img) => img.getAttribute('src') || '')
        .filter((s) => /s3\.amazonaws\.com\/ballotpedia-api4\/files\/thumbs\//.test(s))
        .filter((s) => !/SubmitPhoto|Silhouette|placeholder/i.test(s))
        .filter((s) => s.toLowerCase().includes(lastName));
      if (candidates.length === 0) return null;
      // Pick the one with the largest WxH in the URL (matches /thumbs/W/H/...)
      candidates.sort((a, b) => {
        const aw = parseInt(a.match(/thumbs\/(\d+)\//)?.[1] || '0', 10);
        const bw = parseInt(b.match(/thumbs\/(\d+)\//)?.[1] || '0', 10);
        return bw - aw;
      });
      return candidates[0];
    }, lastNameLower);
    return url;
  } catch (e) {
    return null;
  }
}

async function tryBingImages(page: Page, c: Candidate): Promise<string | null> {
  try {
    const q = encodeURIComponent(`"${c.name}" Missouri Democrat candidate`);
    await page.goto(`https://www.bing.com/images/search?q=${q}&form=HDRSC2&safesearch=strict`, {
      waitUntil: 'domcontentloaded',
      timeout: 20000,
    });
    await page.waitForTimeout(2500);

    // Verify the result page actually mentions the candidate. If the
    // candidate's name doesn't appear in the result tiles' alt/title text,
    // Bing has fallen back to "MO Democrat" results that are someone else.
    const lastNameLower = c.lastName.toLowerCase();
    const firstNameLower = c.name.split(/\s+/)[0].toLowerCase();
    const url = await page.evaluate(({ first, last }) => {
      // Bing wraps each result in an `a.iusc` whose `m` data attribute is a
      // JSON blob containing { murl, desc, t, ... }.
      const anchors = Array.from(document.querySelectorAll('a.iusc'));
      for (const a of anchors.slice(0, 20)) {
        const m = a.getAttribute('m');
        if (!m) continue;
        try {
          const data = JSON.parse(m);
          const murl: string = data.murl || '';
          const desc: string = (data.desc || '').toLowerCase();
          const t: string = (data.t || '').toLowerCase();
          const tt: string = (data.tt || '').toLowerCase();
          const hay = `${desc} ${t} ${tt}`;
          // Require BOTH the first name AND the last name appear in
          // the result text. This keeps Crystal Quade / generic MO Dem
          // header images from getting picked for every candidate.
          if (!hay.includes(last) || !hay.includes(first)) continue;
          if (!murl) continue;
          if (/^https?:\/\//.test(murl) && /\.(jpg|jpeg|png|webp)/i.test(murl)) {
            return murl;
          }
        } catch {}
      }
      return null;
    }, { first: firstNameLower, last: lastNameLower });
    return url;
  } catch (e) {
    return null;
  }
}

async function tryDuckDuckGoImages(page: Page, c: Candidate): Promise<string | null> {
  try {
    const q = encodeURIComponent(`"${c.name}" Missouri Democrat candidate`);
    // DuckDuckGo's image search exposes a JSON token endpoint that returns
    // direct image URLs without needing JS-heavy rendering.
    await page.goto(`https://duckduckgo.com/?q=${q}&iax=images&ia=images`, {
      waitUntil: 'domcontentloaded',
      timeout: 20000,
    });
    await page.waitForTimeout(3000);

    const lastNameLower = c.lastName.toLowerCase();
    const firstNameLower = c.name.split(/\s+/)[0].toLowerCase();
    const url = await page.evaluate(({ first, last }) => {
      // DDG image tiles are anchors with a title attribute holding the
      // page heading. Require the candidate's first AND last name appear
      // before trusting the image as theirs.
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
    }, { first: firstNameLower, last: lastNameLower });
    return url;
  } catch (e) {
    return null;
  }
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    viewport: { width: 1280, height: 900 },
    locale: 'en-US',
  });
  const page = await ctx.newPage();

  for (const c of CANDIDATES) {
    let url: string | null = null;
    let source = 'none';
    url = await tryBallotpedia(page, c);
    if (url) source = 'ballotpedia';
    if (!url) {
      url = await tryBingImages(page, c);
      if (url) source = 'bing';
    }
    if (!url) {
      url = await tryDuckDuckGoImages(page, c);
      if (url) source = 'ddg';
    }
    if (url) {
      console.log(`HIT\t${c.id}\t${source}\t${c.name}\t${url}`);
    } else {
      console.log(`MISS\t${c.id}\t${c.name}`);
    }
  }

  await browser.close();
})();
