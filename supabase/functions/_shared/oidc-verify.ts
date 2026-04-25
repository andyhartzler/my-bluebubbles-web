// Verifies a Google-signed OIDC JWT on the `Authorization: Bearer ...` header.
// Used by mail-pubsub-receiver to assert that a push request actually came
// from Google's Pub/Sub service via our configured push-auth service account.
//
// Reference: https://cloud.google.com/pubsub/docs/push#authentication
//
// On failure returns a Response (401/403) so the caller can early-return.
// On success returns null.

interface JwksKey {
  kty: string;
  alg: string;
  kid: string;
  n: string;
  e: string;
  use?: string;
}

interface JwksCache {
  keys: Map<string, CryptoKey>;
  fetchedAt: number;
}

const GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs";
const JWKS_TTL_MS = 60 * 60 * 1000;
let jwksCache: JwksCache | null = null;

function b64urlDecode(s: string): Uint8Array {
  const pad = "=".repeat((4 - (s.length % 4)) % 4);
  const b64 = (s + pad).replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

function b64urlDecodeText(s: string): string {
  return new TextDecoder().decode(b64urlDecode(s));
}

async function loadJwks(): Promise<Map<string, CryptoKey>> {
  const now = Date.now();
  if (jwksCache && now - jwksCache.fetchedAt < JWKS_TTL_MS) {
    return jwksCache.keys;
  }
  const res = await fetch(GOOGLE_JWKS_URL);
  if (!res.ok) throw new Error(`JWKS fetch failed: ${res.status}`);
  const { keys } = (await res.json()) as { keys: JwksKey[] };
  const map = new Map<string, CryptoKey>();
  for (const jwk of keys) {
    if (jwk.kty !== "RSA" || jwk.alg !== "RS256") continue;
    const key = await crypto.subtle.importKey(
      "jwk",
      { kty: jwk.kty, alg: jwk.alg, n: jwk.n, e: jwk.e, use: jwk.use ?? "sig", ext: true },
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
    map.set(jwk.kid, key);
  }
  jwksCache = { keys: map, fetchedAt: now };
  return map;
}

interface VerifyOptions {
  expectedAudience: string;
  expectedEmail: string;
  /** Allowed clock skew in seconds. Defaults to 60. */
  clockSkewSeconds?: number;
}

/**
 * Verifies the bearer token on `req`. Returns null on success, Response on
 * failure. Caller should early-return any non-null result.
 */
export async function verifyPubsubOidc(
  req: Request,
  opts: VerifyOptions,
): Promise<Response | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "missing_auth" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  const jwt = authHeader.slice(7).trim();
  const parts = jwt.split(".");
  if (parts.length !== 3) {
    return new Response(JSON.stringify({ error: "malformed_jwt" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  const [headerB64, payloadB64, sigB64] = parts;

  let header: { alg?: string; kid?: string; typ?: string };
  let payload: Record<string, unknown>;
  try {
    header = JSON.parse(b64urlDecodeText(headerB64));
    payload = JSON.parse(b64urlDecodeText(payloadB64));
  } catch {
    return new Response(JSON.stringify({ error: "malformed_jwt" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (header.alg !== "RS256" || !header.kid) {
    return new Response(JSON.stringify({ error: "bad_alg" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const keys = await loadJwks();
  const key = keys.get(header.kid);
  if (!key) {
    return new Response(JSON.stringify({ error: "unknown_kid" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signature = b64urlDecode(sigB64);
  const ok = await crypto.subtle.verify(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    signature,
    signingInput,
  );
  if (!ok) {
    return new Response(JSON.stringify({ error: "bad_signature" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const skew = opts.clockSkewSeconds ?? 60;
  const now = Math.floor(Date.now() / 1000);
  const iss = payload.iss as string | undefined;
  const aud = payload.aud as string | undefined;
  const email = payload.email as string | undefined;
  const emailVerified = payload.email_verified as boolean | undefined;
  const iat = payload.iat as number | undefined;
  const exp = payload.exp as number | undefined;

  if (
    iss !== "https://accounts.google.com" &&
    iss !== "accounts.google.com"
  ) {
    return new Response(JSON.stringify({ error: "bad_iss" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (aud !== opts.expectedAudience) {
    return new Response(JSON.stringify({ error: "bad_aud" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (email !== opts.expectedEmail || emailVerified !== true) {
    return new Response(JSON.stringify({ error: "bad_email" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (typeof exp !== "number" || exp + skew < now) {
    return new Response(JSON.stringify({ error: "expired" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (typeof iat !== "number" || iat - skew > now) {
    return new Response(JSON.stringify({ error: "issued_in_future" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  return null;
}
