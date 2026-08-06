-- Make the enrichment failures that 20260806_04 started swallowing VISIBLE.
--
-- 20260806_04 was right that a failing enrichment step must not abort a signup:
-- the member row is the point, and a search document or a district lookup is a
-- derivative that can be rebuilt. But it reported those failures with RAISE
-- WARNING and nothing more, and nothing reads the Postgres log. No alert, no
-- table, no Sentry path out of Postgres. That is the same "a log line nobody
-- reads is not visibility" argument this project already makes at length in
-- site-forms/api/membership/process/route.ts, applied against itself.
--
-- It matters more than it looks, because sync_table_to_knowledge is attached to
-- INSERT and UPDATE on FOURTEEN tables, not just to the signup INSERT the _04
-- header reasons about. The failure this now catches: a column change on
-- public.knowledge_documents makes upsert_knowledge_document raise, every
-- members, donors, subscribers and slack_messages write keeps succeeding, and
-- the RAG index silently stops being written for all 14 tables. Before _04 that
-- aborted the statement and was impossible to miss. After _04 it was impossible
-- to notice. This is the middle position: the write still succeeds, and the
-- failure lands somewhere a human and the CRM can see.

create table if not exists public.enrichment_failures (
  id              bigserial primary key,
  occurred_at     timestamptz not null default now(),
  source_function text        not null,
  source_table    text,
  row_id          text,
  error_message   text,
  error_detail    text
);

comment on table public.enrichment_failures IS
  'Non-fatal failures from the AFTER INSERT/UPDATE enrichment triggers (knowledge sync, district lookup, membership card). The parent write SUCCEEDED in every row here; only the derived work failed. Rows accumulating means an enrichment path has broken silently, which before 20260806_04 would have shown up as failed inserts instead.';

create index if not exists enrichment_failures_occurred_at_idx
  on public.enrichment_failures (occurred_at desc);

alter table public.enrichment_failures enable row level security;
-- No policies on purpose: service_role bypasses RLS, and nothing else has any
-- business reading operational failure detail that quotes row ids.
revoke all on public.enrichment_failures from anon, authenticated;

-- ---------------------------------------------------------------------------
-- The recorder.
--
-- SECURITY DEFINER so the trigger's caller does not need rights on the table,
-- and it SWALLOWS ITS OWN ERRORS. This is called from inside an exception
-- handler on the signup path: if recording the failure could itself raise, it
-- would propagate out of the handler and abort the very member insert that _04
-- exists to protect. A failure to log must never be worse than the thing it is
-- logging. RAISE WARNING is kept as well as, not instead of, the table.
-- ---------------------------------------------------------------------------
create or replace function public.log_enrichment_failure(
  p_source_function text,
  p_source_table    text,
  p_row_id          text,
  p_error_message   text,
  p_error_detail    text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    insert into public.enrichment_failures
      (source_function, source_table, row_id, error_message, error_detail)
    values
      (p_source_function, p_source_table, p_row_id, p_error_message, p_error_detail);
  exception when others then
    raise warning 'could not record enrichment failure (%): %', p_source_function, sqlerrm;
  end;
end;
$$;

revoke all on function public.log_enrichment_failure(text, text, text, text, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Route the three handlers into it. Each keeps its RAISE WARNING and its
-- comment; the only change is the added recorder call. The bodies are patched
-- in place rather than rewritten, so nothing else about 20260806_04 moves.
-- ---------------------------------------------------------------------------
do $patch$
declare
  v_src  text;
  v_new  text;
  v_fn   text;
  v_pairs text[][] := array[
    ['sync_table_to_knowledge',
     $old$    RAISE WARNING 'knowledge sync failed for %.% row %: %',
      TG_TABLE_SCHEMA, TG_TABLE_NAME, (to_jsonb(NEW)->>'id'), SQLERRM;$old$,
     $new$    RAISE WARNING 'knowledge sync failed for %.% row %: %',
      TG_TABLE_SCHEMA, TG_TABLE_NAME, (to_jsonb(NEW)->>'id'), SQLERRM;
    PERFORM public.log_enrichment_failure('sync_table_to_knowledge',
      TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, (to_jsonb(NEW)->>'id'), SQLERRM, SQLSTATE);$new$],
    ['trigger_district_lookup',
     $old$      RAISE WARNING 'district lookup could not be queued for member %: %', NEW.id, SQLERRM;$old$,
     $new$      RAISE WARNING 'district lookup could not be queued for member %: %', NEW.id, SQLERRM;
      PERFORM public.log_enrichment_failure('trigger_district_lookup',
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, NEW.id::text, SQLERRM, SQLSTATE);$new$],
    ['auto_generate_membership_card',
     $old$      RAISE WARNING 'membership card could not be created for member %: %', NEW.id, SQLERRM;$old$,
     $new$      RAISE WARNING 'membership card could not be created for member %: %', NEW.id, SQLERRM;
      PERFORM public.log_enrichment_failure('auto_generate_membership_card',
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, NEW.id::text, SQLERRM, SQLSTATE);$new$]
  ];
  i int;
begin
  for i in 1 .. array_length(v_pairs, 1) loop
    v_fn := v_pairs[i][1];
    select pg_get_functiondef(p.oid) into v_src
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = v_fn
     limit 1;

    if v_src is null then
      raise exception 'expected function public.% to exist', v_fn;
    end if;
    if position(v_pairs[i][2] in v_src) = 0 then
      raise exception 'could not find the exception handler to patch in public.%; refusing to guess', v_fn;
    end if;

    v_new := replace(v_src, v_pairs[i][2], v_pairs[i][3]);
    execute v_new;
  end loop;
end;
$patch$;
