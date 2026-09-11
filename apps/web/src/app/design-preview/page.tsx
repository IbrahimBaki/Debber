import type { ReactNode } from "react";
import Image from "next/image";
import styles from "./page.module.css";

type IconName = "home" | "plan" | "activity" | "more" | "plus" | "chevron" | "check" | "clock" | "skip" | "alert" | "receipt" | "spark" | "arrow";

function Icon({ name, size = 20 }: { name: IconName; size?: number }) {
  const paths: Record<IconName, ReactNode> = {
    home: <><path d="M3 10.8 12 3l9 7.8v8.7a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 19.5v-8.7Z"/><path d="M9 21v-6h6v6"/></>,
    plan: <><path d="M4 5.5h16M4 12h11M4 18.5h16"/><path d="M17 9.5v5M14.5 12h5"/></>,
    activity: <><path d="M4 17.5 8.2 13l3.4 2.7L20 6.5"/><path d="M16 6.5h4v4"/></>,
    more: <><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></>,
    plus: <><path d="M12 5v14M5 12h14"/></>,
    chevron: <path d="m9 18 6-6-6-6"/>,
    check: <path d="m5 12 4.1 4L19 6.8"/>,
    clock: <><circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3.5 2"/></>,
    skip: <><path d="M6 6v12M9.5 8.5 15 12l-5.5 3.5"/><path d="M18 6v12"/></>,
    alert: <><path d="M12 3 21 20H3L12 3Z"/><path d="M12 9v4.5M12 17h.01"/></>,
    receipt: <><path d="M6 3.5h12v17l-3-1.7-3 1.7-3-1.7-3 1.7v-17Z"/><path d="M9 8h6M9 12h6"/></>,
    spark: <path d="m12 3 1.65 5.35L19 10l-5.35 1.65L12 17l-1.65-5.35L5 10l5.35-1.65L12 3Z"/>,
    arrow: <><path d="M5 12h14"/><path d="m13 6 6 6-6 6"/></>,
  };

  return <svg aria-hidden="true" className={styles.icon} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{paths[name]}</svg>;
}

