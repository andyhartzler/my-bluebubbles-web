-- Slack app-configuration token: durable store + crash-safe rotation bookkeeping.
--
-- WHY THIS EXISTS
-- Slack app-config tokens (xoxe.xoxp-...) live 12 hours. Renewing them means
-- POSTing the refresh token to tooling.tokens.rotate, which returns a NEW access
-- token AND a NEW refresh token and IMMEDIATELY INVALIDATES THE OLD REFRESH
-- TOKEN. There is no way to ask Slack for the current pair afterwards. So if a
-- rotation succeeds at Slack and the new pair is not durably written, programmatic
-- access to the app configuration is lost permanently and a human has to mint a
-- new token by hand in the Slack UI.
--
-- The pair therefore lives in Vault (encrypted at rest, always-on, readable from a
-- pg_cron job body) rather than in a file on a laptop that sleeps.
--
-- BOTH TOKENS LIVE IN ONE SECRET, AS ONE JSON DOCUMENT, ON PURPOSE. Two secrets
-- would mean two writes, and a crash between them would leave a mismatched pair,
-- which is exactly as dead as losing the pair outright. One secret means one
-- UPDATE, so the pair can never be half-written.

-- ---------------------------------------------------------------------------
-- Attempt log. Written BEFORE Slack is called, so an interrupted rotation leaves
-- evidence rather than silence.
-- ---------------------------------------------------------------------------
create table if not exists public.slack_token_rotation_log (
  id            bigserial primary key,
  started_at    timestamptz not null default now(),
  finished_at   timestamptz,
  -- started       : we are about to call, or have called, Slack. Outcome unknown.
  -- persisted     : Slack rotated and the new pair is committed to Vault.
  -- slack_error   : Slack refused. The OLD pair is untouched and still valid.
  -- persist_failed: Slack rotated but the write failed. ACCESS IS LOST.
  -- watchdog_alarm: not a rotation; the health watchdog raising its hand.
  status        text not null default 'started'
                  check (status in ('started','persisted','slack_error','persist_failed','watchdog_alarm')),
  trigger_source text,
  slack_error   text,
  note          text,
  -- Fingerprints, never the tokens. Enough to prove the stored pair is the pair
  -- Slack just issued, without any value being printable.
  access_fp     text,
  refresh_fp    text,
  expires_at    timestamptz
);

create index if not exists slack_token_rotation_log_started_idx
  on public.slack_token_rotation_log (started_at desc);

alter table public.slack_token_rotation_log enable row level security;
-- No policies: service_role bypasses RLS, everyone else sees nothing. The table
-- holds no secrets, but it also has no reason to be public.

comment on table public.slack_token_rotation_log is
  'One row per Slack app-config token rotation attempt. A row left in status=started is an alarm: Slack may have rotated while the new pair was not written.';

-- ---------------------------------------------------------------------------
-- Fingerprint helper. Truncated sha256 so a fingerprint cannot be walked back to
-- a token, but two runs can still be compared for equality.
-- ---------------------------------------------------------------------------
create or replace function public.slack_token_fp(p_token text)
returns text
language sql
immutable
security definer
set search_path = public, extensions
as $$
  select case
           when p_token is null or p_token = '' then null
           else left(encode(extensions.digest(p_token, 'sha256'), 'hex'), 16)
         end;
$$;

