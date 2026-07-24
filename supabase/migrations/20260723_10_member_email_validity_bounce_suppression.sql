-- Applied to prod 2026-07-23. Email bounce suppression.
--
-- Context: the job-alert queue (wedged since Jan) was unwedged earlier today
-- and drained a 10-day-old backlog to the whole roster, and some of those
-- addresses hard-bounce. This adds durable bounce tracking so a bounced
-- address is never emailed again, and a freshness window (in the
-- process-job-alert-queue edge function) so a stalled queue never blasts old
-- alerts.

-- 1. Members email-validity tracking.
alter table public.members
  add column if not exists email_valid boolean not null default true,
  add column if not exists email_bounced_at timestamptz,
  add column if not exists email_bounce_reason text;

-- 2. Job-alert enqueue skips hard-bounced members.
create or replace function public.queue_job_alerts(p_job_id uuid, p_template_id uuid)
 returns table(queued integer, total integer)
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_queued int := 0;
  v_total int := 0;
begin
  with inserted as (
    insert into job_notification_log (
      template_id, trigger_type, recipient_member_id, recipient_email,
      recipient_name, job_id, channel, status
    )
    select p_template_id, 'new_job_alert', m.id, m.email, m.name, p_job_id, 'email', 'pending'
    from members m
    where m.subscribed_to_job_alerts = true
      and m.email is not null
      and m.email_valid = true   -- skip addresses that have hard-bounced
      and not exists (
        select 1 from job_notification_log jnl
        where jnl.job_id = p_job_id
          and jnl.recipient_member_id = m.id
          and jnl.trigger_type = 'new_job_alert'
      )
    returning 1
  )
  select count(*) into v_queued from inserted;
  select count(*) into v_total from members
    where subscribed_to_job_alerts = true and email is not null and email_valid = true;
  return query select v_queued, v_total;
end;
$function$;

-- 3. One-time bounce cleanup applied 2026-07-23 from NDRs in andrew@'s inbox
-- (scanned via DWD service account). 4 members marked email_valid=false
-- (Allison Van Horn, Krish Patel, Dakota Tritinger, Urmil Patel); 3
-- subscribers set subscription_status='cleaned' (james@claycountydemocrats.org,
-- upatel79@laduceschools.net, zachary.mallory@redcross.org). The other ~29
-- bounced addresses were external contacts/candidates, not members/subscribers.