function Amount({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <span className={`${styles.amount} ${className}`} dir="rtl">{children}<small>ج.م</small></span>;
}

const expenses = [
  ["سوبر ماركت", "اليوم، ١:٢٠ م", "١٬٢٨٥٫٥٠", "food"],
  ["خضار وفاكهة", "أمس، ٦:٤٠ م", "٣٤٠٫٠٠", "produce"],
  ["صيدلية", "١٠ سبتمبر", "١٨٥٫٧٥", "care"],
  ["مواصلات", "١٠ سبتمبر", "٩٥٫٠٠", "move"],
] as const;

const recurring = [
  ["فاتورة الكهرباء", "مستحقة ١٥ سبتمبر", "معلّق", "pending"],
  ["الإنترنت", "تم السداد في ٨ سبتمبر", "تم السداد", "paid"],
  ["اشتراك النادي", "مؤجل لهذا الشهر", "تم التخطي", "skipped"],
  ["مصروف المدرسة", "مستحق ٢٢ سبتمبر", "معلّق", "pending"],
] as const;

export default function DesignPreview() {
  return (
    <main className={styles.app} dir="rtl">
      <aside className={styles.rail} aria-label="التنقل الرئيسي">
        <div className={styles.railBrand}><Image src="/brand/mark.svg" alt="دبّر" width={39} height={53} /></div>
        <nav className={styles.railNav}>
          <a className={styles.railActive} href="#overview" aria-current="page"><Icon name="home" /><span>الرئيسية</span></a>
          <a href="#sections"><Icon name="plan" /><span>الخطة</span></a>
          <a href="#activity"><Icon name="activity" /><span>النشاط</span></a>
          <a href="#states"><Icon name="more" /><span>المزيد</span></a>
        </nav>
        <div className={styles.railFoot}><span className={styles.avatar}>س</span><span>سارة وعمرو</span></div>
      </aside>

      <div className={styles.content}>
        <header className={styles.topbar}>
          <button className={styles.household} type="button" aria-label="اختيار المنزل"><span className={styles.avatar}>س</span><span><b>سارة وعمرو</b><small>منزلنا</small></span><Icon name="chevron" size={16} /></button>
          <Image className={styles.wordmark} src="/brand/wordmark-ar.svg" alt="دبّر" width={1064} height={808} priority />
          <button className={styles.desktopAction} type="button"><Icon name="plus" size={19} />إضافة مصروف</button>
        </header>

        <div className={styles.pageHead} id="overview">
          <div><p className={styles.month}>سبتمبر ٢٠٢٦ <span>•</span> الشهر مفتوح</p><h1>وضع الشهر واضح.</h1><span className={styles.sharedCue}>مساحة مشتركة <i /> الأرقام المعروضة ضمن نطاقك</span></div>
          <button className={styles.monthButton} type="button">تغيير الشهر <Icon name="chevron" size={16} /></button>
        </div>

        <section className={styles.balance} aria-labelledby="balance-title">
          <div className={styles.balanceIntro}><p id="balance-title">المتاح للصرف الآن</p><Amount className={styles.balanceAmount}>٤٬٦٥٩٫٧٥</Amount><span>ضمن الأقسام المشتركة المعروضة لك</span></div>
          <div className={styles.balanceStats}>
            <div><span>ميزانية الأقسام</span><Amount>١٢٬٥٠٠٫٠٠</Amount></div>
            <div><span>المصروف حتى الآن</span><Amount>٧٬٨٤٠٫٢٥</Amount></div>
          </div>
          <div className={styles.allocation} role="progressbar" aria-label="نسبة المصروف من ميزانية الأقسام" aria-valuemin={0} aria-valuemax={12500} aria-valuenow={7840} aria-valuetext="تم صرف ٧٨٤٠٫٢٥ جنيه من ميزانية أقسام قدرها ١٢٥٠٠ جنيه">
            <span className={styles.spentTrack} /><span className={styles.remainingTrack} />
          </div>
          <div className={styles.allocationLabels}><span><i className={styles.spentDot} />مصروف ٦٣٪</span><span><i className={styles.remainingDot} />متبقي ٣٧٪</span></div>
        </section>

        <div className={styles.desktopGrid}>
        <section className={styles.sectionBlock} id="sections" aria-labelledby="section-title">
          <div className={styles.sectionHeading}><div><p>الأقسام</p><h2 id="section-title">مصروف البيت</h2></div><button className={styles.textAction} type="button">عرض الخطة <Icon name="arrow" size={17} /></button></div>
          <div className={styles.sectionSurface}>
            <div className={styles.sectionMeta}><span>المخصص <Amount>٦٬٠٠٠٫٠٠</Amount></span><span>المصروف <Amount>٤٬٨٢٠٫٥٠</Amount></span></div>
            <div className={styles.sectionBar}><span style={{ width: "80%" }} /></div>
            <div className={styles.remainingLine}><span>المتبقي للصرف</span><Amount>١٬١٧٩٫٥٠</Amount></div>
          </div>
          <div className={`${styles.sectionSurface} ${styles.overSurface}`}>
            <div className={styles.sectionMeta}><span>التنقل والاحتياجات</span><span className={styles.stateDanger}><Icon name="alert" size={16} />تجاوزت المخصص</span></div>
            <div className={styles.sectionBar}><span style={{ width: "100%" }} /></div>
            <div className={styles.remainingLine}><span>مخصص <Amount>٩٠٠٫٠٠</Amount></span><span className={styles.negative}>تجاوز بمقدار <Amount>١٢٠٫٠٠</Amount></span></div>
          </div>
        </section>

        <section className={styles.sectionBlock} id="activity" aria-labelledby="recurring-title">
          <div className={styles.sectionHeading}><div><p>التزامات الشهر</p><h2 id="recurring-title">البنود الدورية</h2></div><button className={styles.textAction} type="button">كل البنود <Icon name="arrow" size={17} /></button></div>
          <div className={styles.listSurface}>
            {recurring.map(([name, detail, state, tone]) => <div className={styles.recurringRow} key={name}>
              <span className={`${styles.stateGlyph} ${styles[tone]}`}>{tone === "paid" ? <Icon name="check" size={16} /> : tone === "skipped" ? <Icon name="skip" size={16} /> : <Icon name="clock" size={16} />}</span>
              <div><strong>{name}</strong><small>{detail}</small></div><span className={`${styles.status} ${styles[tone]}`}>{state}</span>
            </div>)}
          </div>
        </section>

        <section className={`${styles.sectionBlock} ${styles.expensesBlock}`} aria-labelledby="expenses-title">
          <div className={styles.sectionHeading}><div><p>آخر ما تم تسجيله</p><h2 id="expenses-title">المصروفات الأخيرة</h2></div><button className={styles.textAction} type="button">السجل <Icon name="arrow" size={17} /></button></div>
          <div className={styles.listSurface}>
            {expenses.map(([name, date, amount, tone]) => <div className={styles.expenseRow} key={name}>
              <span className={`${styles.expenseGlyph} ${styles[tone]}`}><Icon name="receipt" size={18} /></span>
              <div><strong>{name}</strong><small>{date}</small></div><Amount>{amount}</Amount>
            </div>)}
          </div>
        </section>
        </div>

        <section className={styles.states} id="states" aria-labelledby="states-title">
          <div className={styles.sectionHeading}><div><p>حالات الواجهة</p><h2 id="states-title">عندما لا تسير الأمور كالمعتاد</h2></div></div>
          <div className={styles.stateGrid}>
            <article className={styles.emptyState}><span><Icon name="spark" size={23} /></span><h3>بداية هادئة</h3><p>لا توجد مصروفات في هذا القسم بعد.</p><button type="button">إضافة أول مصروف</button></article>
            <article className={styles.loadingState} role="status" aria-busy="true" aria-label="جاري تحميل المصروفات"><div className={styles.skeletonTitle} /><div className={styles.skeletonLine} /><div className={styles.skeletonLine} /></article>
            <article className={styles.successState} role="status" aria-live="polite"><span><Icon name="check" size={20} /></span><div><h3>تم تسجيل المصروف</h3><p>أصبح ضمن مصروف البيت.</p></div></article>
            <article className={styles.errorState} role="alert"><span><Icon name="alert" size={20} /></span><div><h3>تعذر حفظ المصروف</h3><p>تحقق من الاتصال ثم أعد المحاولة.</p><button type="button">إعادة المحاولة</button></div></article>
          </div>
        </section>
      </div>

      <button className={styles.expenseAction} type="button" aria-label="إضافة مصروف"><Icon name="plus" size={22} /><span>إضافة مصروف</span></button>
      <nav className={styles.mobileNav} aria-label="التنقل الرئيسي"><a className={styles.navActive} href="#overview" aria-current="page"><Icon name="home" /><span>الرئيسية</span></a><a href="#sections"><Icon name="plan" /><span>الخطة</span></a><a href="#activity"><Icon name="activity" /><span>النشاط</span></a><a href="#states"><Icon name="more" /><span>المزيد</span></a></nav>
    </main>
  );
}
