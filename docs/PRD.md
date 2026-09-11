# دبّر | Dabber

**منصة إدارة مالية مشتركة بخصوصية انتقائية للأسر والشركاء**  
**PRD v2.0** · 10 سبتمبر 2026 · Architecture locked · جاهز للتنفيذ عبر Next.js + Supabase + Vercel

> القرار الأساسي: **Share the budget, not necessarily every number.**

## 1. الملخص التنفيذي

دبّر هو تطبيق Web/PWA لإدارة ميزانية شهرية مشتركة بين شخصين - مثل زوجين أو شريكين - مع ميزة محورية تميّزه عن تطبيقات المصروفات التقليدية: مشاركة ما يلزم للتعاون فقط، من غير افتراض أن كل البيانات المالية يجب أن تكون مكشوفة للطرف الآخر.

المالك المالي للـWorkspace يجهّز خطة الشهر: مصادر الدخل، الالتزامات الثابتة، ومبالغ مخصصة لأقسام تشغيلية مثل مصروف البيت. كل بند دوري يُنشأ له Snapshot مستقل داخل الشهر، بحيث يمكن تعديل الشهر الحالي من غير تغيير التاريخ السابق، ويمكن متابعة كل بند بحالة Pending / Paid / Skipped وربطه بمصروف فعلي عند الحاجة.

الشريك يرى ويتعامل فقط مع الأقسام والبنود التي سُمح له بها. الصلاحيات تُنفذ على مستوى الخادم وقاعدة البيانات، وليس بمجرد إخفاء عناصر من الواجهة. كما تُطبق قواعد لمنع كشف معلومات مخفية بصورة غير مباشرة من خلال الإجماليات أو الرسوم البيانية.

> **مهم:** قرار المنتج الأساسي: "Share the budget, not necessarily every number" - شارك ميزانية التعاون، وليس بالضرورة كل أرقامك المالية.

## 2. المشكلة والفرصة

### 2.1 المشكلة التي نحلها

- الميزانية الشهرية عند كثير من الأسر موزعة بين ملاحظات، رسائل، جداول، أو الذاكرة؛ فيصعب معرفة ما تم دفعه وما تبقى.
- المصروفات الثابتة تتكرر شهريًا، لكن إعادة إدخالها يدويًا مرهقة، بينما تعديل القالب مباشرة قد يفسد التاريخ السابق.
- التعاون المالي لا يعني دائمًا الشفافية الكاملة: قد يرغب صاحب الحساب في مشاركة ميزانية البيت فقط مع إخفاء إجمالي دخله أو التزامات شخصية محددة.
- تطبيقات تسجيل المصروفات غالبًا تركز على الفرد أو على مشاركة كاملة، ولا تتعامل جيدًا مع درجات مختلفة من الرؤية داخل نفس الميزانية.

### 2.2 الفرصة

نبني نظامًا خفيفًا للاستخدام اليومي، لكنه قائم على نموذج بيانات يصلح لاحقًا للتدبير، أهداف الشراء، الصناديق المخصصة Sinking Funds، الديون، ومتابعة الادخار، من غير أن نحمّل النسخة الأولى بكل هذه التعقيدات.

## 3. الرؤية ومبادئ المنتج

### 3.1 الرؤية

أن يصبح دبّر مساحة مالية مشتركة للأسرة: تخطيط شهري، متابعة يومية، ورؤية واضحة لما يخص كل عضو، مع خصوصية مقصودة وقابلة للضبط.

### 3.2 مبادئ التصميم

| المبدأ | ما يعنيه عمليًا |
| --- | --- |
| Privacy by Design | كل Resource مالي له سياسة رؤية، والـOwner يملك الوصول دائمًا، بينما باقي الأعضاء لا يرون إلا ما مُنح لهم. |
| Monthly Snapshots | القوالب الدورية تُنسخ لكل شهر؛ تعديل القالب اليوم لا يغير يناير أو فبراير. |
| Mobile First | إضافة مصروف متكرر الاستخدام يجب أن تكون سريعة ومناسبة للإبهام والشاشة الصغيرة. |
| Explainable Money | كل رقم إجمالي يجب أن يكون مفهوم المصدر، ولا نعتمد على أرقام سحرية أو حسابات غير قابلة للتتبع. |
| No Privacy Inference | لا نعرض مشتقات يمكن منها استنتاج بيانات مخفية إلا إذا وافق الـOwner صراحة على مشاركة المشتق. |
| Progressive Complexity | الـMVP بسيط؛ الادخار والأهداف والبنوك والإيصالات تُضاف لاحقًا فوق نفس الأساس. |

## 4. المستخدمون والأدوار

### 4.1 الشخصيات الأساسية

| الشخصية | الاحتياج الأساسي | السلوك المتوقع |
| --- | --- | --- |
| Household Owner | تخطيط الدخل والالتزامات وتحديد ما يُشارك | يبدأ الشهر، يحدد الميزانيات، يدعو الشريك، ويتحكم في الرؤية. |
| Partner / Member | تسجيل ومتابعة المصروفات المشتركة من غير الحاجة لرؤية الصورة المالية كاملة | يضيف مصروفات، يعلّم البنود المدفوعة، ويرى رصيد الأقسام المسموح بها. |

### 4.2 قرارات نطاق v1

