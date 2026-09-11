"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type PlanActionState = { error?: string };

const initialState: PlanActionState = {};
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const amountPattern = /^\d{1,10}(\.\d{1,2})?$/;

function parseAmount(raw: FormDataEntryValue | null): number | null {
  const value = String(raw ?? "").trim();
  if (!amountPattern.test(value)) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseName(raw: FormDataEntryValue | null, maxLength: number): string | null {
  const value = String(raw ?? "").trim();
  if (!value || value.length > maxLength) return null;
  return value;
}

function parseId(raw: FormDataEntryValue | null): string | null {
  const value = String(raw ?? "");
  return uuidPattern.test(value) ? value : null;
}

async function requireSession() {
  const supabase = await createClient();
  const { data: claims, error } = await supabase.auth.getClaims();
  if (error || !claims?.claims?.sub) redirect("/login?next=/app/plan");
  return { supabase, uid: claims.claims.sub as string };
}

function friendlyError(error: { code?: string; message?: string } | null, fallback: string): string {
  if (!error) return fallback;
  const message = error.message ?? "";
  if (message.includes("section_allocations_exceed_spending_budget")) {
    return "هذا التغيير يجعل مجموع مخصصات الأقسام أكبر من ميزانية المصروف. عدّل الميزانية أو مخصصات الأقسام أولًا.";
  }
  if (error.code === "42501" || message.includes("not_authorized") || message.includes("not_authenticated")) {
    return "لا يمكن تنفيذ هذا الإجراء الآن. حدّث الصفحة وتحقق من حالة الشهر.";
  }
  if (error.code === "23505") {
    return "حدث تعارض غير متوقع أثناء الحفظ. حدّث الصفحة وحاول مرة أخرى.";
  }
  return fallback;
}

// ---------- Income ----------

export async function addIncomeItem(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase, uid } = await requireSession();
  const periodId = parseId(formData.get("periodId"));
  const name = parseName(formData.get("name"), 120);
  const amount = parseAmount(formData.get("amount"));
  if (!periodId) return { error: "تعذر التعرف على الفترة الحالية. حدّث الصفحة." };
  if (!name) return { error: "اكتب اسم الدخل." };
  if (amount === null) return { error: "اكتب مبلغًا صحيحًا." };

  const { error } = await supabase.from("period_income_items").insert({
    period_id: periodId,
    name_snapshot: name,
    planned_amount: amount,
    created_by: uid,
  });
  if (error) return { error: friendlyError(error, "تعذر إضافة الدخل الآن. حاول مرة أخرى.") };

  revalidatePath("/app/plan");
  return initialState;
}

export async function updateIncomeItem(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase } = await requireSession();
  const id = parseId(formData.get("id"));
  const name = parseName(formData.get("name"), 120);
  const amount = parseAmount(formData.get("amount"));
  if (!id) return { error: "تعذر التعرف على بند الدخل." };
  if (!name) return { error: "اكتب اسم الدخل." };
  if (amount === null) return { error: "اكتب مبلغًا صحيحًا." };

  const { error } = await supabase
    .from("period_income_items")
    .update({ name_snapshot: name, planned_amount: amount })
    .eq("id", id);
  if (error) return { error: friendlyError(error, "تعذر حفظ التعديل الآن.") };

  revalidatePath("/app/plan");
  return initialState;
}

export async function deleteIncomeItem(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase } = await requireSession();
  const id = parseId(formData.get("id"));
  if (!id) return { error: "تعذر التعرف على بند الدخل." };

  const { error } = await supabase.from("period_income_items").delete().eq("id", id);
  if (error) return { error: friendlyError(error, "تعذر حذف بند الدخل الآن.") };

  revalidatePath("/app/plan");
  return initialState;
}

// ---------- Fixed commitments ----------

export async function addRecurringCommitment(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase } = await requireSession();
  const periodId = parseId(formData.get("periodId"));
  const operationId = parseId(formData.get("operationId"));
  const name = parseName(formData.get("name"), 160);
  const amount = parseAmount(formData.get("amount"));
  if (!periodId || !operationId) return { error: "تعذر التعرف على الفترة الحالية. حدّث الصفحة." };
  if (!name) return { error: "اكتب اسم الالتزام." };
  if (amount === null) return { error: "اكتب مبلغًا صحيحًا." };

  const { error } = await supabase.rpc("create_recurring_fixed_commitment", {
    p_period_id: periodId,
    p_name: name,
    p_planned_amount: amount,
    p_template_id: operationId,
  });
  if (error) return { error: friendlyError(error, "تعذر إضافة الالتزام الآن. حاول مرة أخرى.") };

  revalidatePath("/app/plan");
  return initialState;
}

