"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type OnboardingActionState = { error?: string };

const currencies = new Set(["EGP", "SAR", "USD", "EUR"]);
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function validTimeZone(value: string) {
  if (!value.trim()) return false;
  try {
    return Intl.DateTimeFormat(undefined, { timeZone: value }).resolvedOptions().timeZone === value;
  } catch {
    return false;
  }
}

export async function acceptInvitation(
  _previousState: OnboardingActionState,
  formData: FormData,
): Promise<OnboardingActionState> {
  const invitationId = String(formData.get("invitationId") ?? "");
  if (!uuidPattern.test(invitationId)) return { error: "تعذر التحقق من الدعوة. حدّث الصفحة وحاول مرة أخرى." };

  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims) redirect("/login?next=/app");

  const { error } = await supabase.rpc("accept_household_invitation_by_id", {
    p_invitation_id: invitationId,
  });
  if (error) return { error: "لم تعد هذه الدعوة متاحة. حدّث الصفحة للاطلاع على حالتها الحالية." };

  revalidatePath("/app");
  redirect("/app");
}

export async function createInitialHousehold(
  _previousState: OnboardingActionState,
  formData: FormData,
): Promise<OnboardingActionState> {
  const name = String(formData.get("name") ?? "").trim();
  const currency = String(formData.get("currency") ?? "");
  const periodStartDay = Number(formData.get("periodStartDay") ?? "");
  const timezone = String(formData.get("timezone") ?? "").trim();

  if (!name) return { error: "اكتب اسم البيت للمتابعة." };
  if (!currencies.has(currency)) return { error: "اختر عملة مدعومة للبيت." };
  if (!Number.isInteger(periodStartDay) || periodStartDay < 1 || periodStartDay > 31) {
    return { error: "اختر يومًا من ١ إلى ٣١." };
  }
  if (!validTimeZone(timezone)) return { error: "اختر منطقة زمنية صالحة قبل المتابعة." };

  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims) redirect("/login?next=/app");

  const { error } = await supabase.rpc("create_initial_household", {
    p_name: name,
    p_currency_code: currency,
    p_period_start_day: periodStartDay,
    p_timezone: timezone,
  });

  if (error) {
    return { error: "تعذر إنشاء البيت الآن. تحقق من البيانات وحاول مرة أخرى." };
  }

  revalidatePath("/app");
  redirect("/app");
}