- الـWorkspace مصمم أساسًا لشخصين في الـMVP، لكن الـschema لا يمنع دعم أكثر من عضو لاحقًا.
- يوجد Owner واحد لكل Workspace. نقل الملكية Feature لاحقة أو أداة إدارية محدودة.
- عملة واحدة لكل Workspace في v1 لتجنب تعقيد تحويل العملات.
- يمكن للمستخدم امتلاك أكثر من Workspace تقنيًا، لكن تجربة الـMVP تركز على Workspace رئيسي واحد.

### 4.3 Platform Super Admin

يوجد دور مستقل على مستوى المنصة باسم `SUPER_ADMIN`. هذا الدور ليس عضوًا ماليًا داخل الـWorkspace، ولا يُشتق من `Owner/Member`. الـSuper Admin يدخل من تطبيق إداري منفصل، ويملك وصولًا خادميًا كاملًا للبيانات وSupabase Auth لأغراض الإدارة والدعم، مع Audit Log إلزامي لأي إجراء حساس.

## 5. نطاق الـMVP وما هو خارج النطاق

### 5.1 داخل نطاق الـMVP

- تسجيل الدخول وإنشاء الحساب بالبريد الإلكتروني وكلمة المرور، مع تأكيد البريد الإلكتروني الإلزامي واستعادة كلمة المرور بالبريد.
- إنشاء Workspace وضبط الاسم، العملة، المنطقة الزمنية، وبداية الدورة الشهرية.
- دعوة شريك والانضمام للـWorkspace.
- إدخال مصدر أو أكثر للدخل الشهري، مع تحكم في الرؤية.
- إنشاء أقسام Budget Sections مثل: التزامات ثابتة، مصروف البيت، مواصلات، مصروف شخصي مشترك... إلخ.
- قوالب Recurring Templates للبنود المتكررة شهريًا، مثل إيجار، قسط، جمعية، إنترنت، أو بند شراء دوري.
- إنشاء Monthly Snapshot من القوالب مع Planned Amount وDue Date وStatus.
- ميزانية شهرية لكل قسم ومتابعة Planned / Spent / Remaining.
- إضافة مصروفات فعلية Transactions مع المبلغ والتاريخ والوصف والقسم ومن أضاف المصروف.
- ربط المصروف ببند شهري دوري عند الحاجة لمنع العد المزدوج.
- صلاحيات رؤية وتعديل على مستوى القسم والبند/المصدر الحساس.
- Dashboard مختلف بحسب الصلاحيات.
- تاريخ شهري History مع عدم تغيير snapshots القديمة عند تعديل القوالب.
- Audit Log للأحداث الحساسة مثل تغيير الرؤية، تعديل ميزانية، أو حذف مصروف.
- PWA قابلة للإضافة للشاشة الرئيسية، مع تجربة Standalone ومظهر Mobile-first.
- Super Admin Dashboard كتطبيق Next.js منفصل وVercel Project منفصل، وليس UI إضافية داخل تطبيق المستخدم.

### 5.2 خارج نطاق الـMVP

- ربط الحسابات البنكية أو Open Banking.
- تحويل أو دفع أموال من داخل التطبيق.
- Splitwise-style debt settlement المعقد بين عدد كبير من الأشخاص.
- OCR للإيصالات أو استخراج المصروف تلقائيًا من صورة.
- تعدد العملات داخل نفس Workspace.
- Offline-first writes ومزامنة التعارضات؛ النسخة الأولى Online-first.
- استثمارات، أسهم، ضرائب، محاسبة رسمية، أو تقارير قانونية.
- أهداف الادخار والشراء كـFeature كاملة - مصممة في الـRoadmap لكن غير مطلوبة للـMVP.

## 6. النموذج المالي للمنتج

أفضل نموذج ذهني للواجهة ليس "الدخل ناقص المصاريف" فقط، بل طبقات واضحة تمنع خلط الالتزامات بالميزانيات التشغيلية:

| الطبقة | التعريف | مثال |
| --- | --- | --- |
| Income | كل الدخل المخطط للشهر | راتب + دخل إضافي |
| Fixed Commitments | التزامات شبه حتمية أو محددة مسبقًا | إيجار، أقساط، جمعيات |
| Flexible Allocations | مبالغ يقرر الـOwner إتاحتها للصرف داخل أقسام | مصروف البيت 12,000 |
| Reserve / Unallocated | المتبقي غير المخصص بعد الالتزامات والميزانيات | احتياطي أو مبلغ غير مخطط |
| Future Savings Allocations | مبالغ توجه لأهداف أو تدبير | تدبير سيارة / سفر |

```text
Total Income - Fixed Commitments - Flexible Allocations - Savings Allocations = Unallocated / Reserve
```

في الـMVP، Savings Allocations يمكن أن تظل صفرًا أو ممثلة مؤقتًا كقسم عادي. عند إضافة Feature التدبير لاحقًا تتحول إلى Domain مستقل من غير تغيير مفهوم الشهر.

## 7. مفاهيم الـDomain الأساسية

