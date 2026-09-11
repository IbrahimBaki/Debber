"use client";

import Image from "next/image";
import Link from "next/link";
import { useActionState } from "react";

import styles from "@/app/app/onboarding.module.css";

import { inviteMember, type InviteActionState } from "./actions";

const initialState: InviteActionState = {};

export function InvitePartnerForm({
  householdId,
  householdName,
}: {
  householdId: string;
  householdName: string;
}) {
  const [state, action, pending] = useActionState(inviteMember, initialState);

  if (state.success) {
    const expiresLabel = new Intl.DateTimeFormat("ar-EG", { dateStyle: "long" }).format(new Date(state.success.expiresAt));
    return (
      <main className={styles.page}>
        <section className={styles.ready} aria-labelledby="invite-ready-title">
          <Image src="/brand/mark.svg" alt="" width={42} height={42} priority />
          <p className={styles.readyLead}>{householdName}</p>
          <h1 id="invite-ready-title" role="status">الدعوة جاهزة</h1>
          <p className={styles.readyRole} dir="ltr">{state.success.email}</p>
          <p className={styles.intro}>
            خلي شريكك يسجل في دبّر بنفس البريد ده خلال 7 أيام. بعد تسجيل الدخول هتظهر له الدعوة تلقائيًا ويقدر يقبلها.
          </p>
          <p className={styles.intro}>
            صالحة حتى <bdi dir="ltr">{expiresLabel}</bdi>.
          </p>
          <Link className={styles.quietButton} href="/app">العودة للرئيسية</Link>
        </section>
      </main>
    );
  }

  return (
    <main className={styles.page}>
      <section className={styles.flow} aria-labelledby="invite-title">
        <Image src="/brand/mark.svg" alt="" width={42} height={42} priority />
        <h1 id="invite-title">دعوة شريك</h1>
        <p className={styles.intro}>ادعُ شريكك للانضمام إلى {householdName} كعضو في البيت.</p>
        <form action={action} className={styles.form} noValidate>
          <input type="hidden" name="householdId" value={householdId} />
          <div className={styles.field}>
            <label htmlFor="invite-email">البريد الإلكتروني</label>
            <input
              id="invite-email"
              name="email"
              type="email"
              dir="ltr"
              autoComplete="email"
              placeholder="partner@example.com"
              required
              disabled={pending}
              aria-describedby={state.error ? "invite-email-error" : undefined}
            />
          </div>
          {state.error ? (
            <p className={styles.error} id="invite-email-error" role="alert">
              {state.error}
            </p>
          ) : null}
          <button className={styles.primaryButton} disabled={pending}>
            {pending ? "جارٍ الإنشاء…" : "إنشاء الدعوة"}
          </button>
        </form>
      </section>
    </main>
  );
}