export async function addOneTimeCommitment(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase } = await requireSession();
  const periodId = parseId(formData.get("periodId"));
  const operationId = parseId(formData.get("operationId"));
  const name = parseName(formData.get("name"), 160);
  const amount = parseAmount(formData.get("amount"));
  if (!periodId || !operationId) return { error: "تعذر التعرف على الفترة الحالية. حدّث الصفحة." };
  if (!name) return { error: "اكتب اسم الالتزام." };
  if (amount === null) return { error: "اكتب مبلغًا صحيحًا." };

  const { error } = await supabase.rpc("create_one_time_fixed_commitment", {
    p_period_id: periodId,
    p_name: name,
    p_planned_amount: amount,
    p_commitment_id: operationId,
  });
  if (error) return { error: friendlyError(error, "تعذر إضافة الالتزام الآن. حاول مرة أخرى.") };

  revalidatePath("/app/plan");
  return initialState;
}

export async function updateCommitmentAmount(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase } = await requireSession();
  const id = parseId(formData.get("id"));
  const amount = parseAmount(formData.get("amount"));
  if (!id) return { error: "تعذر التعرف على الالتزام." };
  if (amount === null) return { error: "اكتب مبلغًا صحيحًا." };

  const { error } = await supabase.rpc("set_period_fixed_commitment_planned_amount", {
    p_period_fixed_commitment_id: id,
    p_planned_amount: amount,
  });
  if (error) return { error: friendlyError(error, "تعذر حفظ التعديل الآن.") };

  revalidatePath("/app/plan");
  return initialState;
}

export async function setCommitmentSkipped(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase } = await requireSession();
  const id = parseId(formData.get("id"));
  const skip = String(formData.get("skip")) === "true";
  if (!id) return { error: "تعذر التعرف على الالتزام." };

  const { error } = await supabase.rpc("set_period_fixed_commitment_skipped", {
    p_period_fixed_commitment_id: id,
    p_skip: skip,
  });
  if (error) return { error: friendlyError(error, "تعذر حفظ التغيير الآن.") };

  revalidatePath("/app/plan");
  return initialState;
}

export async function stopRecurringCommitment(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase } = await requireSession();
  const templateId = parseId(formData.get("templateId"));
  if (!templateId) return { error: "تعذر التعرف على الالتزام." };

  const { error } = await supabase
    .from("fixed_commitment_templates")
    .update({ is_active: false })
    .eq("id", templateId);
  if (error) return { error: friendlyError(error, "تعذر إيقاف تكرار الالتزام الآن.") };

  revalidatePath("/app/plan");
  return initialState;
}

// ---------- Spending budget ----------

export async function setSpendingBudget(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase } = await requireSession();
  const periodId = parseId(formData.get("periodId"));
  const amount = parseAmount(formData.get("amount"));
  if (!periodId) return { error: "تعذر التعرف على الفترة الحالية. حدّث الصفحة." };
  if (amount === null) return { error: "اكتب مبلغًا صحيحًا." };

  const { error } = await supabase.rpc("set_period_spending_budget", {
    p_period_id: periodId,
    p_spending_budget: amount,
  });
  if (error) return { error: friendlyError(error, "تعذر حفظ ميزانية المصروف الآن.") };

  revalidatePath("/app/plan");
  return initialState;
}

// ---------- Sections ----------

export async function addSection(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase } = await requireSession();
  const periodId = parseId(formData.get("periodId"));
  const operationId = parseId(formData.get("operationId"));
  const name = parseName(formData.get("name"), 120);
  if (!periodId || !operationId) return { error: "تعذر التعرف على الفترة الحالية. حدّث الصفحة." };
  if (!name) return { error: "اكتب اسم القسم." };

  const { error } = await supabase.rpc("create_flexible_budget_section", {
    p_period_id: periodId,
    p_name: name,
    p_section_id: operationId,
  });
  if (error) return { error: friendlyError(error, "تعذر إضافة القسم الآن. حاول مرة أخرى.") };

  revalidatePath("/app/plan");
  return initialState;
}

export async function updateSectionAllocation(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase } = await requireSession();
  const id = parseId(formData.get("id"));
  const amount = parseAmount(formData.get("amount"));
  if (!id) return { error: "تعذر التعرف على القسم." };
  if (amount === null) return { error: "اكتب مبلغًا صحيحًا." };

  const { error } = await supabase.rpc("set_period_section_allocation", {
    p_period_section_budget_id: id,
    p_planned_amount: amount,
  });
  if (error) return { error: friendlyError(error, "هذا المخصص يتجاوز ميزانية المصروف المتاحة.") };

  revalidatePath("/app/plan");
  return initialState;
}

// ---------- Lifecycle ----------

export async function startMonth(_previousState: PlanActionState, formData: FormData): Promise<PlanActionState> {
  const { supabase } = await requireSession();
  const periodId = parseId(formData.get("periodId"));
  if (!periodId) return { error: "تعذر التعرف على الفترة الحالية. حدّث الصفحة." };

  const { error } = await supabase.rpc("set_budget_period_status", {
    p_period_id: periodId,
    p_status: "open",
  });
  if (error) return { error: friendlyError(error, "تعذر بدء الشهر الآن. حاول مرة أخرى.") };

  revalidatePath("/app/plan");
  return initialState;
}