| المفهوم | التعريف |
| --- | --- |
| Workspace | المساحة المشتركة التي تحتوي الأعضاء، الإعدادات، والفترات المالية. |
| Budget Period | دورة مالية شهرية أو دورة تبدأ في يوم محدد؛ لها Draft / Open / Closed. |
| Income Item | مصدر دخل خاص بفترة معينة، ويمكن أن يكون خاصًا بالـOwner. |
| Budget Section | وعاء مالي منطقي مثل مصروف البيت أو المواصلات. |
| Recurring Template | قالب دائم لبند يتكرر؛ لا يمثل عملية دفع تاريخية بنفسه. |
| Monthly Item | Snapshot للبند المتكرر داخل فترة واحدة، له مبلغ وحالة وتاريخ استحقاق مستقل. |
| Transaction | مصروف فعلي حدث، ويمكن ربطه بـMonthly Item. |
| Visibility Policy | سياسة تحدد من يمكنه View/Edit للـResource. |
| Audit Event | سجل غير قابل للتعديل بسهولة يوضح من غيّر ماذا ومتى في الأحداث الحساسة. |

## 8. دورة الشهر والـSnapshots

### 8.1 إنشاء شهر جديد

1. عند أول فتح للشهر الجديد، أو عبر Cron استباقي، يستدعي النظام عملية idempotent باسم منطقي ensure_period(workspace, month).
2. يُنشأ Budget Period مرة واحدة فقط بفضل Unique Constraint على workspace_id + period_key.
3. تُنسخ القوالب الدورية النشطة إلى Monthly Items مع الاسم والمبلغ الافتراضي وموعد الاستحقاق وسياسة الرؤية في لحظة النسخ.
4. تُنسخ ميزانيات الأقسام من آخر إعداد معتمد، ويظهر الشهر في Draft للـOwner للمراجعة.
5. الـOwner يعدل ما يلزم ثم يفتح الشهر Open. الشريك لا يحتاج رؤية شاشة التخطيط الكاملة إذا لم تكن لديه صلاحية.

### 8.2 لماذا Snapshot وليس قراءة القالب مباشرة؟

- الإيجار قد يتغير في مايو، لكن تاريخ يناير - أبريل يجب أن يظل كما كان.
- يمكن تخطي بند في شهر واحد من غير إلغاء القالب للأشهر التالية.
- يمكن تسجيل Actual Amount مختلف عن Planned Amount لشهر بعينه.
- التقارير التاريخية تصبح قابلة لإعادة البناء بثقة.

### 8.3 حالات Monthly Item

| الحالة | المعنى |
| --- | --- |
| Pending | موجود في خطة الشهر ولم يُسجل دفعه بعد. |
| Paid | تم دفعه؛ يُفضّل ربطه بـTransaction فعلية. |
| Skipped | تم استبعاده لهذا الشهر فقط مع سبب اختياري. |

## 9. الصلاحيات والخصوصية

### 9.1 الأدوار الأساسية

| Capability | Owner | Member |
| --- | --- | --- |
| إدارة Workspace والأعضاء | نعم | لا |
| إضافة/تعديل الدخل | نعم | لا افتراضيًا |
| رؤية الدخل | نعم | بحسب Visibility Policy |
| تحديد ميزانية الأقسام | نعم | لا افتراضيًا |
| إضافة Transaction داخل قسم مسموح | نعم | نعم |
| تعديل Transaction أنشأه بنفسه | نعم | نعم - إذا لم يُغلق الشهر |
| تعديل Transactions الآخرين | نعم | اختياري لاحقًا؛ لا في الـMVP |
| تعليم Monthly Item كمدفوع | نعم | إذا كان مرئيًا ومسموح التعديل |
| تغيير Visibility | نعم | لا |
| إغلاق الشهر | نعم | لا |

### 9.2 مستويات الرؤية المقترحة

| Policy Mode | السلوك |
| --- | --- |
| Owner Only | لا يظهر للـMember إطلاقًا، ولا يظهر حتى كعنصر محجوب أو Placeholder. |
| All Members | يظهر لكل أعضاء الـWorkspace المصرح لهم. |
| Custom | قابل لمنح View/Edit لأعضاء محددين؛ لن تحتاجه الواجهة بقوة في v1 لكنه يحمي التوسع المستقبلي. |

### 9.3 منع تسريب البيانات عبر الأرقام المشتقة

> **مهم:** قاعدة إلزامية: واجهة الشريك لا تحسب Global Totals من بيانات بعضها مخفي ثم تعرض الناتج. كل View Model خاص بالـMember يُبنى من الموارد المرئية فقط، أو من Metric مُصرّح بمشاركته صراحة.

| السيناريو | السلوك الصحيح |
| --- | --- |
| الدخل مخفي، لكن مصروف البيت مشترك | الشريك يرى Budget/Spent/Remaining لمصروف البيت فقط؛ لا يرى Total Income ولا Remaining From Income. |
| قسط شخصي مخفي داخل التزامات ثابتة | لا يظهر اسم القسط أو مبلغه أو حتى عدّاد يوحي بوجود بند مخفي. |
| Global Remaining لو عُرض | يُعرض فقط إذا شاركه الـOwner كMetric مستقل أو كانت كل مكوناته مرئية. |
| Charts | تُبنى من dataset مصرح به فقط، ولا تضيف "Other hidden" افتراضيًا. |

### 9.4 تنفيذ أمني

- التحقق من الرؤية يجب أن يتم Server-side وداخل PostgreSQL RLS، وليس في React فقط.
- Service Role key لا يصل للمتصفح مطلقًا.
- كل جدول معرض للعميل يجب أن يملك RLS وGrants محددة، مع اختبارات Allow/Deny.
- التغييرات الحساسة في الصلاحيات تسجل Audit Event.

