-- Repairs to the Slack app-config token rotation shipped earlier today, all
-- three found by review of 20260806_01. None of them break a live surface
-- today; all three are the kind that only show up on the day something else
-- has already gone wrong, which is the day this machinery exists for.
--
-- ---------------------------------------------------------------------------
-- 1. THE HEALTH VIEW COULD NOT RECOVER, AND SHADOWED EVERY LATER SIGNAL
--
-- The `stuck` CTE counted every row still at status='started' older than 15
-- minutes, with no upper bound and no relation to anything that happened
-- afterwards. The `broken` CTE counted every 'persist_failed' row in the last
-- seven days the same way. Because the CASE orders LOST > STUCK > NEVER >
-- EXPIRED > STALE > OK, a single orphaned attempt row pinned the view to STUCK
-- permanently, and one transient persist failure pinned it to LOST for a week,
-- INCLUDING ACROSS SUCCESSFUL ROTATIONS. Two consequences, both bad:
--
--   a) fn_slack_token_rotation_watchdog fires one Telegram message an hour for
--      as long as it lasts, for a condition that has already repaired itself.
--      An alarm that cries wolf for seven days is an alarm that gets muted.
--   b) While it is tripped the view CANNOT report EXPIRED or STALE, so a
--      genuinely dead token weeks later is indistinguishable from the stale
--      row. The surface built to make failure visible would be hiding it.
--
-- The fix is to scope both counts to attempts NEWER THAN THE LAST SUCCESSFUL
-- PERSIST. A completed rotation after the fact is positive proof that the
-- system recovered: the pair in the Vault is good and the refresh token works.
-- An older failure is then history, not a live condition, so the view drops
-- back to OK on its own and the watchdog goes quiet without anyone running a
-- manual UPDATE that nothing documented.
--
-- The historical counts are not thrown away; they move to their own columns so
-- a human reading the view still sees "this has failed 3 times this week"
-- without the status being held hostage to it.
--
-- ---------------------------------------------------------------------------
-- 2. A NULL EXPIRY SILENTLY DISABLED THE EXPIRED BRANCH
--
-- The test was `(select expires_at from last_ok) < now()`, which is NULL, not
-- true, when the expiry was never recorded, so the CASE fell through to STALE
-- or OK. Row id 1 (the original seed) carries expires_at NULL, so the state is
-- reachable. A token whose expiry was never captured would expire with the
-- view reporting OK for six hours and STALE after, never EXPIRED, and
-- hours_to_expiry reading null rather than negative. NULL now gets its own
-- status instead of being absorbed into the healthy one.
--
-- ---------------------------------------------------------------------------
-- 3. slack_config_token_put HAD NO COMPARE-AND-SWAP
--
-- It took a pair and overwrote the secret unconditionally, never checking that
-- the refresh token it was replacing was the one the caller had rotated FROM.
-- The reachable path is the edge function's persist retry loop: an attempt that
-- errors on the round trip AFTER the transaction actually committed sleeps and
-- rewrites, and if anything rotated in between, the newer refresh token is
-- clobbered and is already dead at Slack. Rows 4 and 5 in the log committed
-- 149 ms apart, each overwriting the other, so this is demonstrated rather
-- than theoretical. Health reported OK throughout; the loss would surface up
-- to three hours later as invalid_refresh_token.
--
-- p_expect_refresh_fp closes it. Note the ordering of the two guards below:
-- the IDEMPOTENT case is checked FIRST, because the retry loop's whole purpose
-- is to survive an ambiguous round trip, and "the pair I am trying to write is
-- already the pair that is stored" must read as success rather than as a
-- conflict. Only after that does a mismatch become an error.

-- ---------------------------------------------------------------------------
create or replace function public.slack_config_token_put(
  p_access            text,
  p_refresh           text,
  p_expires_at        timestamptz,
  p_attempt_id        bigint default null,
  p_note              text default null,
  p_expect_refresh_fp text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, vault
as $$
declare
  v_id       uuid;
  v_payload  text;
  v_current  jsonb;
  v_cur_ref  text;
begin
  -- Refuse to overwrite a working pair with something that cannot be a token.
  -- Storing garbage here is indistinguishable from losing the pair.
  if p_access is null or length(p_access) < 40 or p_access not like 'xoxe.xoxp-%' then
    raise exception 'refusing to store implausible access token (len=%)', coalesce(length(p_access), -1);
  end if;
  if p_refresh is null or length(p_refresh) < 40 or p_refresh not like 'xoxe-%' then
    raise exception 'refusing to store implausible refresh token (len=%)', coalesce(length(p_refresh), -1);
  end if;

  select decrypted_secret::jsonb into v_current
    from vault.decrypted_secrets
   where name = 'slack_app_config_tokens';
  v_cur_ref := v_current ->> 'refresh_token';

  -- IDEMPOTENT REPLAY. Checked before the CAS guard on purpose: if the stored
  -- refresh token is already the one being written, a previous attempt in this
  -- same retry loop committed and only its acknowledgement was lost. That is a
  -- success, not a conflict, and reporting it as a conflict would make the
  -- retry loop fail after it had already done its job, then raise a false
  -- "ACCESS LOST" alarm about a pair that is safely stored.
  if v_cur_ref is not null and v_cur_ref = p_refresh then
    if p_attempt_id is not null then
      update public.slack_token_rotation_log
         set status      = 'persisted',
             finished_at = coalesce(finished_at, now()),
             access_fp   = public.slack_token_fp(p_access),
             refresh_fp  = public.slack_token_fp(p_refresh),
             expires_at  = p_expires_at,
             note        = coalesce(p_note, note)
       where id = p_attempt_id;
    end if;
    return jsonb_build_object(
      'stored',     true,
      'idempotent', true,
      'access_fp',  public.slack_token_fp(p_access),
      'refresh_fp', public.slack_token_fp(p_refresh),
      'expires_at', p_expires_at
    );
  end if;

  -- COMPARE AND SWAP. Only enforced when the caller says what it expected to be
  -- replacing, so the recovery tool and a hand seed can still write without it.
  if p_expect_refresh_fp is not null
     and v_cur_ref is not null
     and public.slack_token_fp(v_cur_ref) <> p_expect_refresh_fp then
    raise exception
      'refusing to overwrite: stored refresh fp % is not the expected %; another rotation landed first',
      public.slack_token_fp(v_cur_ref), p_expect_refresh_fp;
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
    'stored',     true,
    'idempotent', false,
    'access_fp',  public.slack_token_fp(p_access),
    'refresh_fp', public.slack_token_fp(p_refresh),
    'expires_at', p_expires_at
  );
