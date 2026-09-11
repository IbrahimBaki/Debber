"use client";

import Image from "next/image";
import { useActionState, useState } from "react";

import { acceptInvitation, type OnboardingActionState } from "@/app/app/actions";
import styles from "@/app/app/onboarding.module.css";

type Invitation = { invitation_id: string; household_name: string; inviter_display_name: string | null; created_at: string; expires_at: string };

const initialState: OnboardingActionState = {};

export function InvitationFlow({ invitations }: { invitations: Invitation[] }) {
  const [selectedId, setSelectedId] = useState(invitations[0]?.invitation_id);
  const [state, action, pending] = useActionState(acceptInvitation, initialState);
  const selected = invitations.find((invitation) => invitation.invitation_id === selectedId) ?? invitations[0];
  const multiple = invitations.length > 1;

  return (
    <main className={styles.page}>
      <section className={styles.flow} aria-labelledby="invitation-title">
        <Image src="/brand/mark.svg" alt="" width={42} height={42} priority />
        <h1 id="invitation-title">{multiple ? "اختر البيت الذي تريد الانضمام إليه" : "أنت مدعو للانضمام إلى بيت مشترك"}</h1>
        <p className={styles.intro}>{multiple ? "اختر دعوة واحدة ثم أكّد قرارك. لن نقبل أي دعوة تلقائيًا." : "هذه مساحة مالية مشتركة. لن تظهر أي تفاصيل مالية قبل قبولك للدعوة."}</p>
        <form action={action} className={styles.form}>
          <fieldset className={styles.invitationList} disabled={pending}>
            <legend className="sr-only">الدعوات المتاحة</legend>
            {invitations.map((invitation) => (
              <label className={`${styles.invitation} ${selectedId === invitation.invitation_id ? styles.selected : ""}`} key={invitation.invitation_id}>
                <input type="radio" name="invitationId" value={invitation.invitation_id} checked={selectedId === invitation.invitation_id} onChange={() => setSelectedId(invitation.invitation_id)} />
                <span><strong>{invitation.household_name}</strong><small>{invitation.inviter_display_name ? `دعوة من ${invitation.inviter_display_name}` : "دعوة للانضمام إلى مساحة مشتركة"}</small></span>
              </label>
            ))}
          </fieldset>
          {selected ? <p className={styles.expiry}>صالح حتى <bdi dir="ltr">{new Intl.DateTimeFormat("ar-EG", { dateStyle: "medium" }).format(new Date(selected.expires_at))}</bdi></p> : null}
          {state.error ? <p className={styles.error} role="alert">{state.error}</p> : null}
          <button className={styles.primaryButton} disabled={pending}>{pending ? "جارٍ قبول الدعوة…" : "قبول الدعوة"}</button>
        </form>
      </section>
    </main>
  );
}