## 10. الرحلات الأساسية للمستخدم

### 10.1 Onboarding للـOwner

1. إنشاء حساب وتسجيل الدخول.
2. إنشاء Workspace: الاسم، العملة، المنطقة الزمنية، ويوم بداية الشهر.
3. إضافة مصادر الدخل أو تخطيها مؤقتًا.
4. إضافة الالتزامات الثابتة كقوالب Recurring.
5. إنشاء قسم أو أكثر للمصروفات المرنة وتحديد Budget لكل قسم.
6. دعوة الشريك.
7. مراجعة Visibility لكل قسم أو بند حساس قبل إرسال الدعوة أو بعدها.
8. فتح الشهر والبدء في التسجيل.

### 10.2 استخدام الشريك اليومي

1. يفتح Home فيرى فقط الأقسام المسموحة.
2. يختار Add Expense، يدخل المبلغ، القسم، وصفًا اختياريًا، والتاريخ.
3. تتحدث قيمة Spent وRemaining للقسم فورًا.
4. يمكنه فتح Checklist الخاصة بالشهر وتعليم بند مرئي Paid أو إدخال Actual Amount إذا مُنح Edit.

### 10.3 دفع بند دوري

1. يفتح Monthly Item.
2. يختار Mark as Paid.
3. يؤكد Actual Amount؛ القيمة الافتراضية هي Planned Amount.
4. النظام ينشئ Transaction مرتبطة بالبند أو يربط Transaction موجودة.
5. لا تدخل القيمة مرتين في إجمالي الصرف.

### 10.4 إغلاق الشهر

1. الـOwner يراجع البنود Pending والمبالغ الفعلية.
2. يعالج أي مصروفات غير مصنفة.
3. يختار Close Period.
4. بعد الإغلاق تصبح التعديلات المالية مقيدة؛ إعادة الفتح للـOwner فقط مع Audit Event.

## 11. المتطلبات الوظيفية التفصيلية

| ID | Priority | Requirement |
| --- | --- | --- |
| AUTH-01 | Must | يستطيع المستخدم التسجيل وتسجيل الدخول باستخدام البريد الإلكتروني وكلمة المرور، مع تأكيد البريد الإلكتروني الإلزامي واستعادة كلمة المرور بالبريد. |
| AUTH-02 | Must | جلسة المستخدم تعمل على Web وPWA بصورة آمنة ولا تحتوي أسرار Backend في العميل. |
| WS-01 | Must | يستطيع المستخدم إنشاء Workspace وضبط الاسم والعملة والمنطقة الزمنية ويوم بداية الفترة. |
| WS-02 | Must | يستطيع الـOwner دعوة Member، وإلغاء الدعوة قبل قبولها. |
| WS-03 | Must | لا يستطيع غير العضو الوصول لأي بيانات للـWorkspace حتى عبر API مباشرة. |
| PERIOD-01 | Must | يوجد Budget Period واحد فقط لكل Workspace وperiod_key. |
| PERIOD-02 | Must | إنشاء الفترة الجديدة idempotent ولا يكرر الـSnapshots عند تكرار الطلب. |
| PERIOD-03 | Must | الفترة تمر بحالات Draft/Open/Closed. |
| INC-01 | Must | الـOwner يستطيع إضافة عدة Income Items للشهر. |
| INC-02 | Must | كل Income Item يمكن أن يملك Visibility Policy مستقلة. |
| SEC-01 | Must | الـOwner يستطيع إنشاء Budget Section مع Planned Budget شهري. |
| SEC-02 | Must | الـMember يرى فقط الأقسام التي تسمح سياستها بذلك. |
| REC-01 | Must | يمكن إنشاء Recurring Template شهري بمبلغ افتراضي وموعد استحقاق وسياسة رؤية. |
| REC-02 | Must | تُنسخ القوالب إلى Monthly Items، وتعديل القالب لا يغير الأشهر السابقة. |
| REC-03 | Must | Monthly Item يقبل Pending/Paid/Skipped مع Actual Amount اختياري. |
| TX-01 | Must | يمكن إضافة Transaction بمبلغ موجب، تاريخ، قسم، وصف اختياري، وcreated_by. |
| TX-02 | Must | يمكن ربط Transaction بـMonthly Item لمنع العد المزدوج. |
| TX-03 | Must | الـMember يمكنه تعديل/حذف مصروفه داخل شهر مفتوح وفق السياسة. |
| VIS-01 | Must | الرؤية تُطبق في قاعدة البيانات وليس UI فقط. |
| VIS-02 | Must | الـOwner يستطيع جعل Resource Owner Only أو Shared أو Custom. |
| VIS-03 | Must | لا تعرض الواجهة مشتقات تسمح باستنتاج أرقام مخفية. |
| DASH-01 | Must | Dashboard الـOwner يعرض Income، Fixed، Allocated، Spent، Remaining، وReserve وفق بياناته الكاملة. |
| DASH-02 | Must | Dashboard الـMember يعرض View Model مبنيًا فقط على البيانات المصرح بها. |
| HIST-01 | Must | يمكن تصفح الشهور السابقة مع احترام الصلاحيات الحالية أو سياسة أرشفة محددة. |
| AUD-01 | Must | تسجل أحداث تغيير الصلاحيات، الإغلاق/إعادة الفتح، والحذف المالي الحساس. |
| PWA-01 | Must | يوفر التطبيق manifest صالحًا وأيقونات وتجربة display=standalone وقابلية إضافة للشاشة الرئيسية على المنصات المدعومة. |
| PWA-02 | Should | Cache للـapp shell والموارد الثابتة؛ لا يوجد Offline financial mutation في v1. |
| RT-01 | Should | تحديثات Realtime للأقسام المشتركة عند إضافة أحد الطرفين مصروفًا. |
| EXPORT-01 | Should | الـOwner يستطيع تصدير CSV لشهر واحد أو نطاق زمني لاحقًا في v1.1 إن لم يدخل الـMVP. |
| I18N-01 | Must | واجهة عربية RTL من اليوم الأول مع بنية تسمح بالإنجليزية لاحقًا. |
| CUR-01 | Must | عملة واحدة لكل Workspace، وتنسيق المبالغ يتم حسب العملة من غير float arithmetic. |

