# تطبيق احتياجات المنزل — تعليمات العمل لـ Claude Code

اقرأ هذا الملف كاملاً قبل أي عمل. المرجع الوظيفي التفصيلي في `docs/SCOPE.md`،
والمهام مرتبة في `TASKS.md`، ومخطط قاعدة البيانات في `supabase/schema.sql`.

## 1. ما هذا المشروع

تطبيق جوال (Flutter) يحوّل احتياجات البيت من رسائل واتساب متفرقة إلى طلبات لها
مسؤول وحالة وسعر متوقع. بيت واحد فيه أدوار: **مدير** و**شريك** (الزوج/الزوجة)
يطلبان وينفذان ويريان الميزانية، و**منفذ** (سواق/عامل منزلي) ينفذ فقط ما يُكلَّف
به بواجهة مبسطة بلغته، بلا ميزانية ولا سجل أسعار.

المزايا الثلاث المميزة: طلب وتنفيذ بأدوار وحالات إغلاق، تسوية الكاش مع صور
الفواتير، وسعر استرشادي يتراكم من فواتير البيت.

هدف النسخة الأولى: بيت واحد يستغني عن الواتساب لطلبات الشراء بالكامل.

## 2. القرارات التقنية الثابتة (لا تُغيَّر بدون سؤال)

| البند | القرار |
| --- | --- |
| الإطار | Flutter (قناة stable)، Dart 3، حزمة واحدة لأندرويد وiOS والويب |
| الخلفية | Supabase: Auth + Postgres + Storage + Realtime. لا خادم آخر |
| اسم الحزمة | `home_needs`، معرّف أندرويد `sa.homeneeds.app` (يُغيَّر قبل النشر بالمتاجر) |
| الحد الأدنى | Android minSdk 24، iOS 13 |
| إدارة الحالة | `flutter_riverpod` |
| التنقل | `go_router` مع حراسة حسب الدور |
| التعريب | `flutter_localizations` + ملفات ARB في `lib/l10n/` (ar الافتراضية، en، ur) |
| الصور | `image_picker` + `flutter_image_compress` (ضغط قبل الرفع، أقصى بعد 1280px) |
| المفاتيح | `SUPABASE_URL` و`SUPABASE_ANON_KEY` عبر `--dart-define` وتُقرأ بـ `String.fromEnvironment`. لا مفاتيح في الكود ولا في git |
| الأرقام | أرقام غربية (0-9) في كل الواجهات، العملة "ريال" |

الدخول في النسخة التجريبية: أعضاء البيت بالبريد وكلمة المرور (Supabase email
auth)؛ المنفذ بتسجيل مجهول (`signInAnonymously`) ثم كود الدعوة. تسجيل الدخول
برقم الجوال يُؤجَّل لما بعد التجربة (يحتاج مزوّد SMS).

## 3. قاعدة البيانات: قواعد لا تُكسر

- `supabase/schema.sql` هو المصدر الوحيد للحقيقة. أي تعديل يُكتب كملف جديد
  `supabase/migrations/NNN_description.sql` ويُذكر في وصف الـ PR، ولا يُعدَّل
  `schema.sql` نفسه بعد أول تشغيل.
- تغيير حالة البند يتم **حصراً** عبر RPC:
  `assign_item`, `claim_item`, `close_item`, `cancel_item`, `reopen_item`,
  `reactivate_deferred`. التحديث المباشر لعمود `status` مرفوض بمشغّل في القاعدة.
- إنشاء البيت والانضمام عبر RPC: `create_household`, `create_invite_code`,
  `join_with_code`.
- الرصيد يُحسب بـ `executor_balance(household, executor)` ولا يُخزَّن.
- سجل الأسعار (`price_records`) والانتقالات (`item_transitions`) وحركة المصروف
  عند الشراء تُكتب بالمشغّلات تلقائياً؛ التطبيق لا يكتب فيها مباشرة.
- صور الفواتير في bucket `receipts` وصور البنود في `item-images`، والمسار دائماً
  `<household_id>/<uuid>.jpg` (سياسات التخزين تعتمد على المجلد الأول).
- الكيانات: households, members, invite_codes, catalog_items, items,
  item_transitions, cash_movements, receipts, price_records.

## 4. الأدوار والحالات (ملخص)

| الصلاحية | مدير | شريك | منفذ |
| --- | --- | --- | --- |
| إضافة بند وتعديله | نعم | نعم | لا |
| تكليف بند | نعم | نعم | لا |
| إغلاق بند (تم / مؤجل / مرفوض) | نعم | نعم | للمكلَّف به فقط |
| رؤية السعر المتوقع والميزانية | نعم | نعم | لا |
| تسليم كاش | نعم | نعم | لا |
| تسجيل مصروف وصورة فاتورة | نعم | نعم | نعم |
| دعوة الأعضاء وتغيير الأدوار | نعم | لا | لا |

