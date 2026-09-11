SET local check_function_bodies = off;

REVOKE ALL ON TABLE "public"."household_invitations" FROM "authenticated";

DROP POLICY "Owners can create invitations for their household" ON "public"."household_invitations";

DROP POLICY "Owners can delete invitations for their household" ON "public"."household_invitations";

DROP POLICY "Owners can read invitations for their household" ON "public"."household_invitations";

DROP POLICY "Owners can update invitations for their household" ON "public"."household_invitations";

CREATE OR REPLACE FUNCTION public.create_household_invitation (
  p_household_id uuid,
  p_email        text
)
  RETURNS TABLE (
    invitation_id uuid,
    email         text,
    expires_at    timestamp with time zone,
    created       boolean
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_caller_email text;
  v_email text;
  v_existing_id uuid;
  v_existing_expires_at timestamptz;
  v_new_id uuid;
  v_new_expires_at timestamptz;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if not public.is_household_owner(p_household_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  v_email := pg_catalog.lower(pg_catalog.btrim(p_email));

  if v_email is null or v_email = '' or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'invalid_email' using errcode = '22023';
  end if;

  select pg_catalog.lower(u.email) into v_caller_email
  from auth.users u
  where u.id = v_uid;

  if v_caller_email is not null and v_caller_email = v_email then
    raise exception 'self_invite_not_allowed' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.household_members hm
    join auth.users u on u.id = hm.user_id
    where hm.household_id = p_household_id
      and hm.status = 'active'
      and pg_catalog.lower(u.email) = v_email
  ) then
    raise exception 'already_active_member' using errcode = 'P0001';
  end if;

  -- Serialize concurrent/retried invitation-creation attempts for the same Household+email so
  -- a race can never leave two simultaneous pending rows for the same recipient. A different
  -- Household inviting the same email is a different lock key and proceeds independently.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_household_id::text || ':' || v_email, 0)
  );

  select hi.id, hi.expires_at into v_existing_id, v_existing_expires_at
  from public.household_invitations hi
  where hi.household_id = p_household_id
    and pg_catalog.lower(hi.email) = v_email
    and hi.status = 'pending'
  order by hi.created_at desc
  limit 1
  for update;

  if v_existing_id is not null then
    if v_existing_expires_at > now() then
      return query select v_existing_id, v_email, v_existing_expires_at, false;
      return;
    end if;

    -- A stale pending invitation never blocks a fresh one; lazily transition it first.
    update public.household_invitations
    set status = 'expired', updated_at = now()
    where id = v_existing_id;
  end if;

  v_new_expires_at := now() + interval '7 days';

  insert into public.household_invitations (
    household_id, email, token_hash, invited_by, expires_at
  ) values (
    p_household_id,
    v_email,
    encode(extensions.gen_random_bytes(32), 'hex'),
    v_uid,
    v_new_expires_at
  )
  returning id into v_new_id;

  insert into public.audit_events (
    household_id, actor_user_id, actor_type, event_type, entity_type, entity_id
  ) values (
    p_household_id, v_uid, 'user', 'household_invitation.created', 'household_invitation', v_new_id
  );

  return query select v_new_id, v_email, v_new_expires_at, true;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."create_household_invitation"(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION "public"."create_household_invitation"(uuid, text) FROM "anon", "service_role";

GRANT EXECUTE ON FUNCTION "public"."create_household_invitation"(uuid, text) TO "authenticated", "postgres";