## 12. قواعد العمل والحسابات

| Rule ID | القاعدة |
| --- | --- |
| BR-01 | Total Income = مجموع Income Items التي يملك المستخدم الحالي حق رؤيتها في View Model الخاص به؛ Owner يرى الكل. |
| BR-02 | Fixed Planned = مجموع Planned Amount لبنود الالتزامات داخل الشهر، مع مراعاة صلاحية العرض. |
| BR-03 | Section Spent = مجموع Transactions النشطة التابعة للقسم داخل الفترة. |
| BR-04 | Section Remaining = Section Budget - Section Spent. |
| BR-05 | Reserve للـOwner = Total Income - Planned Fixed - Flexible Allocations - Savings Allocations. |
| BR-06 | Mark Paid لا يزيد Spent مرتين: إما ينشئ Transaction ويربطها أو يربط Transaction موجودة. |
| BR-07 | تعديل Recurring Template يؤثر على الفترات المستقبلية فقط، إلا إذا اختار الـOwner تطبيقه يدويًا على الشهر المفتوح. |
| BR-08 | الحذف التاريخي يُفضّل Soft Delete / Reversal للأحداث المالية بعد استخدامها، حفاظًا على الـauditability. |
| BR-09 | أي رقم مالي يُخزن Decimal/Numeric أو Minor Units؛ ممنوع استخدام IEEE float للحسابات المالية. |
| BR-10 | الفترات تعتمد Workspace Timezone وليس timezone جهاز المستخدم لتحديد حدود الشهر. |

## 13. هيكل الشاشات وتجربة الاستخدام

### 13.1 Navigation على الموبايل

| Tab | المحتوى |
| --- | --- |
| Home | ملخص الشهر + الأقسام + التنبيهات المهمة. |
| Plan | التخطيط والبنود الدورية؛ يظهر للـMember بقدر صلاحياته. |
| Activity | Timeline للمصروفات والتعديلات المسموحة. |
| More | الأعضاء، الرؤية، الإعدادات، التاريخ، التصدير. |

يُفضل زر Add Expense كـFAB أو زر ثابت في أسفل الشاشة؛ الهدف أن تسجيل مصروف متكرر لا يتطلب رحلة طويلة.

### 13.2 Home للـOwner

- Period selector في الأعلى.
- Cards: Total Income، Fixed Commitments، Flexible Budget، Spent، Reserve.
- قائمة الأقسام مع Budget / Spent / Remaining وProgress Bar.
- Upcoming/Pending recurring items.
- CTA لإضافة مصروف أو تعديل الخطة.

### 13.3 Home للـMember

- لا توجد Cards تشير إلى دخل أو بنود مخفية ما لم تُشارك صراحة.
- يظهر فقط ملخص الأقسام المسموحة: مثل مصروف البيت 12,000 - صُرف 7,500 - متبقي 4,500.
- Pending items المسموحة فقط.
- Activity الخاصة بالموارد المشتركة فقط.

### 13.4 شاشة Visibility

لتجنب التعقيد، الواجهة تعرض Presets واضحة: Private to me / Shared with partner / Custom. ويجب توفير Preview اختياري بعنوان "What your partner can see" قبل الحفظ، لأنه يقلل أخطاء الخصوصية.

## 14. النموذج النهائي للبيانات

الـschema الداخلي يستخدم `household` كاسم تقني للـWorkspace المشترك، مع فصل واضح بين configuration الدائم وبين snapshots الشهرية.

### 14.1 Identity / Membership

| Table | Purpose |
| --- | --- |
| `profiles` | Profile عام للتطبيق مرتبط بـ`auth.users`. |
| `households` | الـWorkspace المالي المشترك وإعداداته. |
| `household_members` | Owner/Member وحالة العضوية. |
| `household_invitations` | دعوات العضوية المشفرة/المحددة الصلاحية. |
| `platform_admins` | صلاحيات إدارة منصة Dabber، منفصلة تمامًا عن Household roles. |
| `resource_permissions` | Grants مخصصة للأعضاء عند استخدام `visibility_scope=custom`. |

### 14.2 Monthly Finance