revoke all on function public.slack_token_fp(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Read the stored pair. Returns the secret, so it is service_role only.
-- ---------------------------------------------------------------------------
create or replace function public.slack_config_token_get()
returns jsonb
language sql
stable
security definer
set search_path = public, vault
as $$
  select decrypted_secret::jsonb
    from vault.decrypted_secrets
   where name = 'slack_app_config_tokens';
$$;

revoke all on function public.slack_config_token_get() from public, anon, authenticated;
grant execute on function public.slack_config_token_get() to service_role;

-- ---------------------------------------------------------------------------
-- Write the pair AND close out the attempt, in one transaction.
--
-- This is the whole crash-safety story. A single `select
-- public.slack_config_token_put(...)` from PostgREST runs inside one implicit
-- transaction, so the Vault write and the log update commit together or not at
-- all. There is no state in which the log says "persisted" but the pair is old,
-- and none in which the pair is new but the log still says "started".
-- ---------------------------------------------------------------------------
create or replace function public.slack_config_token_put(
  p_access     text,
  p_refresh    text,
  p_expires_at timestamptz,
  p_attempt_id bigint default null,
  p_note       text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, vault
as $$
declare
  v_id      uuid;
  v_payload text;
begin
  -- Refuse to overwrite a working pair with something that cannot be a token.
  -- Storing garbage here is indistinguishable from losing the pair.
  if p_access is null or length(p_access) < 40 or p_access not like 'xoxe.xoxp-%' then
    raise exception 'refusing to store implausible access token (len=%)', coalesce(length(p_access), -1);
  end if;
  if p_refresh is null or length(p_refresh) < 40 or p_refresh not like 'xoxe-%' then
    raise exception 'refusing to store implausible refresh token (len=%)', coalesce(length(p_refresh), -1);
  end if;

  v_payload := jsonb_build_object(
    'access_token',  p_access,
    'refresh_token', p_refresh,
    'rotated_at',    now(),
    'expires_at',    p_expires_at
  )::text;

  select id into v_id from vault.secrets where name = 'slack_app_config_tokens';

  if v_id is null then
    perform vault.create_secret(
      v_payload,
      'slack_app_config_tokens',
      'Slack app-configuration token pair for app A09TR00J9UL, as JSON {access_token, refresh_token, rotated_at, expires_at}. Rotated unattended by the slack-token-rotate edge function. Both tokens live in this one secret so the pair can never be half-written.'
    );
  else
    perform vault.update_secret(v_id, v_payload);
  end if;

  if p_attempt_id is not null then
    update public.slack_token_rotation_log
       set status      = 'persisted',
           finished_at = now(),
           access_fp   = public.slack_token_fp(p_access),
           refresh_fp  = public.slack_token_fp(p_refresh),
           expires_at  = p_expires_at,
           note        = coalesce(p_note, note)
     where id = p_attempt_id;
  end if;

  return jsonb_build_object(
    'stored',      true,
    'access_fp',   public.slack_token_fp(p_access),
    'refresh_fp',  public.slack_token_fp(p_refresh),
    'expires_at',  p_expires_at
  );
end;
$$;

revoke all on function public.slack_config_token_put(text, text, timestamptz, bigint, text) from public, anon, authenticated;
grant execute on function public.slack_config_token_put(text, text, timestamptz, bigint, text) to service_role;

-- ---------------------------------------------------------------------------
-- Open an attempt. Separate call so the row exists BEFORE Slack is contacted.
-- ---------------------------------------------------------------------------
create or replace function public.slack_token_rotation_begin(p_source text default 'unknown')
returns bigint
language sql
security definer
set search_path = public
as $$
  insert into public.slack_token_rotation_log (status, trigger_source)
  values ('started', p_source)
  returning id;
$$;

revoke all on function public.slack_token_rotation_begin(text) from public, anon, authenticated;
grant execute on function public.slack_token_rotation_begin(text) to service_role;

create or replace function public.slack_token_rotation_fail(
  p_attempt_id bigint,
  p_status     text,
  p_error      text
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.slack_token_rotation_log
     set status      = p_status,
         finished_at = now(),
         slack_error = left(coalesce(p_error, ''), 2000)
   where id = p_attempt_id;
$$;

revoke all on function public.slack_token_rotation_fail(bigint, text, text) from public, anon, authenticated;
grant execute on function public.slack_token_rotation_fail(bigint, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- Store the Telegram alert credentials in Vault so the SQL watchdog can shout
-- without depending on the edge function it is watching. Seeded by the edge
-- function itself on its first run, so the values never pass through a human's
-- hands or a transcript.
-- ---------------------------------------------------------------------------
create or replace function public.ops_alert_credential_seed(p_name text, p_value text)
returns boolean
language plpgsql
security definer
set search_path = public, vault
as $$
declare v_id uuid;
begin
  if p_name not in ('telegram_alert_bot_token', 'telegram_alert_chat_id') then
    raise exception 'ops_alert_credential_seed refuses unknown name %', p_name;
  end if;
  if p_value is null or p_value = '' then
    return false;
  end if;
  select id into v_id from vault.secrets where name = p_name;
  if v_id is null then
    perform vault.create_secret(p_value, p_name,
      'Mirror of the edge-function secret of the same name, so SQL-only watchdogs can alert without the edge runtime.');
    return true;
  end if;
  return false;  -- already present; never overwrite from a caller
end;
$$;

revoke all on function public.ops_alert_credential_seed(text, text) from public, anon, authenticated;
grant execute on function public.ops_alert_credential_seed(text, text) to service_role;

-- ---------------------------------------------------------------------------
-- Health surface. This is what a human or a later session reads.
-- ---------------------------------------------------------------------------
create or replace view public.v_slack_token_rotation_health
with (security_invoker = true)
as
with last_ok as (
  select finished_at, expires_at, access_fp, refresh_fp
    from public.slack_token_rotation_log
   where status = 'persisted'
   order by finished_at desc
   limit 1
),
stuck as (
  select count(*) as n
    from public.slack_token_rotation_log
   where status = 'started'
     and started_at < now() - interval '15 minutes'
),
broken as (
  select count(*) as n
    from public.slack_token_rotation_log
   where status = 'persist_failed'
     and started_at > now() - interval '7 days'
)
select
  (select finished_at from last_ok)                                      as last_success_at,
  round(extract(epoch from (now() - (select finished_at from last_ok))) / 3600.0, 2)
                                                                          as hours_since_success,
  (select expires_at from last_ok)                                        as token_expires_at,
  round(extract(epoch from ((select expires_at from last_ok) - now())) / 3600.0, 2)
                                                                          as hours_to_expiry,
  (select access_fp from last_ok)                                         as access_fp,
  (select refresh_fp from last_ok)                                        as refresh_fp,
  (select n from stuck)                                                   as stuck_attempts,
  (select n from broken)                                                  as persist_failures_7d,
  case
    when (select n from broken) > 0                     then 'LOST'
    when (select n from stuck) > 0                      then 'STUCK'
    when (select finished_at from last_ok) is null      then 'NEVER'
    when (select expires_at from last_ok) < now()       then 'EXPIRED'
    when (select finished_at from last_ok) < now() - interval '6 hours' then 'STALE'
    else 'OK'
  end                                                                     as status;

comment on view public.v_slack_token_rotation_health is
  'Slack app-config token rotation health. LOST means a rotation succeeded at Slack but the pair was not stored and a human must mint a new token by hand. STUCK means an attempt never reported back and may have done the same.';

revoke all on public.v_slack_token_rotation_health from anon;

-- ---------------------------------------------------------------------------
-- Watchdog. SQL only, no edge-function dependency, so it still fires when the
-- thing it is watching is the thing that is down.
-- ---------------------------------------------------------------------------
create or replace function public.fn_slack_token_rotation_watchdog()
returns text
language plpgsql
security definer
set search_path = public, vault, net
as $$
declare
  v_status  text;
  v_health  record;
  v_recent  boolean;
  v_token   text;
  v_chat    text;
  v_msg     text;
begin
  select * into v_health from public.v_slack_token_rotation_health;
  v_status := v_health.status;

  if v_status = 'OK' then
    return 'OK';
  end if;

  -- One alarm row per hour, so a sustained outage does not spam.
  select exists (
    select 1 from public.slack_token_rotation_log
     where status = 'watchdog_alarm'
       and started_at > now() - interval '1 hour'
  ) into v_recent;

  if v_recent then
    return v_status || ' (already alarmed within the hour)';
  end if;

  v_msg := 'MOYD Slack app-config token rotation is ' || v_status || E'.\n'
        || 'last success: ' || coalesce(v_health.last_success_at::text, 'never')
        || ' (' || coalesce(v_health.hours_since_success::text, 'n/a') || 'h ago)' || E'\n'
        || 'token expires: ' || coalesce(v_health.token_expires_at::text, 'unknown') || E'\n'
        || 'stuck attempts: ' || v_health.stuck_attempts
        || ', persist failures (7d): ' || v_health.persist_failures_7d || E'\n'
        || 'If this says LOST or STUCK, programmatic Slack app-config access may be gone '
        || 'and a new token must be generated by hand at api.slack.com/authentication/config-tokens.';

  insert into public.slack_token_rotation_log (status, trigger_source, note, finished_at)
  values ('watchdog_alarm', 'watchdog', left(v_msg, 2000), now());

  select decrypted_secret into v_token from vault.decrypted_secrets where name = 'telegram_alert_bot_token';
  select decrypted_secret into v_chat  from vault.decrypted_secrets where name = 'telegram_alert_chat_id';

  if v_token is not null and v_chat is not null then
    perform net.http_post(
      url     := 'https://api.telegram.org/bot' || v_token || '/sendMessage',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body    := jsonb_build_object('chat_id', v_chat, 'text', v_msg)
    );
  end if;

  return v_status || ' (alarm raised)';
end;
$$;

revoke all on function public.fn_slack_token_rotation_watchdog() from public, anon, authenticated;
