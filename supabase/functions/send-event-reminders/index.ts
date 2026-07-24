import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const BB_URL = Deno.env.get('BLUEBUBBLES_URL') || 'https://messages.moydchat.org';
const BB_PASSWORD = Deno.env.get('BLUEBUBBLES_PASSWORD') || '';

function normalizeToE164(phone: string): string | null {
  if (!phone) return null;
  const digits = phone.replace(/\D/g, '');
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith('1')) return `+${digits}`;
  return null;
}

function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  return new Intl.DateTimeFormat('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZone: 'America/Chicago',
  }).format(date);
}

async function fetchWithTimeout(url: string, options: RequestInit, timeoutMs = 10000): Promise<Response> {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { ...options, signal: controller.signal });
    return res;
  } finally {
    clearTimeout(id);
  }
}

async function sendBBText(phoneE164: string, message: string): Promise<{ ok: boolean; error?: string; method?: string }> {
  const chatGuid = `iMessage;-;${phoneE164}`;
  
  // Try 1: message/text (fast for existing chats)
  try {
    const res = await fetchWithTimeout(`${BB_URL}/api/v1/message/text?password=${BB_PASSWORD}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chatGuid, message }),
    }, 10000);
    if (res.ok) return { ok: true, method: 'message/text' };
    const errText = await res.text().catch(() => 'unknown');
    console.error(`BB message/text (${res.status}) for ${phoneE164}:`, errText.slice(0, 200));
  } catch (e) {
    console.error(`BB message/text timeout/error for ${phoneE164}:`, e.message || e);
  }

  // Try 2: chat/new with addresses (creates chat if needed)
  try {
    const res2 = await fetchWithTimeout(`${BB_URL}/api/v1/chat/new?password=${BB_PASSWORD}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        addresses: [phoneE164],
        message,
        service: 'iMessage',
      }),
    }, 10000);
    if (res2.ok) return { ok: true, method: 'chat/new' };
    const text = await res2.text().catch(() => 'unknown');
    console.error(`BB chat/new (${res2.status}) for ${phoneE164}:`, text.slice(0, 200));
    return { ok: false, error: `message/text+chat/new both failed. Last: ${res2.status}: ${text.slice(0, 100)}` };
  } catch (e) {
    console.error(`BB chat/new timeout/error for ${phoneE164}:`, e.message || e);
    return { ok: false, error: `both timed out: ${e.message || e}` };
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Validate BB_PASSWORD upfront
    if (!BB_PASSWORD) {
      const errMsg = 'BLUEBUBBLES_PASSWORD env var is empty or not set. Cannot send reminders.';
      console.error(errMsg);
      return new Response(JSON.stringify({ error: errMsg, bb_password_set: false }), {
        status: 503,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Parse request body for manual trigger
    let manualEventId: string | null = null;
    let forceType: '4h' | '30m' | null = null;
    try {
      const body = await req.json();
      if (body?.event_id) manualEventId = body.event_id;
      if (body?.type === '4h' || body?.type === '30m') forceType = body.type;
    } catch (_e) {}

    const now = new Date();
    const results: any = {
      timestamp: now.toISOString(),
      bb_password_set: true,
      bb_status: null as number | string | null,
      mode: manualEventId ? (forceType ? `force_${forceType}` : 'manual') : 'scheduled',
      events_4h_found: 0,
      events_30m_found: 0,
      reminders_4h: 0,
      reminders_30m: 0,
      attendees_processed: 0,
      errors: 0,
      error_details: [] as any[],
    };

    // BB connectivity test
    try {
      const bbTest = await fetchWithTimeout(`${BB_URL}/api/v1/server/info?password=${BB_PASSWORD}`, { method: 'GET' }, 5000);
      results.bb_status = bbTest.status;
      if (!bbTest.ok) {
        const bbErrText = await bbTest.text().catch(() => 'unknown');
        results.bb_error = `HTTP ${bbTest.status}: ${bbErrText.slice(0, 200)}`;
        console.error('BB connectivity check failed:', results.bb_error);
      }
    } catch (e) {
      results.bb_status = 'unreachable';
      results.bb_error = e.message || String(e);
      console.error('BB unreachable:', results.bb_error);
    }

    async function processReminders(
      events: any[],
      reminderType: '4h' | '30m',
      buildMessage: (event: any) => string,
      sentAtColumn: string
    ) {
      for (const event of events) {
        const { data: attendees, error: attErr } = await supabase
          .from('event_attendees')
          .select('id, member_id, guest_phone, guest_name')
          .eq('event_id', event.id)
          .eq('rsvp_status', 'attending')
          .is(sentAtColumn, null);

        if (attErr) {
          results.errors++;
          results.error_details.push({ type: 'attendee_query', event: event.title, error: attErr.message });
          continue;
        }

        const attendeeList = attendees || [];
        results.attendees_processed += attendeeList.length;
        console.log(`Event "${event.title}" (${reminderType}): ${attendeeList.length} attendees to notify`);

        for (const att of attendeeList) {
          let phoneE164: string | null = null;

          if (att.member_id) {
            const { data: m } = await supabase
              .from('members')
              .select('phone_e164, opt_out')
              .eq('id', att.member_id)
              .single();
            if (m?.opt_out) {
              results.error_details.push({ type: 'opted_out', name: att.guest_name });
              continue;
            }
            phoneE164 = m?.phone_e164 || null;
          }

          if (!phoneE164 && att.guest_phone) {
            phoneE164 = normalizeToE164(att.guest_phone);
          }

          if (!phoneE164) {
            results.error_details.push({ type: 'no_phone', name: att.guest_name });
            results.errors++;
            continue;
          }

          const message = buildMessage(event);
          const sendResult = await sendBBText(phoneE164, message);
          if (sendResult.ok) {
            await supabase
              .from('event_attendees')
              .update({ [sentAtColumn]: new Date().toISOString() })
              .eq('id', att.id);
            if (reminderType === '4h') results.reminders_4h++;
            else results.reminders_30m++;
            results.error_details.push({ type: 'sent', name: att.guest_name, method: sendResult.method });
          } else {
            results.errors++;
            results.error_details.push({ type: 'send_failed', name: att.guest_name, phone: phoneE164, error: sendResult.error });
          }
        }
      }
    }

    const build4hMessage = (event: any) => {
      const dateFormatted = formatDate(event.event_date);
      return `Reminder: ${event.title} is in 4 hours!\n\n${dateFormatted}\n${event.location || ''}\n${event.location_address || ''}\n\nSee you soon!`;
    };

    const build30mMessage = (event: any) => {
      return `Starting soon! ${event.title} begins in 30 minutes.\n\n${event.location || ''}\n${event.location_address || ''}`;
    };

    if (manualEventId) {
      // Manual/force trigger for a specific event
      const { data: manualEvent, error: evErr } = await supabase
        .from('events')
        .select('id, title, event_date, location, location_address')
        .eq('id', manualEventId)
        .single();

      if (evErr || !manualEvent) {
        return new Response(JSON.stringify({ error: 'Event not found', detail: evErr }), {
          status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      results.manual_event = manualEvent.title;

      if (forceType === '4h') {
        // Force send 4h reminders regardless of time window
        results.events_4h_found = 1;
        await processReminders([manualEvent], '4h', build4hMessage, 'reminder_4h_sent_at');
      } else if (forceType === '30m') {
        // Force send 30m reminders regardless of time window
        results.events_30m_found = 1;
        await processReminders([manualEvent], '30m', build30mMessage, 'reminder_30m_sent_at');
      } else {
        // Manual trigger without type: send 4h reminder (legacy behavior)
        results.events_4h_found = 1;
        await processReminders(
          [manualEvent],
          '4h',
          (event) => {
            const dateFormatted = formatDate(event.event_date);
            return `Reminder: ${event.title} is coming up today!\n\n${dateFormatted}\n${event.location || ''}\n${event.location_address || ''}\n\nSee you soon!`;
          },
          'reminder_4h_sent_at'
        );
      }
    } else {
      // Scheduled mode: check time windows
      // 4h window: 3h42m to 4h17m (wider than previous 3h45m-4h15m)
      const fourHourStart = new Date(now.getTime() + 3 * 60 * 60 * 1000 + 42 * 60 * 1000);
      const fourHourEnd = new Date(now.getTime() + 4 * 60 * 60 * 1000 + 17 * 60 * 1000);
      const { data: events4h } = await supabase
        .from('events')
        .select('id, title, event_date, location, location_address')
        .gte('event_date', fourHourStart.toISOString())
        .lte('event_date', fourHourEnd.toISOString())
        .eq('status', 'published');

      results.events_4h_found = events4h?.length ?? 0;
      results.window_4h = { from: fourHourStart.toISOString(), to: fourHourEnd.toISOString() };
      console.log(`4h window: ${fourHourStart.toISOString()} - ${fourHourEnd.toISOString()}, found ${results.events_4h_found} events`);

      await processReminders(events4h || [], '4h', build4hMessage, 'reminder_4h_sent_at');

      // 30m window: 13m to 47m (wider than previous 15m-45m)
      const thirtyMinStart = new Date(now.getTime() + 13 * 60 * 1000);
      const thirtyMinEnd = new Date(now.getTime() + 47 * 60 * 1000);
      const { data: events30m } = await supabase
        .from('events')
        .select('id, title, event_date, location, location_address')
        .gte('event_date', thirtyMinStart.toISOString())
        .lte('event_date', thirtyMinEnd.toISOString())
        .eq('status', 'published');

      results.events_30m_found = events30m?.length ?? 0;
      results.window_30m = { from: thirtyMinStart.toISOString(), to: thirtyMinEnd.toISOString() };
      console.log(`30m window: ${thirtyMinStart.toISOString()} - ${thirtyMinEnd.toISOString()}, found ${results.events_30m_found} events`);

      await processReminders(events30m || [], '30m', build30mMessage, 'reminder_30m_sent_at');
    }

    // Log summary
    console.log(`Results: 4h=${results.reminders_4h}, 30m=${results.reminders_30m}, errors=${results.errors}`);

    return new Response(JSON.stringify(results), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Fatal error:', error);
    return new Response(JSON.stringify({ error: error.message, stack: error.stack }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