| Table | Purpose |
| --- | --- |
| `budget_periods` | دورة مالية واحدة لكل Household و`period_key`. |
| `income_sources` | قوالب/مصادر دخل متكررة وإعداد رؤيتها. |
| `period_income_items` | Snapshot شهري للدخل + دخل one-off. |
| `budget_sections` | أقسام ثابتة/مرنة؛ وهي Privacy Boundary الأساسية للمصروفات. |
| `period_section_budgets` | Snapshot شهري لاسم القسم ونوعه ومبلغ الخطة. |
| `recurring_templates` | قوالب البنود الدورية. |
| `monthly_items` | Snapshot شهري للبند الدوري وحالته Pending/Paid/Skipped. |
| `transactions` | المصروفات الفعلية. |
| `audit_events` | Audit للأحداث الحساسة داخل Household. |
| `admin_audit_logs` | Audit لأي إجراء إداري مميز. |

### 14.3 قرار الخصوصية للمصروفات

في الـMVP، كل Transaction ترث حدود الرؤية من Budget Section. لا ندعم Transaction مخفية داخل Section تعرض `Spent/Remaining` للشريك، لأن المبلغ قد يُستنتج من الإجماليات. البنود الخاصة توضع داخل Section خاص.

### 14.4 أهم القيود

- `budget_periods(household_id, period_key)` UNIQUE.
- `household_members(household_id, user_id)` UNIQUE.
- `period_section_budgets(period_id, section_id)` UNIQUE.
- Snapshot واحد لكل recurring template في الفترة.
- Posted transaction واحدة لكل monthly item في الـMVP لمنع double-counting؛ partial payments توسع لاحق.
- Validation triggers تمنع ربط Section من Household بفترة Household آخر أو Transaction بMonthly Item غير متسق.

## 15. المعمارية النهائية المتفق عليها

```text
GitHub Monorepo
│
├── apps/web      → Next.js Household PWA → Vercel Project A
│                         │
│                  Publishable Key + JWT
│                         │
├── apps/admin    → Next.js Super Admin → Vercel Project B
│                         │
│                 Server-only Secret Key
│                         │
└─────────────────────────▼
                     Supabase
              Auth + PostgreSQL + RLS
```

### 15.1 Stack Locked

| Layer | Decision |
| --- | --- |
| Household UI | Next.js App Router + TypeScript |
| Admin UI | Separate Next.js App Router + TypeScript |
| UI System | Tailwind CSS + shadcn/ui أو مكونات مماثلة |
| Database | Supabase PostgreSQL |
| Auth | Supabase Auth |
| Household Authorization | PostgreSQL RLS + permission helpers |
| Privileged Admin Access | Supabase Secret Key server-side only |
| Hosting | Vercel - مشروعان منفصلان من نفس الـmonorepo |
| Database Lifecycle | Supabase CLI + Git migrations |
| PWA | Web App Manifest + mobile-first standalone UX |

### 15.2 أنواع Supabase Clients

```text
browser client → publishable key + user session + RLS
server client  → publishable key + request session + RLS
admin client   → secret key + server only + no user access token + BYPASSRLS
```

لا يتم استخدام client واحد عام لكل السياقات، حتى لا تختلط جلسة المستخدم مع الـSecret Key.

## 16. Super Admin Dashboard

### 16.1 الفصل عن تطبيق المستخدم

الـSuper Admin لا يرى "buttons زيادة" داخل `apps/web`. يوجد Application مستقل، Deployment مستقل، Domain مستقل، وEnvironment Variables مستقلة.

### 16.2 التحقق من الـSuper Admin

1. Login عادي عبر Supabase Auth.
2. التحقق server-side من صف المستخدم في `platform_admins` وأن `is_active=true` و`role=super_admin`.
3. بعد ذلك فقط يُنشأ/يُستخدم privileged Supabase client بالـSecret Key.
4. الـSecret Key لا يصل للمتصفح مطلقًا.

### 16.3 Scope الوصول الإداري

الـSuper Admin يستطيع - من الخادم - الوصول إلى:

- كل Auth users عبر Supabase Auth Admin API.
- كل Profiles/Households/Memberships.
- كل Income/Budgets/Sections/Recurring Items/Transactions.
- Audit logs.
- إجراءات دعم أو تعطيل حسابات عند الحاجة.

كل Mutation إداري حساس يسجل في `admin_audit_logs` مع actor/action/target/reason/timestamp.

## 17. تصميم الـApplication Actions / RPCs

العمليات البسيطة single-row يمكن أن تستخدم authenticated Supabase client مع RLS. العمليات التي تحتاج عدة writes مترابطة يجب أن تكون transaction واحدة في PostgreSQL عبر RPC.

| Action/RPC | Purpose |
| --- | --- |
| `ensure_budget_period` | إنشاء الشهر ونسخ Sources/Sections/Recurring Templates مرة واحدة فقط. |
| `mark_monthly_item_paid` | إنشاء Transaction + تعليم Monthly Item Paid atomically. |
| `void_transaction` | إلغاء الحركة وتحديث البند المرتبط مع Audit. |
| `set_monthly_item_skipped` | Skip/Unskip للبند الدوري من خلال منطق ذري ومصرح به. |
| `set_budget_period_status` | Open/Close/Reopen للشهر مع validation وAudit. |
| `accept_household_invitation` | قبول الدعوة وربط المستخدم بالHousehold atomically. |
| `remove_household_member` | إزالة عضو بواسطة Owner ومنع إزالة المالك. |

