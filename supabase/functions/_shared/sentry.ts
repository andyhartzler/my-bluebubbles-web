// Shared Sentry wrapper for Edge Functions.
// Reports to the missouri-young-democrats/supabase-edge Sentry project.
// DSN comes from the SENTRY_DSN_EDGE secret; when unset (e.g. local serve
// without secrets), everything here is a transparent no-op.
//
// Usage:
//   import { withSentry } from "../_shared/sentry.ts";
//   serve(withSentry("my-function", async (req) => { ... }));

import * as Sentry from "npm:@sentry/deno@^9.24.0";

const dsn = Deno.env.get("SENTRY_DSN_EDGE") ?? "";

if (dsn) {
  Sentry.init({
    dsn,
    environment: "production",
    // Edge functions are short-lived; error monitoring only, no tracing.
    tracesSampleRate: 0,
  });
}

export { Sentry };

type Handler = (req: Request) => Promise<Response> | Response;

export function withSentry(fnName: string, handler: Handler): Handler {
  if (!dsn) return handler;
  return async (req: Request): Promise<Response> => {
    Sentry.setTag("function", fnName);
    Sentry.setTag(
      "region",
      Deno.env.get("SB_REGION") ?? Deno.env.get("DENO_REGION") ?? "unknown",
    );
    try {
      const res = await handler(req);
      // 5xx responses are handled-but-broken paths worth surfacing.
      if (res.status >= 500) {
        Sentry.captureMessage(
          `${fnName} responded ${res.status} ${req.method} ${new URL(req.url).pathname}`,
          "error",
        );
        await Sentry.flush(2000);
      }
      return res;
    } catch (e) {
      Sentry.captureException(e);
      // The isolate can be torn down right after the response; flush so the
      // event actually leaves the box before that happens.
      await Sentry.flush(2000);
      throw e;
    }
  };
}
