import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.203.0/testing/asserts.ts";
import { FakeTime } from "https://deno.land/std@0.203.0/testing/time.ts";
import {
  buildEmailInboxRecord,
  extractHeader,
  firstEmailAddress,
  handleRequest,
  parseEmailAddresses,
  resolveMemberId,
} from "./index.ts";
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.1";

type MaybeSingleResult<T> = Promise<{ data: T | null; error: { message: string } | null }>;

class StubQuery<T> {
  constructor(private readonly response: { data: T | null; error: { message: string } | null }) {}

  select(): StubQuery<T> {
    return this;
  }

  or(): StubQuery<T> {
    return this;
  }

  limit(): StubQuery<T> {
    return this;
  }

  maybeSingle(): MaybeSingleResult<T> {
    return Promise.resolve(this.response);
  }
}

class StubSupabaseClient<T> {
  constructor(private readonly response: { data: T | null; error: { message: string } | null }) {}

  from(): StubQuery<T> {
    return new StubQuery<T>(this.response);
  }
}

function createTestLogger() {
  const messages: string[] = [];
  return {
    messages,
    logger: {
      info: (message: string) => messages.push(`info:${message}`),
      warn: (message: string) => messages.push(`warn:${message}`),
      error: (message: string) => messages.push(`error:${message}`),
    },
  };
}

type GmailHeader = { name?: string; value?: string };

Deno.test("parseEmailAddresses normalizes and deduplicates", () => {
  const result = parseEmailAddresses("Alice <Alice@example.com>, bob@example.com, Bob@example.com");
  assertEquals(result, ["alice@example.com", "bob@example.com"]);
});

Deno.test("firstEmailAddress returns the first parsed entry", () => {
  const result = firstEmailAddress("Alice <alice@example.com>, bob@example.com");
  assertEquals(result, "alice@example.com");
});

Deno.test("extractHeader handles missing values", () => {
  const message = {
    id: "msg-1",
    payload: {
      headers: [
        { name: "Subject", value: "Hello" },
      ] as GmailHeader[],
    },
  };

  assertEquals(extractHeader(message as unknown as any, "Subject"), "Hello");
  assertEquals(extractHeader(message as unknown as any, "From"), null);
});

Deno.test("buildEmailInboxRecord populates Supabase payload", async () => {
  const time = new FakeTime("2023-09-15T00:00:00.000Z");
  try {
    const supabase = new StubSupabaseClient<{ id: string }>({ data: { id: "member-123" }, error: null });
    const { logger, messages } = createTestLogger();
    const message = {
      id: "msg-123",
      threadId: "thread-456",
      historyId: "789",
      internalDate: `${Date.parse("2023-09-14T12:00:00.000Z")}`,
      labelIds: ["INBOX"],
      snippet: "Snippet text",
      payload: {
        headers: [
          { name: "Subject", value: "Test Subject" },
          { name: "From", value: "Alice <alice@example.com>" },
          { name: "To", value: "Bob <bob@example.com>" },
          { name: "Cc", value: "cc@example.com" },
          { name: "Bcc", value: "bcc@example.com" },
          { name: "Date", value: "Thu, 14 Sep 2023 12:00:00 +0000" },
          { name: "Message-ID", value: "<message@example.com>" },
          { name: "References", value: "<ref@example.com>" },
          { name: "In-Reply-To", value: "<reply@example.com>" },
        ] as GmailHeader[],
      },
    };

    const record = await buildEmailInboxRecord(
      supabase as unknown as SupabaseClient,
      message as unknown as any,
      logger,
    );

    assertEquals(record.gmail_message_id, "msg-123");
    assertEquals(record.gmail_thread_id, "thread-456");
    assertEquals(record.history_id, "789");
    assertEquals(record.snippet, "Snippet text");
    assertEquals(record.subject, "Test Subject");
    assertEquals(record.from_address, "alice@example.com");
    assertEquals(record.to_address, ["bob@example.com"]);
    assertEquals(record.cc_address, ["cc@example.com"]);
    assertEquals(record.bcc_address, ["bcc@example.com"]);
    assertEquals(record.message_id, "msg-123");
    assertEquals(record.message_id_header, "<message@example.com>");
    assertEquals(record.references_header, "<ref@example.com>");
    assertEquals(record.in_reply_to, "<reply@example.com>");
    assertEquals(record.in_reply_to_header, "<reply@example.com>");
    assertEquals(record.date, "2023-09-14T12:00:00.000Z");
    assertEquals(record.received_at, "2023-09-14T12:00:00.000Z");
    assertEquals(record.internal_date, "2023-09-14T12:00:00.000Z");
    assertEquals(record.label_ids, ["INBOX"]);
    assertEquals(record.member_id, "member-123");
    assertEquals(record.synced_at, "2023-09-15T00:00:00.000Z");
    assertStringIncludes(messages[0], "info:Resolved member for email");
  } finally {
    time.restore();
  }
});

Deno.test("resolveMemberId logs and returns null when lookup fails", async () => {
  const supabase = new StubSupabaseClient<{ id: string }>({ data: null, error: { message: "not found" } });
  const { logger, messages } = createTestLogger();

  const memberId = await resolveMemberId(
    supabase as unknown as SupabaseClient,
    "missing@example.com",
    logger,
  );

  assertEquals(memberId, null);
  assertStringIncludes(messages.at(-1) ?? "", "warn:Failed to resolve member for email");
});

Deno.test("handleRequest responds to OPTIONS with CORS headers", async () => {
  const request = new Request("https://example.com", {
    method: "OPTIONS",
    headers: {
      Origin: "https://app.example.com",
      "Access-Control-Request-Headers": "X-Test-Header",
    },
  });

  const response = await handleRequest(request);

  assertEquals(response.status, 204);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "https://app.example.com");
  assertEquals(response.headers.get("Access-Control-Allow-Methods"), "POST, OPTIONS");
  assertStringIncludes(response.headers.get("Access-Control-Allow-Headers") ?? "", "x-test-header");
});

