"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type ExpenseActionState = {
  error?: string;
  success?: {
    transactionId: string;
    amount: number;
    sectionName: string;
    currencyCode: string;
    overspent: boolean;
    overspentBy: number;
  };
};

const initialState: ExpenseActionState = {};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const amountPattern = /^\d{1,10}(\.\d{1,2})?$/;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

function friendlyError(error: { code?: string; message?: string } | null, fallback: string): string {
  if (!error) return fallback;
  const message = error.message ?? "";
  if (message.includes("period_not_open")) return "الشهر ده مش مفتوح لتسجيل مصروفات دلوقتي.";
  if (message.includes("expense_date_out_of_period")) return "اختار تاريخ داخل الشهر الحالي.";
  if (message.includes("expense_date_in_future")) return "التاريخ ده لسه ما جاش.";
  if (message.includes("not_authorized")) return "مش متاح تسجيل مصروف في القسم ده دلوقتي.";
  if (message.includes("invalid_amount")) return "اكتب مبلغًا صحيحًا أكبر من صفر.";
  if (message.includes("invalid_description")) return "الملاحظة طويلة جدًا.";
  if (message.includes("section_budget_not_found")) return "تعذر التعرف على القسم. حدّث الصفحة وحاول مرة أخرى.";
  if (message.includes("not_authenticated")) return "انتهت الجلسة. سجّل الدخول مرة أخرى.";
  if (error.code === "23505") return "حدث تعارض غير متوقع. حدّث الصفحة وحاول مرة أخرى.";
  return fallback;
}

export async function recordExpenseAction(_previousState: ExpenseActionState, formData: FormData): Promise<ExpenseActionState> {
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims?.sub) redirect("/login?next=/app/expenses/new");

  const periodSectionBudgetId = String(formData.get("periodSectionBudgetId") ?? "");
  const transactionId = String(formData.get("transactionId") ?? "");
  const amountRaw = String(formData.get("amount") ?? "").trim();
  const occurredAt = String(formData.get("occurredAt") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const sectionName = String(formData.get("sectionName") ?? "");
  const currencyCode = String(formData.get("currencyCode") ?? "");

  if (!uuidPattern.test(periodSectionBudgetId)) return { error: "تعذر التعرف على القسم. حدّث الصفحة." };
  if (!uuidPattern.test(transactionId)) return { error: "تعذر إتمام العملية. حدّث الصفحة وحاول مرة أخرى." };
  if (!amountPattern.test(amountRaw) || !(Number(amountRaw) > 0)) return { error: "اكتب مبلغًا صحيحًا أكبر من صفر." };
  if (occurredAt && !datePattern.test(occurredAt)) return { error: "اختار تاريخًا صحيحًا." };
  const amount = Number(amountRaw);

  const { data: newTransactionId, error } = await supabase.rpc("record_expense", {
    p_period_section_budget_id: periodSectionBudgetId,
    p_amount: amount,
    p_occurred_at: occurredAt || undefined,
    p_description: description || undefined,
    p_transaction_id: transactionId,
  });

  if (error) return { error: friendlyError(error, "تعذر تسجيل المصروف الآن. حاول مرة أخرى.") };

  // Server truth wins: refetch the section's actual totals after the mutation rather than
  // computing the overspend state from anything the client sent.
  const [{ data: sectionRow }, { data: txRows }] = await Promise.all([
    supabase.from("period_section_budgets").select("planned_amount").eq("id", periodSectionBudgetId).maybeSingle(),
    supabase.from("transactions").select("amount").eq("period_section_budget_id", periodSectionBudgetId).eq("state", "posted"),
  ]);
  const spent = (txRows ?? []).reduce((sum, row) => sum + Number(row.amount), 0);
  const remaining = Number(sectionRow?.planned_amount ?? 0) - spent;

  revalidatePath("/app/expenses/new");
  revalidatePath("/app");

  return {
    success: {
      transactionId: newTransactionId as string,
      amount,
      sectionName,
      currencyCode,
      overspent: remaining < 0,
      overspentBy: remaining < 0 ? Math.abs(remaining) : 0,
    },
  };
}

export async function voidExpenseAction(_previousState: ExpenseActionState, formData: FormData): Promise<ExpenseActionState> {
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims?.sub) redirect("/login?next=/app/expenses/new");

  const transactionId = String(formData.get("transactionId") ?? "");
  if (!uuidPattern.test(transactionId)) return { error: "تعذر التعرف على المصروف." };

  const { error } = await supabase.rpc("void_transaction", { p_transaction_id: transactionId });
  if (error) return { error: friendlyError(error, "تعذر إلغاء المصروف الآن. حاول مرة أخرى.") };

  revalidatePath("/app/expenses/new");
  revalidatePath("/app");
  return initialState;
}
