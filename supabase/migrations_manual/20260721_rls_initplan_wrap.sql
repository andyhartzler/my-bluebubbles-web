-- Generated 2026-07-21 from live pg_policies. Wraps STABLE auth-check calls in (SELECT ...)
-- so they evaluate once per statement (InitPlan) instead of per row. Approved by Andrew.
SET lock_timeout = '3s';
ALTER POLICY "rls_phase2_staff_all" ON public."ai_configuration" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Service role has full access to apple_wallet_registrations" ON public."apple_wallet_registrations" USING (((SELECT auth.role()) = 'service_role'::text));
ALTER POLICY "assn_delete" ON public."assignments" USING (((assigned_by = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "assn_insert" ON public."assignments" WITH CHECK (((SELECT is_staff()) AND (assigned_by IS NOT NULL) AND (assigned_by = (SELECT auth.uid()))));
ALTER POLICY "assn_select" ON public."assignments" USING (((assigned_to = (SELECT auth.uid())) OR (assigned_by = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "assn_update" ON public."assignments" USING (((assigned_to = (SELECT auth.uid())) OR (assigned_by = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin()))) WITH CHECK (((assigned_to = (SELECT auth.uid())) OR (assigned_by = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "audit_log_self_select" ON public."audit_log" USING ((actor_id = (SELECT auth.uid())));
ALTER POLICY "audit_log_superadmin_select" ON public."audit_log" USING ((SELECT current_user_is_superadmin()));
ALTER POLICY "rls_phase2_staff_all" ON public."bank_transactions" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."call_time_list_items" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."call_time_lists" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Users can create their own drafts" ON public."campaign_drafts" WITH CHECK (((SELECT auth.uid()) = user_id));
ALTER POLICY "Users can delete their own drafts" ON public."campaign_drafts" USING (((SELECT auth.uid()) = user_id));
ALTER POLICY "Users can update their own drafts" ON public."campaign_drafts" USING (((SELECT auth.uid()) = user_id)) WITH CHECK (((SELECT auth.uid()) = user_id));
ALTER POLICY "Users can view their own drafts" ON public."campaign_drafts" USING (((SELECT auth.uid()) = user_id));
ALTER POLICY "rls_phase2_staff_all" ON public."campaign_recipients" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Users can create templates" ON public."campaign_templates" WITH CHECK ((created_by = (SELECT auth.uid())));
ALTER POLICY "Users can delete their own templates" ON public."campaign_templates" USING ((created_by = (SELECT auth.uid())));
ALTER POLICY "Users can update their own templates" ON public."campaign_templates" USING ((created_by = (SELECT auth.uid()))) WITH CHECK ((created_by = (SELECT auth.uid())));
ALTER POLICY "Users can view public and own templates" ON public."campaign_templates" USING (((is_public = true) OR (created_by = (SELECT auth.uid()))));
ALTER POLICY "Users can delete their own campaigns" ON public."campaigns" USING ((created_by = (SELECT auth.uid())));
ALTER POLICY "Users can update their own campaigns" ON public."campaigns" USING ((created_by = (SELECT auth.uid()))) WITH CHECK ((created_by = (SELECT auth.uid())));
ALTER POLICY "rls_phase2_staff_all" ON public."candidate_contacts" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."candidate_endorsements" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."candidate_news" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "csc_delete" ON public."candidate_score_components" USING ((SELECT is_executive()));
ALTER POLICY "csc_exec_write" ON public."candidate_score_components" USING (((EXISTS ( SELECT 1
   FROM members m
  WHERE ((m.id = (SELECT auth.uid())) AND (m.executive_committee = true)))) OR (SELECT current_user_is_superadmin()))) WITH CHECK (((EXISTS ( SELECT 1
   FROM members m
  WHERE ((m.id = (SELECT auth.uid())) AND (m.executive_committee = true)))) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "csc_insert" ON public."candidate_score_components" WITH CHECK ((SELECT is_executive()));
ALTER POLICY "csc_update" ON public."candidate_score_components" USING ((SELECT is_executive())) WITH CHECK ((SELECT is_executive()));
ALTER POLICY "rls_phase2_staff_all" ON public."candidates" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Users can delete their own canvas boards" ON public."canvas_boards" USING ((created_by = (SELECT auth.uid())));
ALTER POLICY "rls_phase2_staff_all" ON public."chapter_documents" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."chapters" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Service role has full access to claim_tokens" ON public."claim_tokens" USING (((SELECT auth.role()) = 'service_role'::text));
ALTER POLICY "Authenticated can insert own diagnostics" ON public."client_diagnostics" WITH CHECK (((user_id = (SELECT auth.uid())) OR (user_id IS NULL)));
ALTER POLICY "Staff can read diagnostics" ON public."client_diagnostics" USING ((SELECT is_staff()));
ALTER POLICY "committees_staff_write" ON public."committees" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "dp_delete" ON public."dashboard_pages" USING (((user_id = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "dp_insert" ON public."dashboard_pages" WITH CHECK (((created_by = (SELECT auth.uid())) AND ((user_id = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin()))));
ALTER POLICY "dp_select" ON public."dashboard_pages" USING (((user_id = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "dp_update" ON public."dashboard_pages" USING (((user_id = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin()))) WITH CHECK (((user_id = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "rls_phase2_staff_all" ON public."district_demographics" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."donation_thank_yous" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Service role full access to donations" ON public."donations" USING (((SELECT auth.role()) = 'service_role'::text));
ALTER POLICY "rls_phase2_staff_all" ON public."donations" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."donor_activity_log" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."donor_call_outcomes" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."donor_contacts" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."donor_enrichment" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."donor_profiles" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."donor_tags" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Service role full access to donors" ON public."donors" USING (((SELECT auth.role()) = 'service_role'::text));
ALTER POLICY "rls_phase2_staff_all" ON public."donors" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."election_history" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."email_campaign_link_clicks" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."email_campaign_links" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."email_campaign_recipients" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."email_campaign_statistics" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."email_campaigns" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."email_cleanup_staging" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "email_inbox_staff_read" ON public."email_inbox" USING ((SELECT is_staff()));
ALTER POLICY "email_inbox_staff_write" ON public."email_inbox" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."email_log_members" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."email_logs" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."email_templates" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "endorsement_ai_scores_staff_read" ON public."endorsement_ai_scores" USING ((SELECT is_staff()));
ALTER POLICY "endorsement_decisions_staff_all" ON public."endorsement_decisions" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "endorsement_votes_own_write" ON public."endorsement_votes" USING (((SELECT is_staff()) AND (voter_id = (SELECT auth.uid())))) WITH CHECK (((SELECT is_staff()) AND (voter_id = (SELECT auth.uid()))));
ALTER POLICY "endorsement_votes_staff_read" ON public."endorsement_votes" USING ((SELECT is_staff()));
ALTER POLICY "event_attendees_staff_read" ON public."event_attendees" USING ((SELECT is_staff()));
ALTER POLICY "event_attendees_staff_write" ON public."event_attendees" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "events_staff_write" ON public."events" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Form creators can view analytics" ON public."form_analytics" USING ((EXISTS ( SELECT 1
   FROM form_schemas
  WHERE ((form_schemas.id = form_analytics.form_id) AND (form_schemas.created_by = (SELECT auth.uid()))))));
ALTER POLICY "Staff can view form drafts" ON public."form_drafts" USING ((SELECT is_staff()));
ALTER POLICY "auth_read_form_events" ON public."form_events" USING (((SELECT auth.role()) = 'authenticated'::text));
ALTER POLICY "Form creators can view field analytics" ON public."form_field_analytics" USING ((EXISTS ( SELECT 1
   FROM form_schemas
  WHERE ((form_schemas.id = form_field_analytics.form_id) AND (form_schemas.created_by = (SELECT auth.uid()))))));
ALTER POLICY "Form creators can view form files" ON public."form_files" USING ((EXISTS ( SELECT 1
   FROM form_schemas
  WHERE ((form_schemas.id = form_files.form_id) AND (form_schemas.created_by = (SELECT auth.uid()))))));
ALTER POLICY "Users can view own uploads" ON public."form_files" USING ((uploaded_by = (SELECT auth.uid())));
ALTER POLICY "Users can create forms" ON public."form_schemas" WITH CHECK ((created_by = (SELECT auth.uid())));
ALTER POLICY "Users can delete their own forms" ON public."form_schemas" USING ((created_by = (SELECT auth.uid())));
ALTER POLICY "Users can update their own forms" ON public."form_schemas" USING ((created_by = (SELECT auth.uid()))) WITH CHECK ((created_by = (SELECT auth.uid())));
ALTER POLICY "form_submissions_self_read" ON public."form_submissions" USING ((member_id = ( SELECT members.id
   FROM members
  WHERE (members.user_id = (SELECT auth.uid())))));
ALTER POLICY "form_submissions_staff_read" ON public."form_submissions" USING ((SELECT is_staff()));
ALTER POLICY "form_submissions_staff_write" ON public."form_submissions" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Users can create templates" ON public."form_templates" WITH CHECK ((created_by = (SELECT auth.uid())));
ALTER POLICY "Users can delete own templates" ON public."form_templates" USING (((created_by = (SELECT auth.uid())) AND (is_system = false)));
ALTER POLICY "Users can update own templates" ON public."form_templates" USING (((created_by = (SELECT auth.uid())) AND (is_system = false))) WITH CHECK ((created_by = (SELECT auth.uid())));
ALTER POLICY "Users can view own templates" ON public."form_templates" USING ((created_by = (SELECT auth.uid())));
ALTER POLICY "rls_phase2_staff_all" ON public."historical_candidates" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Job posters can view analytics for their jobs" ON public."job_analytics_events" USING ((job_id IN ( SELECT jobs.id
   FROM jobs
  WHERE (jobs.submitter_member_id IN ( SELECT members.id
           FROM members
          WHERE (members.user_id = (SELECT auth.uid())))))));
ALTER POLICY "Members can insert own analytics events" ON public."job_analytics_events" WITH CHECK ((member_id = (SELECT auth.uid())));
ALTER POLICY "Members can view own analytics events" ON public."job_analytics_events" USING ((member_id = (SELECT auth.uid())));
ALTER POLICY "Job posters can update application status" ON public."job_applications" USING ((job_id IN ( SELECT jobs.id
   FROM jobs
  WHERE (jobs.submitter_email = (SELECT auth.email()))))) WITH CHECK ((job_id IN ( SELECT jobs.id
   FROM jobs
  WHERE (jobs.submitter_email = (SELECT auth.email())))));
ALTER POLICY "Job posters can view applications to own jobs" ON public."job_applications" USING ((job_id IN ( SELECT jobs.id
   FROM jobs
  WHERE (jobs.submitter_email = (SELECT auth.email())))));
ALTER POLICY "Members can create applications" ON public."job_applications" WITH CHECK ((EXISTS ( SELECT 1
   FROM members
  WHERE ((members.user_id = (SELECT auth.uid())) OR (members.email = (SELECT auth.email()))))));
ALTER POLICY "Members can view own applications" ON public."job_applications" USING ((member_id IN ( SELECT members.id
   FROM members
  WHERE ((members.user_id = (SELECT auth.uid())) OR (members.email = (SELECT auth.email()))))));
ALTER POLICY "rls_phase3_job_applications_staff_all" ON public."job_applications" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Job posters can view interactions for their jobs" ON public."job_member_interactions" USING ((job_id IN ( SELECT jobs.id
   FROM jobs
  WHERE (jobs.submitter_member_id IN ( SELECT members.id
           FROM members
          WHERE (members.user_id = (SELECT auth.uid())))))));
ALTER POLICY "Members can view own interactions" ON public."job_member_interactions" USING ((member_id IN ( SELECT members.id
   FROM members
  WHERE (members.user_id = (SELECT auth.uid())))));
ALTER POLICY "Executive committee can delete notification logs" ON public."job_notification_log" USING ((EXISTS ( SELECT 1
   FROM members
  WHERE ((members.user_id = (SELECT auth.uid())) AND (members.executive_committee = true)))));
ALTER POLICY "Executive committee can view all notification logs" ON public."job_notification_log" USING ((EXISTS ( SELECT 1
   FROM members
  WHERE ((members.user_id = (SELECT auth.uid())) AND (members.executive_committee = true)))));
ALTER POLICY "Job submitters can view application notification logs" ON public."job_notification_log" USING ((EXISTS ( SELECT 1
   FROM jobs
  WHERE ((jobs.id = job_notification_log.job_id) AND (jobs.submitter_email = ( SELECT members.email
           FROM members
          WHERE (members.user_id = (SELECT auth.uid()))
         LIMIT 1))))));
ALTER POLICY "Users can view their own notification logs" ON public."job_notification_log" USING ((recipient_member_id = ( SELECT members.id
   FROM members
  WHERE (members.user_id = (SELECT auth.uid()))
 LIMIT 1)));
ALTER POLICY "Executive committee can manage template variables" ON public."job_notification_template_variables" USING ((EXISTS ( SELECT 1
   FROM members
  WHERE ((members.user_id = (SELECT auth.uid())) AND (members.executive_committee = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM members
  WHERE ((members.user_id = (SELECT auth.uid())) AND (members.executive_committee = true)))));
ALTER POLICY "Executive committee has full access to notification templates" ON public."job_notification_templates" USING ((EXISTS ( SELECT 1
   FROM members
  WHERE ((members.user_id = (SELECT auth.uid())) AND (members.executive_committee = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM members
  WHERE ((members.user_id = (SELECT auth.uid())) AND (members.executive_committee = true)))));
ALTER POLICY "Job posters can update own jobs" ON public."jobs" USING ((submitter_email = (SELECT auth.email()))) WITH CHECK ((submitter_email = (SELECT auth.email())));
ALTER POLICY "Job posters can view own jobs" ON public."jobs" USING ((submitter_email = (SELECT auth.email())));
ALTER POLICY "Users can update their submissions" ON public."jobs" USING (((status = 'pending'::text) AND (submitter_email = ((SELECT auth.jwt()) ->> 'email'::text))));
ALTER POLICY "rls_phase3_jobs_staff_all" ON public."jobs" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Users create own messages" ON public."knowledge_chat_messages" WITH CHECK ((session_id IN ( SELECT knowledge_chat_sessions.id
   FROM knowledge_chat_sessions
  WHERE (knowledge_chat_sessions.user_id = (SELECT auth.uid())))));
ALTER POLICY "Users view own messages" ON public."knowledge_chat_messages" USING ((session_id IN ( SELECT knowledge_chat_sessions.id
   FROM knowledge_chat_sessions
  WHERE (knowledge_chat_sessions.user_id = (SELECT auth.uid())))));
ALTER POLICY "Users create own sessions" ON public."knowledge_chat_sessions" WITH CHECK ((user_id = (SELECT auth.uid())));
ALTER POLICY "Users delete own sessions" ON public."knowledge_chat_sessions" USING ((user_id = (SELECT auth.uid())));
ALTER POLICY "Users update own sessions" ON public."knowledge_chat_sessions" USING ((user_id = (SELECT auth.uid())));
ALTER POLICY "Users view own sessions" ON public."knowledge_chat_sessions" USING ((user_id = (SELECT auth.uid())));
ALTER POLICY "Users view own usage" ON public."knowledge_usage_log" USING ((user_id = (SELECT auth.uid())));
ALTER POLICY "Users can view their own alert history" ON public."legislation_alert_history" USING ((user_id = (SELECT auth.uid())));
ALTER POLICY "Users can create their own alerts" ON public."legislation_alerts" WITH CHECK ((user_id = (SELECT auth.uid())));
ALTER POLICY "Users can delete their own alerts" ON public."legislation_alerts" USING ((user_id = (SELECT auth.uid())));
ALTER POLICY "Users can update their own alerts" ON public."legislation_alerts" USING ((user_id = (SELECT auth.uid()))) WITH CHECK ((user_id = (SELECT auth.uid())));
ALTER POLICY "Users can view their own alerts" ON public."legislation_alerts" USING ((user_id = (SELECT auth.uid())));
ALTER POLICY "Authenticated users can create notes" ON public."legislation_bill_notes" WITH CHECK ((author_id = (SELECT auth.uid())));
ALTER POLICY "Users can delete their own notes" ON public."legislation_bill_notes" USING ((author_id = (SELECT auth.uid())));
ALTER POLICY "Users can update their own notes" ON public."legislation_bill_notes" USING ((author_id = (SELECT auth.uid()))) WITH CHECK ((author_id = (SELECT auth.uid())));
ALTER POLICY "Service role can update legislation statistics" ON public."legislation_statistics" USING (((SELECT auth.role()) = 'service_role'::text));
ALTER POLICY "rls_phase2_staff_all" ON public."legislation_text_extraction_queue" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Service role has full access to magic_links" ON public."magic_links" USING (((SELECT auth.role()) = 'service_role'::text));
ALTER POLICY "ma_self" ON public."mail_aliases" USING (((user_id = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "mmc_self" ON public."mail_messages_cache" USING (((alias_email = current_user_alias()) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "mps_superadmin" ON public."mail_pubsub_state" USING ((SELECT current_user_is_superadmin()));
ALTER POLICY "msl_self" ON public."mail_send_log" USING (((sender_user_id = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "mvp_self" ON public."mail_vacation_prefs" USING (((user_id = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin()))) WITH CHECK (((user_id = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "rls_phase2_staff_all" ON public."mautic_sync_log" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."mautic_sync_queue" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."mec_committees" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."mec_contributions" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."mec_donor_merges" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."mec_donors" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."mec_expenditures" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."mec_financial_summaries" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."mec_independent_expenditures" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."mec_large_contributions" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."mec_reports" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "meeting_attendance_self_select" ON public."meeting_attendance" USING ((EXISTS ( SELECT 1
   FROM members m
  WHERE ((m.id = meeting_attendance.member_id) AND (m.user_id = (SELECT auth.uid()))))));
ALTER POLICY "rls_phase2_staff_all" ON public."meeting_attendance" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "meeting_invitees_self_select" ON public."meeting_invitees" USING ((EXISTS ( SELECT 1
   FROM members m
  WHERE ((m.id = meeting_invitees.member_id) AND (m.user_id = (SELECT auth.uid()))))));
ALTER POLICY "rls_phase2_staff_all" ON public."meeting_invitees" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "meetings_self_attended" ON public."meetings" USING (((EXISTS ( SELECT 1
   FROM (meeting_attendance ma
     JOIN members m ON ((m.id = ma.member_id)))
  WHERE ((ma.meeting_id = meetings.id) AND (m.user_id = (SELECT auth.uid()))))) OR (EXISTS ( SELECT 1
   FROM members m
  WHERE ((m.id = meetings.meeting_host) AND (m.user_id = (SELECT auth.uid())))))));
ALTER POLICY "rls_phase2_staff_all" ON public."meetings" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."member_email_history" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."member_portal_field_visibility" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."member_portal_meetings" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."member_portal_resources" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."member_profile_changes" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "member_roles_self_select" ON public."member_roles" USING ((user_id = (SELECT auth.uid())));
ALTER POLICY "member_roles_superadmin_delete" ON public."member_roles" USING ((SELECT current_user_is_superadmin()));
ALTER POLICY "member_roles_superadmin_insert" ON public."member_roles" WITH CHECK ((SELECT current_user_is_superadmin()));
ALTER POLICY "member_roles_superadmin_select_all" ON public."member_roles" USING ((SELECT current_user_is_superadmin()));
ALTER POLICY "member_roles_superadmin_update" ON public."member_roles" USING ((SELECT current_user_is_superadmin())) WITH CHECK ((SELECT current_user_is_superadmin()));
ALTER POLICY "rls_phase2_staff_all" ON public."member_submitted_events" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "members_self_read" ON public."members" USING (((user_id = (SELECT auth.uid())) OR (email = ((SELECT auth.jwt()) ->> 'email'::text)) OR (school_email = ((SELECT auth.jwt()) ->> 'email'::text))));
ALTER POLICY "members_self_update" ON public."members" USING ((user_id = (SELECT auth.uid()))) WITH CHECK ((user_id = (SELECT auth.uid())));
ALTER POLICY "members_staff_read" ON public."members" USING ((SELECT is_staff()));
ALTER POLICY "members_staff_write" ON public."members" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Members can view own membership card" ON public."membership_cards" USING ((member_id = (SELECT auth.uid())));
ALTER POLICY "Service role has full access to membership_cards" ON public."membership_cards" USING (((SELECT auth.role()) = 'service_role'::text));
ALTER POLICY "Staff can view membership cards" ON public."membership_cards" USING ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."mo_voter_file" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."non_member_attendees" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."nonprofit_officers" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "auth_read_page_views" ON public."page_views" USING (((SELECT auth.role()) = 'authenticated'::text));
ALTER POLICY "Members can create own physical card request" ON public."physical_card_requests" WITH CHECK ((member_id = (SELECT auth.uid())));
ALTER POLICY "Members can view own physical card requests" ON public."physical_card_requests" USING ((member_id = (SELECT auth.uid())));
ALTER POLICY "Service role has full access to physical_card_requests" ON public."physical_card_requests" USING (((SELECT auth.role()) = 'service_role'::text));
ALTER POLICY "rls_phase2_staff_all" ON public."plaid_connections" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."receipts" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."scheduled_meetings" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "scheduled_meetings_self_invited" ON public."scheduled_meetings" USING (((created_by = (SELECT auth.uid())) OR (EXISTS ( SELECT 1
   FROM (meeting_invitees mi
     JOIN members m ON ((m.id = mi.member_id)))
  WHERE ((mi.meeting_id = scheduled_meetings.id) AND (m.user_id = (SELECT auth.uid())))))));
ALTER POLICY "rls_phase2_staff_all" ON public."slack_analytics_cache" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."slack_avatar_sync_queue" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."slack_channel_committee_mapping" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."slack_channel_membership_log" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."slack_message_archive_status" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."slack_messages" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."slack_user_mapping" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."slack_users_unmatched" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "subscribers_staff_read" ON public."subscribers" USING ((SELECT is_staff()));
ALTER POLICY "subscribers_staff_write" ON public."subscribers" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."survey_questions" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."survey_responses" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."survey_sessions" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."surveys" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "auth_all_tracking_links" ON public."tracking_links" USING (((SELECT auth.role()) = 'authenticated'::text));
ALTER POLICY "uhp_self_all" ON public."user_home_preferences" USING (((user_id = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin()))) WITH CHECK (((user_id = (SELECT auth.uid())) OR (SELECT current_user_is_superadmin())));
ALTER POLICY "rls_phase2_staff_all" ON public."van_addresses" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."van_districts" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."van_early_voting" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."van_emails" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."van_household" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."van_mec_donor_parties" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."van_phones" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."van_polling_locations" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."van_scores" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."van_voters" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "rls_phase2_staff_all" ON public."van_voting_history" USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY "Members can view own votes" ON public."votes" USING ((member_id = ( SELECT members.id
   FROM members
  WHERE (members.user_id = (SELECT auth.uid())))));
ALTER POLICY "Members can vote" ON public."votes" WITH CHECK (((member_id = ( SELECT members.id
   FROM members
  WHERE (members.user_id = (SELECT auth.uid())))) AND (EXISTS ( SELECT 1
   FROM form_schemas
  WHERE ((form_schemas.id = votes.voting_form_id) AND (form_schemas.form_type = 'vote'::text) AND (form_schemas.status = 'active'::text) AND (form_schemas.voting_starts_at <= now()) AND (form_schemas.voting_ends_at >= now()))))));
