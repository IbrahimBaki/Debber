SET local check_function_bodies = off;

ALTER TABLE "public"."admin_audit_logs"
  ADD COLUMN "target_user_id" uuid;

ALTER TABLE "public"."admin_audit_logs"
  ADD COLUMN "household_id" uuid;

ALTER TABLE "public"."admin_audit_logs"
  ADD COLUMN "invitation_id" uuid;

CREATE OR REPLACE FUNCTION public.admin_accept_household_invitation (
  p_invitation_id uuid
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_admin_uid uuid := (select auth.uid());
  v_invitation public.household_invitations%rowtype;
  v_invitee_uid uuid;
begin
  if v_admin_uid is null or not public.is_platform_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select * into v_invitation
  from public.household_invitations hi
  where hi.id = p_invitation_id
  for update;

  if v_invitation.id is null then
    raise exception 'invitation_not_found' using errcode = 'P0002';
  end if;

  if not exists (
    select 1 from public.households h
    where h.id = v_invitation.household_id and h.archived_at is null
  ) then
    raise exception 'household_not_found' using errcode = 'P0002';
  end if;

  if v_invitation.status = 'accepted' then
    if exists (
      select 1 from public.household_members hm
      where hm.household_id = v_invitation.household_id
        and hm.user_id = v_invitation.accepted_by
        and hm.status = 'active'
    ) then
      return v_invitation.household_id;
    end if;
    raise exception 'invitation_acceptance_incomplete' using errcode = 'P0001';
  end if;

  if v_invitation.status <> 'pending' then
    raise exception 'invitation_not_pending' using errcode = 'P0001';
  end if;

  if v_invitation.expires_at <= now() then
    update public.household_invitations
    set status = 'expired', updated_at = now()
    where id = v_invitation.id;
    raise exception 'invitation_expired' using errcode = 'P0001';
  end if;

  select u.id into v_invitee_uid
  from auth.users u
  where pg_catalog.lower(u.email) = pg_catalog.lower(v_invitation.email);

  if v_invitee_uid is null then
    raise exception 'invitee_user_not_found' using errcode = 'P0002';
  end if;

  insert into public.household_members (household_id, user_id, role, status)
  values (v_invitation.household_id, v_invitee_uid, 'member', 'active')
  on conflict (household_id, user_id)
  do update set status = 'active', removed_at = null, updated_at = now();

  update public.household_invitations
  set status = 'accepted', accepted_by = v_invitee_uid, accepted_at = now(), updated_at = now()
  where id = v_invitation.id;

  insert into public.audit_events (
    household_id, actor_user_id, actor_type, event_type, entity_type, entity_id, metadata
  ) values (
    v_invitation.household_id, v_admin_uid, 'platform_admin', 'membership.invitation_accepted_by_admin',
    'household_member', v_invitee_uid, jsonb_build_object('invitee_user_id', v_invitee_uid)
  );

  perform public.admin_record_audit_event(
    'invitation.accepted_on_behalf', 'household_invitation', v_invitation.id::text,
    v_invitee_uid, v_invitation.household_id, v_invitation.id, null
  );

  return v_invitation.household_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_create_household_invitation (
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
  v_admin_uid uuid := (select auth.uid());
  v_owner_id uuid;
  v_owner_email text;
  v_email text;
  v_existing_id uuid;
  v_existing_expires_at timestamptz;
  v_new_id uuid;
  v_new_expires_at timestamptz;
begin
  if v_admin_uid is null or not public.is_platform_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select h.owner_user_id into v_owner_id
  from public.households h
  where h.id = p_household_id and h.archived_at is null;

  if v_owner_id is null then
    raise exception 'household_not_found' using errcode = 'P0002';
  end if;

  v_email := pg_catalog.lower(pg_catalog.btrim(p_email));
  if v_email is null or v_email = '' or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'invalid_email' using errcode = '22023';
  end if;

  select pg_catalog.lower(u.email) into v_owner_email
  from auth.users u
  where u.id = v_owner_id;

  if v_owner_email is not null and v_owner_email = v_email then
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
    v_owner_id,
    v_new_expires_at
  )
  returning id into v_new_id;

  insert into public.audit_events (
    household_id, actor_user_id, actor_type, event_type, entity_type, entity_id
  ) values (
    p_household_id, v_admin_uid, 'platform_admin', 'household_invitation.created', 'household_invitation', v_new_id
  );

  perform public.admin_record_audit_event(
    'invitation.created_on_behalf', 'household_invitation', v_new_id::text,
    null, p_household_id, v_new_id, null
  );

  return query select v_new_id, v_email, v_new_expires_at, true;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_dashboard_counts()
  RETURNS TABLE (
    users_total         bigint,
    households_active   bigint,
    households_archived bigint,
    invitations_pending bigint,
    memberships_active  bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if not public.is_platform_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  return query
  select
    (select count(*) from auth.users),
    (select count(*) from public.households where archived_at is null),
    (select count(*) from public.households where archived_at is not null),
    (select count(*) from public.household_invitations where status = 'pending' and expires_at > now()),
    (select count(*) from public.household_members where status = 'active');
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_user (
  p_user_id uuid
)
  RETURNS TABLE (
    user_id            uuid,
    email              text,
    status             text,
    email_confirmed_at timestamp with time zone,
    banned_until       timestamp with time zone,
    last_sign_in_at    timestamp with time zone,
    created_at         timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if not public.is_platform_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  return query
  select
    u.id,
    u.email::text,
    case
      when u.banned_until is not null and u.banned_until > now() then 'disabled'
      when u.email_confirmed_at is null then 'needs_activation'
      else 'active'
    end,
    u.email_confirmed_at,
    u.banned_until,
    u.last_sign_in_at,
    u.created_at
  from auth.users u
  where u.id = p_user_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_audit_logs (
  p_limit  integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
  RETURNS TABLE (
    id             bigint,
    admin_email    text,
    action         text,
    target_type    text,
    target_id      text,
    target_user_id uuid,
    household_id   uuid,
    invitation_id  uuid,
    reason         text,
    created_at     timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if not public.is_platform_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  return query
  select l.id, u.email::text, l.action, l.target_type, l.target_id, l.target_user_id,
         l.household_id, l.invitation_id, l.reason, l.created_at
  from public.admin_audit_logs l
  left join auth.users u on u.id = l.admin_user_id
  order by l.created_at desc
  limit greatest(least(coalesce(p_limit, 50), 200), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_invitations (
  p_search_email text                     DEFAULT NULL::text,
  p_status       public.invitation_status DEFAULT NULL::public.invitation_status,
  p_limit        integer                  DEFAULT 50,
  p_offset       integer                  DEFAULT 0
)
  RETURNS TABLE (
    invitation_id           uuid,
    household_id            uuid,
    household_name          text,
    email                   text,
    status                  public.invitation_status,
    invited_by_display_name text,
    created_at              timestamp with time zone,
    expires_at              timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_search text;
begin
  if not public.is_platform_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  v_search := pg_catalog.lower(pg_catalog.btrim(p_search_email));
  if v_search = '' then
    v_search := null;
  end if;

  return query
  select hi.id, h.id, h.name, hi.email, hi.status, p.display_name, hi.created_at, hi.expires_at
  from public.household_invitations hi
  join public.households h on h.id = hi.household_id
  left join public.profiles p on p.id = hi.invited_by
  where (v_search is null or pg_catalog.lower(hi.email) like '%' || v_search || '%')
    and (p_status is null or hi.status = p_status)
  order by hi.created_at desc
  limit greatest(least(coalesce(p_limit, 50), 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_user_memberships (
  p_user_id uuid
)
  RETURNS TABLE (
    household_id   uuid,
    household_name text,
    role           public.household_role,
    status         public.member_status,
    joined_at      timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if not public.is_platform_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  return query
  select h.id, h.name, hm.role, hm.status, hm.joined_at
  from public.household_members hm
  join public.households h on h.id = hm.household_id
  where hm.user_id = p_user_id
  order by hm.joined_at asc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_users (
  p_search text    DEFAULT NULL::text,
  p_limit  integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
  RETURNS TABLE (
    user_id            uuid,
    email              text,
    status             text,
    email_confirmed_at timestamp with time zone,
    banned_until       timestamp with time zone,
    last_sign_in_at    timestamp with time zone,
    created_at         timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_search text;
begin
  if not public.is_platform_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  v_search := pg_catalog.btrim(p_search);
  if v_search = '' then
    v_search := null;
  end if;

  return query
  select
    u.id,
    u.email::text,
    case
      when u.banned_until is not null and u.banned_until > now() then 'disabled'
      when u.email_confirmed_at is null then 'needs_activation'
      else 'active'
    end,
    u.email_confirmed_at,
    u.banned_until,
    u.last_sign_in_at,
    u.created_at
  from auth.users u
  where v_search is null
     or pg_catalog.lower(u.email) like '%' || pg_catalog.lower(
          pg_catalog.replace(pg_catalog.replace(v_search, '%', '\%'), '_', '\_')
        ) || '%' escape '\'
  order by u.created_at desc
  limit greatest(least(coalesce(p_limit, 50), 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_record_audit_event (
  p_action         text,
  p_target_type    text,
  p_target_id      text DEFAULT NULL::text,
  p_target_user_id uuid DEFAULT NULL::uuid,
  p_household_id   uuid DEFAULT NULL::uuid,
  p_invitation_id  uuid DEFAULT NULL::uuid,
  p_reason         text DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null or not public.is_platform_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if p_action is null or pg_catalog.btrim(p_action) = '' then
    raise exception 'invalid_action' using errcode = '22023';
  end if;

  insert into public.admin_audit_logs (
    admin_user_id, action, target_type, target_id, target_user_id, household_id, invitation_id, reason
  ) values (
    v_uid, p_action, p_target_type, p_target_id, p_target_user_id, p_household_id, p_invitation_id, p_reason
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_revoke_household_invitation (
  p_invitation_id uuid,
  p_reason        text DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_admin_uid uuid := (select auth.uid());
  v_invitation public.household_invitations%rowtype;
begin
  if v_admin_uid is null or not public.is_platform_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select * into v_invitation
  from public.household_invitations hi
  where hi.id = p_invitation_id
  for update;

  if v_invitation.id is null then
    raise exception 'invitation_not_found' using errcode = 'P0002';
  end if;

  if v_invitation.status = 'pending' and v_invitation.expires_at <= now() then
    update public.household_invitations
    set status = 'expired', updated_at = now()
    where id = v_invitation.id;
    raise exception 'invitation_expired' using errcode = 'P0001';
  end if;

  if v_invitation.status <> 'pending' then
    raise exception 'invitation_not_pending' using errcode = 'P0001';
  end if;

  update public.household_invitations
  set status = 'revoked', updated_at = now()
  where id = v_invitation.id;

  insert into public.audit_events (
    household_id, actor_user_id, actor_type, event_type, entity_type, entity_id, metadata
  ) values (
    v_invitation.household_id, v_admin_uid, 'platform_admin', 'household_invitation.revoked',
    'household_invitation', v_invitation.id, jsonb_build_object('reason', p_reason)
  );

  perform public.admin_record_audit_event(
    'invitation.revoked', 'household_invitation', v_invitation.id::text,
    null, v_invitation.household_id, v_invitation.id, p_reason
  );
end;
$function$;

ALTER TABLE "public"."admin_audit_logs"
  ADD CONSTRAINT "admin_audit_logs_household_id_fkey" FOREIGN KEY (household_id) REFERENCES public.households(id);

ALTER TABLE "public"."admin_audit_logs"
  ADD CONSTRAINT "admin_audit_logs_invitation_id_fkey" FOREIGN KEY (invitation_id) REFERENCES public.household_invitations(id);

ALTER TABLE "public"."admin_audit_logs"
  ADD CONSTRAINT "admin_audit_logs_target_user_id_fkey" FOREIGN KEY (target_user_id) REFERENCES auth.users(id);

REVOKE ALL ON FUNCTION "public"."admin_accept_household_invitation"(uuid) FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."admin_accept_household_invitation"(uuid) FROM anon, service_role;

GRANT EXECUTE ON FUNCTION "public"."admin_accept_household_invitation"(uuid) TO "authenticated", "postgres";

REVOKE ALL ON FUNCTION "public"."admin_create_household_invitation"(uuid, text) FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."admin_create_household_invitation"(uuid, text) FROM anon, service_role;

GRANT EXECUTE ON FUNCTION "public"."admin_create_household_invitation"(uuid, text) TO "authenticated", "postgres";

REVOKE ALL ON FUNCTION "public"."admin_dashboard_counts"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."admin_dashboard_counts"() FROM anon, service_role;

GRANT EXECUTE ON FUNCTION "public"."admin_dashboard_counts"() TO "authenticated", "postgres";

REVOKE ALL ON FUNCTION "public"."admin_get_user"(uuid) FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."admin_get_user"(uuid) FROM anon, service_role;

GRANT EXECUTE ON FUNCTION "public"."admin_get_user"(uuid) TO "authenticated", "postgres";

REVOKE ALL ON FUNCTION "public"."admin_list_audit_logs"(integer, integer) FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."admin_list_audit_logs"(integer, integer) FROM anon, service_role;

GRANT EXECUTE ON FUNCTION "public"."admin_list_audit_logs"(integer, integer) TO "authenticated", "postgres";

REVOKE ALL ON FUNCTION "public"."admin_list_invitations"(text, public.invitation_status, integer, integer) FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."admin_list_invitations"(text, public.invitation_status, integer, integer) FROM anon, service_role;

GRANT EXECUTE ON FUNCTION "public"."admin_list_invitations"(text, public.invitation_status, integer, integer) TO "authenticated", "postgres";

REVOKE ALL ON FUNCTION "public"."admin_list_user_memberships"(uuid) FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."admin_list_user_memberships"(uuid) FROM anon, service_role;

GRANT EXECUTE ON FUNCTION "public"."admin_list_user_memberships"(uuid) TO "authenticated", "postgres";

REVOKE ALL ON FUNCTION "public"."admin_list_users"(text, integer, integer) FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."admin_list_users"(text, integer, integer) FROM anon, service_role;

GRANT EXECUTE ON FUNCTION "public"."admin_list_users"(text, integer, integer) TO "authenticated", "postgres";

REVOKE ALL ON FUNCTION "public"."admin_record_audit_event"(text, text, text, uuid, uuid, uuid, text) FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."admin_record_audit_event"(text, text, text, uuid, uuid, uuid, text) FROM anon, service_role;

GRANT EXECUTE ON FUNCTION "public"."admin_record_audit_event"(text, text, text, uuid, uuid, uuid, text) TO "authenticated", "postgres";

REVOKE ALL ON FUNCTION "public"."admin_revoke_household_invitation"(uuid, text) FROM PUBLIC;

REVOKE ALL ON FUNCTION "public"."admin_revoke_household_invitation"(uuid, text) FROM anon, service_role;

GRANT EXECUTE ON FUNCTION "public"."admin_revoke_household_invitation"(uuid, text) TO "authenticated", "postgres";
