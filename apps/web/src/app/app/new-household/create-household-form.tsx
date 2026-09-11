"use client";

import Image from "next/image";
import { useActionState, useEffect, useState } from "react";

import { createInitialHousehold, type OnboardingActionState } from "@/app/app/actions";
import styles from "@/app/app/onboarding.module.css";

const currencies = [
  ["EGP", "جنيه مصري"],
  ["SAR", "ريال سعودي"],
  ["USD", "دولار أمريكي"],
  ["EUR", "يورو"],
] as const;

const initialState: OnboardingActionState = {};

export function CreateHouseholdForm() {
  const [state, action, pending] = useActionState(createInitialHousehold, initialState);
  const [timezone, setTimezone] = useState("");
  const [timezoneChanged, setTimezoneChanged] = useState(false);
  const [detectionFailed, setDetectionFailed] = useState(false);
  const [timezones, setTimezones] = useState<string[]>([]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      try {
        const detected = Intl.DateTimeFormat().resolvedOptions().timeZone;
        if (detected && detected.trim()) setTimezone(detected);
        else setDetectionFailed(true);
        setTimezones(Intl.supportedValuesOf?.("timeZone") ?? []);
      } catch { setDetectionFailed(true); }
    }, 0);
    return () => window.clearTimeout(timer);
  }, []);

  return (
    <main className={styles.page}>
      <section className={styles.flow} aria-labelledby="create-household-title">
        <Image src="/brand/mark.svg" alt="" width={42} height={42} priority />
        <h1 id="create-household-title">خلّينا نرتب البيت</h1>
        <p className={styles.intro}>اختيارات بسيطة الآن، وبعدها نكمل تجهيز الميزانية وقت ما تكون جاهز.</p>
        <form action={action} className={styles.form} noValidate>
          <div className={styles.field}>
            <label htmlFor="household-name">اسم البيت</label>
            <input id="household-name" name="name" required maxLength={120} placeholder="بيتنا" autoComplete="organization" disabled={pending} />
          </div>
          <fieldset className={styles.currencyGroup} disabled={pending}>
            <legend>العملة</legend>
            <div className={styles.currencyOptions}>
              {currencies.map(([code, label]) => (
                <label key={code} className={styles.currencyOption}>
                  <input type="radio" name="currency" value={code} defaultChecked={code === "EGP"} />
                  <span dir="ltr">{code}</span><small>{label}</small>
                </label>
              ))}
            </div>
          </fieldset>
          <div className={styles.field}>
            <label htmlFor="period-start-day">بداية الشهر المالي</label>
            <select id="period-start-day" name="periodStartDay" defaultValue="1" disabled={pending}>
              {Array.from({ length: 31 }, (_, index) => index + 1).map((day) => <option value={day} key={day}>{day}</option>)}
            </select>
            <p>يمكنك اختيار موعد دورة الراتب. إذا لم يوجد اليوم في شهر ما، نستخدم آخر يوم فيه.</p>
          </div>
          <div className={styles.timezone}>
            <div><strong>المنطقة الزمنية</strong><p>تُستخدم لحساب بداية الفترة الشهرية.</p></div>
            {!timezoneChanged && timezone ? <button type="button" className={styles.changeButton} onClick={() => setTimezoneChanged(true)}>تغيير</button> : null}
            {timezoneChanged || !timezone ? (
              timezones.length ? (
                <select aria-label="المنطقة الزمنية" name="timezone" value={timezone} onChange={(event) => setTimezone(event.target.value)} required disabled={pending}>
                  <option value="">اختر المنطقة الزمنية</option>
                  {timezones.map((zone) => <option value={zone} key={zone}>{zone}</option>)}
                </select>
              ) : <input aria-label="المنطقة الزمنية" name="timezone" value={timezone} onChange={(event) => setTimezone(event.target.value)} placeholder="Africa/Cairo" required disabled={pending} />
            ) : <><bdi className={styles.timezoneValue} dir="ltr">{timezone}</bdi><input type="hidden" name="timezone" value={timezone} /></>}
            {detectionFailed ? <p className={styles.warning} role="status">لم نتمكن من تحديد منطقتك الزمنية. اخترها يدويًا للمتابعة.</p> : null}
          </div>
          {state.error ? <p className={styles.error} role="alert">{state.error}</p> : null}
          <button className={styles.primaryButton} disabled={pending}>{pending ? "جارٍ إنشاء البيت…" : "إنشاء البيت"}</button>
        </form>
      </section>
    </main>
  );
}