أي RPC بـ`security definer` يجب أن يعيد التحقق صراحة من `auth.uid()` والصلاحيات، ويستخدم `search_path` آمنًا.

## 18. Migration & Schema Governance

### 18.1 القرار

**أي تعديل في Supabase Database يجب أن يكون موثقًا في Git كـmigration، ولا يتم تعديل Production Schema يدويًا.**

### 18.2 الهيكل

```text
supabase/
├── schemas/       # Declarative current state - المصدر المقروء للـschema
├── migrations/    # Timestamped immutable deployment history
├── tests/         # pgTAP / RLS tests
├── seed.sql
└── config.toml    # ينشأ عبر supabase init ويُcommit
```

### 18.3 الـWorkflow اليومي

```bash
# 1. تعديل supabase/schemas/*.sql

# 2. توليد migration
supabase db diff -f meaningful_change_name

# 3. مراجعة SQL الناتج يدويًا

# 4. إعادة بناء local DB من الصفر
supabase db reset

# 5. اختبارات database/RLS
supabase test db

# 6. TypeScript types
supabase gen types --lang typescript --local > packages/database/src/database.types.ts
```

### 18.4 Production Deploy

```bash
supabase migration list
supabase db push --dry-run
supabase db push
```

نفضل تشغيل `db push` من CI/CD بعد merge وليس من أجهزة المطورين. GitHub `production` Environment مع manual approval مطلوب قبل الـpublic beta.

### 18.5 قاعدة مهمة

`supabase db diff` مفيد لكنه ليس مصدر ثقة أعمى؛ يتم مراجعة generated migration لأن DML وبعض أنواع تغييرات الـdatabase لا تظهر دائمًا بصورة كاملة في diff.

## 19. RLS & Security Requirements

- RLS مفعّل على كل جدول exposed في `public`.
- Grants تُضبط صراحة ولا نعتمد على RLS وحده مع grants واسعة.
- كل Policy لها Allow/Deny tests.
- Secret Key موجود فقط في `apps/admin` server environment.
- User app لا يملك أي وسيلة bypass لـRLS.
- Admin client لا يحمل end-user access token عند تنفيذ privileged query.
- `admin_audit_logs` لا يحصل عليه `anon` أو `authenticated` مباشرة.
- لا تُستخدم `user_metadata` القابلة لتعديل المستخدم كمرجع Authorization للـSuper Admin.

## 20. Data Integrity & Financial Correctness

- Money stored as `numeric(14,2)` وليس float.
- Month generation idempotent.
- Template edits لا تعيد كتابة snapshots القديمة.
- Paid recurring item لا يُحسب مرتين؛ actual spend مصدره posted Transaction.
- حذف التاريخ المالي الصامت غير مسموح؛ نستخدم void/archive مع audit.
- closed period يمنع ordinary financial edits.
- علاقات period/section/monthly-item/transaction تُفحص DB-side.

## 21. حالات الحواف الأساسية

| Scenario | Decision |
| --- | --- |
| مصروف يتجاوز Budget | نسمح + Warning. |
| قيمة قسط تغيرت لشهر واحد | تعديل Monthly Item فقط. |
| القيمة تغيرت دائمًا | تعديل Template، والشهور السابقة ثابتة. |
| Owner يريد إخفاء قسط | يوضع في Private Section؛ لا نخفي transaction داخل Shared Section. |
| Member يغادر | access يُلغى فورًا والتاريخ يحتفظ بـcreated_by. |
| تكرار ensure period | Unique constraints تمنع duplication. |
| تكرار Mark Paid | RPC + unique posted transaction تمنع double posting. |
| تغيير visibility | الحالية تحكم الوصول التاريخي افتراضيًا. |
| Admin يحتاج كل users | Auth Admin API من server Secret-Key client. |

## 22. الشاشات

### Household PWA

```text
Home
Plan
  Income
  Fixed Commitments
  Flexible Sections
Recurring Checklist
Add Expense
Activity
History
Settings
  Household
  Members & Invitations
  Visibility
```

### Super Admin

```text
Dashboard
Users
Households
Budgets
Transactions
Recurring Items
Audit Logs
System
```

## 23. PWA والموبايل

- Arabic RTL وMobile-first من البداية.
- Manifest وicons وstandalone display.
- Online-first writes في الـMVP.
- caching محافظ؛ لا نخزن private financial API payloads بلا داعٍ.
- Quick Add Expense هدف UX أساسي.

## 24. Non-functional Requirements

| Area | Requirement |
| --- | --- |
| Security | RLS + least privilege + server-only admin secrets. |
| Migration reproducibility | clean `db reset` من migrations شرط merge. |
| Testing | pgTAP database/RLS tests + application tests. |
| Performance | indexes على membership, periods, sections, transactions وRLS filters. |
| Privacy | لا نرسل financial payloads للanalytics. |
| Auditability | Owner-sensitive وAdmin-sensitive mutations قابلة للتتبع. |
| Localization | Arabic RTL أولًا مع بنية i18n. |
| Backups | backup/restore runbook قبل الاعتماد التجاري. |

## 25. CI/CD

### Pull Request Gate

- Start local Supabase.
- Apply migration chain from zero.
- Run database tests.
- Build/lint/typecheck apps عند بدء الكود.

### Production DB Deployment