end;
$$;

-- The 5-argument signature is replaced, not kept alongside. Leaving it callable
-- would leave the un-guarded overwrite reachable, which is the whole defect.
drop function if exists public.slack_config_token_put(text, text, timestamptz, bigint, text);

revoke all on function public.slack_config_token_put(text, text, timestamptz, bigint, text, text) from public, anon, authenticated;
grant execute on function public.slack_config_token_put(text, text, timestamptz, bigint, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- Dropped rather than replaced: CREATE OR REPLACE VIEW cannot insert columns in
-- the middle of the column list, and the two new history columns belong next to
-- the counts they explain rather than tacked on after `status`.
drop view if exists public.v_slack_token_rotation_health;

create view public.v_slack_token_rotation_health
with (security_invoker = true)
as
with last_ok as (
  select finished_at, expires_at, access_fp, refresh_fp
    from public.slack_token_rotation_log
   where status = 'persisted'
   order by finished_at desc
   limit 1
),
-- Both of these are now scoped to "since the last success". A rotation that
-- completed after the failure is proof the system recovered.
stuck as (
  select count(*) as n
    from public.slack_token_rotation_log
   where status = 'started'
     and started_at < now() - interval '15 minutes'
     and started_at > coalesce((select finished_at from last_ok), '-infinity'::timestamptz)
),
broken as (
  select count(*) as n
    from public.slack_token_rotation_log
   where status = 'persist_failed'
     and started_at > now() - interval '7 days'
     and started_at > coalesce((select finished_at from last_ok), '-infinity'::timestamptz)
),
history as (
  select
    count(*) filter (where status = 'persist_failed' and started_at > now() - interval '7 days') as failed_7d,
    count(*) filter (where status = 'started'        and started_at < now() - interval '15 minutes') as orphaned_all
    from public.slack_token_rotation_log
)
select
  (select finished_at from last_ok)                                       as last_success_at,
  round(extract(epoch from (now() - (select finished_at from last_ok))) / 3600.0, 2)
                                                                          as hours_since_success,
  (select expires_at from last_ok)                                        as token_expires_at,
  round(extract(epoch from ((select expires_at from last_ok) - now())) / 3600.0, 2)
                                                                          as hours_to_expiry,
  (select access_fp from last_ok)                                         as access_fp,
  (select refresh_fp from last_ok)                                        as refresh_fp,
  (select n from stuck)                                                   as stuck_attempts,
  (select n from broken)                                                  as persist_failures_7d,
  -- Retained so a resolved failure is still legible to a human without it
  -- holding the status hostage.
  (select failed_7d from history)                                         as failed_7d_including_recovered,
  (select orphaned_all from history)                                      as orphaned_attempts_all_time,
  case
    when (select n from broken) > 0                       then 'LOST'
    when (select n from stuck) > 0                        then 'STUCK'
    when (select finished_at from last_ok) is null        then 'NEVER'
    -- Explicit, because NULL < now() is NULL and used to fall through to OK.
    when (select expires_at from last_ok) is null         then 'NO_EXPIRY'
    when (select expires_at from last_ok) < now()         then 'EXPIRED'
    when (select finished_at from last_ok) < now() - interval '6 hours' then 'STALE'
    else 'OK'
  end                                                                     as status;

comment on view public.v_slack_token_rotation_health is
  'Slack app-config token rotation health. LOST means a rotation succeeded at Slack but the pair was not stored and a human must mint a new token by hand. STUCK means an attempt never reported back and may have done the same. Both are scoped to failures NEWER than the last successful persist, so a later success clears them and the watchdog stops shouting on its own. NO_EXPIRY means the last success did not record an expiry, which is a gap in the record rather than a healthy token.';

revoke all on public.v_slack_token_rotation_health from anon;
