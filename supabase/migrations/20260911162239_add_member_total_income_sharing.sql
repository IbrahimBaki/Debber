SET local check_function_bodies = off;

ALTER TABLE "public"."households"
  ADD COLUMN "share_total_income_with_members" boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.get_member_visible_total_income (
  p_period_id uuid
)
  RETURNS numeric
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_household_id uuid;
  v_shared boolean;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select household_id into v_household_id
  from public.budget_periods
  where id = p_period_id;

  if v_household_id is null then
    raise exception 'period_not_found' using errcode = 'P0002';
  end if;

  if not public.is_household_member(v_household_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if not public.is_household_owner(v_household_id) then
    select share_total_income_with_members into v_shared
    from public.households
    where id = v_household_id;

    if not coalesce(v_shared, false) then
      return null;
    end if;
  end if;

  return coalesce(
    (select sum(planned_amount) from public.period_income_items where period_id = p_period_id),
    0
  );
end;
$function$;

REVOKE ALL ON FUNCTION "public"."get_member_visible_total_income"(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION "public"."get_member_visible_total_income"(uuid) FROM "anon", "service_role";

GRANT EXECUTE ON FUNCTION "public"."get_member_visible_total_income"(uuid) TO "authenticated", "postgres";
