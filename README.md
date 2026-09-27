# تطبيق احتياجات المنزل — حزمة البداية

كل ما يلزم لبدء التطوير من الآيباد عبر Claude Code السحابي، بدون لابتوب.
الكود يُكتب في السحابة، وملف APK يُبنى تلقائياً في GitHub، والنسخة الويب
تعمل على الآيفون من Safari.

## ما في الحزمة

| الملف | الغرض |
| --- | --- |
| `CLAUDE.md` | تعليمات Claude Code: القرارات التقنية، قواعد القاعدة، بنية الكود، طريقة العمل |
| `TASKS.md` | 11 مهمة مرتبة، كل واحدة بمعيار قبول و"أمر بدء" ينسخ كما هو |
| `docs/SCOPE.md` | النطاق الوظيفي الكامل (الأدوار، الحالات، الشاشات، الكاش، الأسعار) |
| `supabase/schema.sql` | قاعدة البيانات كاملة: 9 جداول، صلاحيات الأدوار (RLS)، دوال RPC، مشغّلات، تخزين — مختبَرة |
| `supabase/seed_catalog.sql` | كتالوج أولي: 44 صنفاً بالعربية والإنجليزية والأردية مع مرادفات |
| `claude-cloud-setup.sh` | سكربت تهيئة البيئة السحابية (Flutter + Android SDK) |
| `.github/workflows/build.yml` | بناء تلقائي: فحص → APK → نشر الويب |
| `.gitignore` | يمنع رفع المفاتيح وملفات البناء |

## الإعداد مرة واحدة (من الآيباد، 30–40 دقيقة)

### 1. المستودع على GitHub

1. أنشئ حساباً على github.com إن لم يكن لديك، ثم مستودعاً جديداً باسم `home-needs`.
   عام (Public) إن أردت نشر نسخة الويب مجاناً على GitHub Pages، وإلا خاص (Private).
2. من صفحة المستودع: **Add file → Upload files**، واسحب محتويات هذه الحزمة
   (المجلدات `supabase` و`docs` و`.github` والملفات). Safari على الآيباد يدعم السحب من تطبيق الملفات.
   إن لم يظهر مجلد `.github` في الملفات، فعّل "إظهار الملفات المخفية" أو ارفع
   `build.yml` لاحقاً في المسار `.github/workflows/build.yml` عبر **Add file → Create new file**.
3. **Commit changes**.

### 2. قاعدة البيانات على Supabase

1. أنشئ مشروعاً في supabase.com (الخطة المجانية تكفي)، اختر أقرب منطقة متاحة.
2. **SQL Editor → New query**: الصق محتوى `supabase/schema.sql` كاملاً → **Run**.
   ثم الصق `supabase/seed_catalog.sql` → **Run**.
3. **Authentication → Sign In / Providers**: تأكد أن **Email** مفعّل، وفعّل **Anonymous sign-ins**
   (للسواق: يدخل بكود الدعوة بلا حساب).
4. **Project Settings → API**: انسخ **Project URL** و**anon public** key.

### 3. الأسرار في GitHub

**Settings → Secrets and variables → Actions → New repository secret**:

- `SUPABASE_URL` = رابط المشروع
- `SUPABASE_ANON_KEY` = مفتاح anon

### 4. بيئة Claude Code السحابية

1. افتح تطبيق Claude على الآيباد → تبويب **Code** (أو claude.ai/code في Safari)، واربط حساب GitHub واختر المستودع.
2. أنشئ بيئة سحابية جديدة (Add cloud environment):
   - **Network access: Full** (تحميل Android SDK يحتاجه).
   - **Environment variables**: `SUPABASE_URL=...` و`SUPABASE_ANON_KEY=...` (مفتاح anon عام بطبيعته؛ الحماية في RLS).
   - **Setup script**: الصق محتوى `claude-cloud-setup.sh` كاملاً.
3. ابدأ جلسة على المستودع بوضع **Auto**، واكتب:

   `اقرأ CLAUDE.md و TASKS.md ونفّذ المهمة 1 فقط.`

## دورة العمل اليومية

1. جلسة Claude Code واحدة = مهمة واحدة من `TASKS.md` بأمر البدء المكتوب فيها.
2. عند الانتهاء يفتح Claude طلب دمج (PR). راجع الفرق من الآيباد، ثم **Merge**.
3. الدمج في `main` يشغّل البناء تلقائياً (**Actions**): يظهر ملف `app-release-apk` خلال دقائق.
4. **للسواق (أندرويد):** أسهل طريقة رابط مباشر: اطلب من Claude في الجلسة
   `أصدر وسم v0.1.0` — يُنشأ **Release** يحمل APK، أرسل رابطه للسواق بالواتساب، يفتحه ويثبّته
   (يحتاج السماح بتثبيت من مصادر غير معروفة مرة واحدة).
5. **للبيت (آيفون):** افتح رابط GitHub Pages (`https://<اسمك>.github.io/home-needs/`) في Safari
   → مشاركة → **إضافة إلى الشاشة الرئيسية**. يعمل كتطبيق. نسخة App Store تحتاج ماك وحساب مطوّر آبل لاحقاً.

## ملاحظات

- لا تعدّل `supabase/schema.sql` بعد تشغيله؛ أي تغيير يكتبه Claude كملف في `supabase/migrations/` وتنفّذه أنت في SQL Editor.
- مفتاح `service_role` في Supabase لا يُستخدم في التطبيق ولا يُرفع لأي مكان.
- إن ظهرت مشكلة في بناء Android داخل جلسة Claude، تجاهلها: البناء الرسمي في GitHub Actions.
- التجربة اليدوية بالواتساب (خطة التحقق في `docs/SCOPE.md`) تمشي بالتوازي ولا تنتظر التطبيق.