- `supabase db push --dry-run`.
- protected GitHub Environment approval.
- `supabase db push`.
- لا يوجد `db reset --linked` على production.

## 26. Repo Structure

```text
dabber/
├── apps/
│   ├── web/
│   └── admin/
├── packages/
│   ├── ui/
│   ├── database/
│   ├── validation/
│   └── config/
├── supabase/
│   ├── schemas/
│   ├── migrations/
│   ├── tests/
│   └── seed.sql
├── docs/
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── DATABASE.md
│   ├── PERMISSIONS.md
│   ├── MIGRATIONS.md
│   ├── SUPER_ADMIN.md
│   ├── ERD.md
│   └── adr/
└── .github/workflows/
```

## 27. Acceptance Criteria الإضافية لـv2

بالإضافة إلى معايير الـMVP الوظيفية السابقة:

1. المستخدم العادي لا يستطيع عبر API قراءة Household غير عضو به.
2. Partner لا يقرأ Income `owner_only` حتى لو عرف الـUUID.
3. Section private لا تظهر rows أو counts أو transactions المرتبطة بها.
4. Admin app منفصل عن user app في Vercel.
5. Secret Key غير موجود في client bundles أو `NEXT_PUBLIC_*`.
6. Super Admin يستطيع server-side list لكل Supabase Auth users.
7. Super Admin يستطيع inspect أي Household بغض النظر عن household RLS.
8. كل privileged admin mutation ينتج `admin_audit_logs` entry.
9. clean `supabase db reset` يعيد بناء schema من migration history.
10. `supabase test db` ينجح قبل merge لتغييرات database.
11. database types تُولد من schema وتُcommit مع تغييرات العقد المستخدم في TypeScript.

## 28. خطة التنفيذ

| Milestone | Deliverable |
| --- | --- |
| 0 — Repository/Foundation | Monorepo، Next apps skeleton، Supabase CLI، baseline migration، CI، RTL tokens. |
| 1 — Auth & Household | Auth، profiles، household create، membership/invite، RLS tests. |
| 2 — Monthly Planning | periods، income، sections، recurring templates، ensure period. |
| 3 — Spending | transactions، quick add، totals، paid checklist RPC. |
| 4 — Privacy | visibility presets، custom grants عند الحاجة، partner-safe dashboards، inference tests. |
| 5 — History & Audit | close/reopen، void flow، household audit. |
| 6 — Super Admin | separate app، users/households inspectors، Secret-Key server layer، admin audit. |
| 7 — PWA & Production | manifest، mobile QA، staging، protected migrations، backup/restore. |
| 8 — Beta | 5–20 households، product metrics، friction fixes. |

## 29. Future Roadmap

- Savings / تدبير: Goal + Contribution domain.
- Purchase goals with target amount/date.
- Sinking funds.
- Reminders and notifications.
- CSV/export.
- Richer multi-member permissions.
- Partial payments.
- Receipt attachments/OCR.
- Bank integrations only after core behavior is proven.

## 30. قرارات معمارية مقفولة

| Decision | Locked choice |
| --- | --- |
| App stack | Next.js + TypeScript |
| Hosting | Vercel |
| Backend/data | Supabase |
| Database | PostgreSQL |
| User authorization | RLS + authenticated server checks |
| Super Admin | Separate Next.js app/project |
| Admin elevated access | Server-only Supabase Secret Key after admin verification |
| DB workflow | Declarative schemas + Git migrations + CLI |
| Spending privacy | Section-level in MVP |
| Recurring | Template → Monthly Snapshot |
| Month creation | Lazy idempotent RPC; scheduler optional |
| Offline | Online-first MVP |
| Money | Decimal numeric, single household currency MVP |

## 31. Migration Documentation Standard

أي migration يدوية أو تم تعديل generated SQL فيها بصورة جوهرية تحتوي Header يشرح:

```text
Migration ID
Purpose
Risk
Data migration/backfill
Rollback/forward-fix strategy
Operational notes / PR
```

ولا يتم تعديل migration سبق تطبيقها على production؛ أي تصحيح يكون migration جديدة forward-only.

## 32. مراجع التنفيذ الرسمية

1. Supabase. Local development workflow. Accessed 10 Sep 2026. https://supabase.com/docs/guides/local-development/cli-workflows
2. Supabase. Database migrations. Accessed 10 Sep 2026. https://supabase.com/docs/guides/local-development/database-migrations
3. Supabase. Declarative database schemas. Accessed 10 Sep 2026. https://supabase.com/docs/guides/local-development/declarative-database-schemas
4. Supabase. Row Level Security. Accessed 10 Sep 2026. https://supabase.com/docs/guides/database/postgres/row-level-security
5. Supabase. API keys. Accessed 10 Sep 2026. https://supabase.com/docs/guides/getting-started/api-keys
6. Supabase. Managing environments. Accessed 10 Sep 2026. https://supabase.com/docs/guides/deployment/managing-environments
7. Supabase. Testing your database. Accessed 10 Sep 2026. https://supabase.com/docs/guides/database/testing
8. Vercel Academy. Deploy Both Apps from a monorepo. Accessed 10 Sep 2026. https://vercel.com/academy/production-monorepos/deploy-both-apps

> **Final product definition:** Dabber is a Shared Monthly Budget Workspace with Selective Visibility, backed by database-enforced privacy and operated through a completely separate platform Super Admin surface.
