-- Second half of the view leak. 20260807_11 revoked `anon`, closing the
-- unauthenticated breach. These eight views were still readable in bulk by the
-- `authenticated` role, 494 confirmed accounts in auth.users, and executed as their
-- postgres owner so RLS on members, subscribers, donors and donations never applied.
--
-- That audience is not the membership. trigger_auto_create_auth_user mints a
-- confirmed auth.users row for every person a chartering roster upload creates, so
-- the set includes people who never signed up and were never told an account exists.
--
-- security_invoker = true makes each view run as its caller so the base-table RLS
-- decides. NOTE: this alone did NOT close the exposure, because the policies
-- themselves were gated on an is_staff() that admitted 273 of 419 members. That is
-- fixed in 20260807_13, which is the actual root cause. This migration is still
-- correct and is kept as defence in depth.
alter view public.members_with_slack             set (security_invoker = true);
alter view public.member_slack_activity          set (security_invoker = true);
alter view public.subscribers_summary            set (security_invoker = true);
alter view public.subscriber_email_engagement    set (security_invoker = true);
alter view public.donor_profile_contributions    set (security_invoker = true);
alter view public.hanaway_campaign_participants  set (security_invoker = true);
alter view public.v_member_job_activity          set (security_invoker = true);
alter view public.candidate_endorsement_responses set (security_invoker = true);
