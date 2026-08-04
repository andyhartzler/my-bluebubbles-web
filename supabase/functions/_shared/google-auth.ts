// Mints a Google OAuth access token via service-account JWT + DWD
// impersonation. Caches per (subject, scopes) for ~50 minutes, well
// inside the 1-hour token lifetime.

interface CachedToken {
  token: string;
  expiresAt: number;
}
const cache = new Map<string, CachedToken>();

function b64url(s: string): string {
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function rsaSign(key: CryptoKey, data: Uint8Array): Promise<string> {
  const sig = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    data,
  );
  let bin = "";
  const bytes = new Uint8Array(sig);
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return b64url(bin);
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const der = pem
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
  const buf = Uint8Array.from(atob(der), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    buf,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

export interface GoogleAuthOptions {
  subject: string;
  scopes: string[];
}

export async function getGoogleAccessToken(
  opts: GoogleAuthOptions,
): Promise<string> {
  const cacheKey = `${opts.subject}|${opts.scopes.slice().sort().join(",")}`;
  const now = Math.floor(Date.now() / 1000);
  const cached = cache.get(cacheKey);
  if (cached && cached.expiresAt > now + 60) return cached.token;

  const sa = JSON.parse(Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON")!);
  const header = { alg: "RS256", typ: "JWT", kid: sa.private_key_id };
  const claim = {
    iss: sa.client_email,
    sub: opts.subject,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: opts.scopes.join(" "),
  };
  const encoder = new TextEncoder();
  const headerB64 = b64url(JSON.stringify(header));
  const claimB64 = b64url(JSON.stringify(claim));
  const signingInput = `${headerB64}.${claimB64}`;
  const key = await importPrivateKey(sa.private_key);
  const sig = await rsaSign(key, encoder.encode(signingInput));
  const jwt = `${signingInput}.${sig}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`Token exchange failed: ${res.status} ${await res.text()}`);
  }
  const data = await res.json();
  const token: string = data.access_token;
  cache.set(cacheKey, { token, expiresAt: now + (data.expires_in ?? 3600) });
  return token;
}
