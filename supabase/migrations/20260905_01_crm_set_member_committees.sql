-- CRM member profile: set the non executive committees of one member in one
-- statement. Executive Committee gates CRM access (is_staff reads the derived
-- flag), so it is preserved if present and refused if requested, in the same
-- spirit as slack_remove_committee and import_merge_committees. Locking the row
-- and editing inside one UPDATE removes the read modify write window that let a
-- concurrent edit be lost. SECURITY INVOKER: RLS on public.members still applies,
-- and the explicit is_staff() check keeps a non executive from reaching it even
-- if a policy is ever loosened.
create or replace function public.crm_set_member_committees(
  p_member_id uuid,
  p_committees text[]
)
returns text[]
language plpgsql
security invoker
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_current text[];
  v_next    text[];
  v_item    text;
begin
  if not public.is_staff() then
    raise exception 'insufficient_privilege: staff role required'
      using errcode = '42501';
  end if;

  if array['Executive Committee'::text] <@ coalesce(p_committees, '{}'::text[]) then
    raise exception 'Executive Committee is managed in Superadmin > Executives'
      using errcode = '22023';
  end if;

  select coalesce(committee, '{}'::text[])
    into v_current
    from public.members
   where id = p_member_id
     for update;

  if not found then
    return null;
  end if;

  v_next := '{}'::text[];
  if v_current @> array['Executive Committee'::text] then
    v_next := array['Executive Committee'::text];
  end if;

  foreach v_item in array coalesce(p_committees, '{}'::text[]) loop
    v_item := btrim(v_item);
    if v_item <> '' and not (v_next @> array[v_item]) then
      v_next := v_next || v_item;
    end if;
  end loop;

  update public.members
     set committee = v_next
   where id = p_member_id;

  return v_next;
end;
$function$;

comment on function public.crm_set_member_committees(uuid, text[]) is
  'CRM profile editor: replaces the non executive committees of one member in one locked statement. Preserves Executive Committee when present and refuses to add it; that membership changes only through the superadmin path.';

revoke all on function public.crm_set_member_committees(uuid, text[]) from public;
revoke all on function public.crm_set_member_committees(uuid, text[]) from anon;
grant execute on function public.crm_set_member_committees(uuid, text[]) to authenticated;