حالات البند: `new → assigned → bought | deferred | rejected`، و`cancelled` قبل
الشراء. المؤجل يعود `assigned` عند حلول موعده. المرفوض يعود `new/assigned`
بـ `reopen_item` بعد تعديله. عند وجود منفذ واحد في البيت يُكلَّف كل بند جديد له
تلقائياً (المشغّل يتولى ذلك).

## 5. بنية الكود

```
lib/
  main.dart
  app.dart                 # MaterialApp.router + l10n + theme
  core/
    supabase/              # client init, auth helpers
    router/                # go_router + role guards
    theme/
    l10n/                  # generated
    widgets/               # مشتركة
  features/
    auth/                  # sign in/up, join with code
    household/             # create household, members, invite codes, settings
    items/                 # list, add/edit, details (واجهة البيت)
    executor/              # my tasks, close item flow, my spend (واجهة المنفذ)
    cash/                  # handover, movements, balance
    prices/                # expected price, monthly summary
  data/
    models/                # freezed أو يدوي بسيط، حقل لكل عمود
    repositories/          # كل استدعاءات Supabase هنا فقط
supabase/                  # schema, seed, migrations
docs/SCOPE.md              # النطاق الوظيفي الكامل
```

- الشاشات لا تستدعي Supabase مباشرة؛ عبر repositories فقط.
- كل نص في الواجهة من ملفات ARB. لا نصوص ثابتة في الكود.
- دعم RTL للعربية والأردية تلقائياً عبر `Directionality` من الـ locale.

## 6. قواعد واجهة المنفذ (مهمة)

- إجراء واحد لكل لمسة، لا قوائم منسدلة، أزرار كبيرة (ارتفاع 56+).
- الصورة/الأيقونة قبل الاسم؛ كل اسم صنف يظهر بلغة المنفذ وتحته العربية.
- بطاقة البند تحمل ثلاثة أزرار: تم / مؤجل / مرفوض.
- إغلاق "تم": لوحة أرقام للسعر + كاميرا للفاتورة، بلا حقول أخرى.
- "مؤجل": خيارات جاهزة (غداً / بعد يومين / أسبوع). "مرفوض": سبب من قائمة.
- لا يظهر للمنفذ: الميزانية، سجل الأسعار، الملخص الشهري، الأعضاء.

## 7. طريقة العمل (كل جلسة)

1. اقرأ `TASKS.md` ونفّذ **مهمة واحدة** فقط: المهمة الأولى غير المكتملة، أو
   المهمة التي يحددها المستخدم. لا تبدأ التالية.
2. قبل الكود: اقرأ معيار القبول للمهمة وقسمها في `docs/SCOPE.md`.
3. بعد الكود، في هذا الترتيب:
   - `flutter gen-l10n` (إن تغيرت ARB) ثم `flutter analyze` بصفر مشاكل.
   - `flutter test` (اكتب اختباراً واحداً على الأقل لكل repository جديد).
   - `flutter build apk --debug` إن كان Android SDK متوفراً.
4. حدّث `TASKS.md` (ضع `[x]`)، وأضف سطراً في `CHANGELOG.md` (أنشئه إن لم يوجد).
5. Commit برسالة قصيرة بالإنجليزية تبدأ برقم المهمة: `T3: items list and add item`.
6. افتح PR واحداً للمهمة، ووصفه: ما أُنجز، ما لم يُنجز، أي migration جديد.

عند الغموض: اسأل سؤالاً واحداً محدداً بدل التخمين. لا تضف مزايا خارج النسخة
الأولى (القائمة في `docs/SCOPE.md` قسم "المزايا حسب الأولوية") حتى لو بدت سهلة.
لا تغيّر `schema.sql`، ولا تبدّل الحزم المذكورة في القسم 2، ولا تضف حزم UI
ثقيلة بدون سؤال.

## 8. البيئة السحابية

إذا لم يكن `flutter` في المسار: نفّذ `bash claude-cloud-setup.sh` (يثبّت Flutter
في `~/flutter` وAndroid SDK في `~/android-sdk`) ثم أضف للمسار:
`export PATH="$HOME/flutter/bin:$PATH" ANDROID_HOME="$HOME/android-sdk"`.
إن فشل تحميل Android SDK بسبب الشبكة، أكمل العمل ببناء الويب
(`flutter build web`) و`flutter analyze`؛ ملف APK يُبنى تلقائياً في GitHub Actions.

## 9. أوامر مرجعية

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run -d chrome --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
flutter build apk --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
flutter build web --release --base-href /home-needs/ --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```
