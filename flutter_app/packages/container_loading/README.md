# محرك تخطيط تحميل الحاويات — Container Loading Engine

مكتبة Dart نقية (بدون Flutter) تشتغل في تطبيق الأندرويد وفي اختبار المقارنة بنفس الكود.

## التشغيل (من Terminal داخل Android Studio)

افتحي المجلد `container_loading` في Android Studio (File ← Open)، وبعدها من تبويب **Terminal** تحت:

```bash
dart pub get                          # مرة وحدة فقط (يحتاج إنترنت)
dart test                             # الاختبارات، لازم تطلع كلها All tests passed
dart run bin/benchmark.dart --quick   # المقارنة السريعة
```

- `dart test` ياخذ تقريبًا 2–4 دقائق.
- المقارنة السريعة: 206 حالات × 5 خوارزميات، ثانيتين لكل تشغيل. في أول سطر يطبع لك تقدير أقصى للمدة. الجهاز يقدر يشتغل عادي، بس لا تقفلين اللابتوب.
- لما يخلص، يطلع مجلد **`results`**، ارسليه كامل (اضغطيه zip):
  - `runs.csv` — سطر لكل تشغيل
  - `summary_by_group.csv` — المتوسطات لكل مجموعة ولكل خوارزمية
  - `plans/` — خطط التحميل للحالات الحقيقية والسيناريوهات (JSON)

### خيارات إضافية

```bash
dart run bin/benchmark.dart --full                      # كل الحالات (1564)، 5 ثواني، 5 بذور — عدة ساعات
dart run bin/benchmark.dart --quick --groups SCN,REAL   # بس السيناريوهات والحالات الحقيقية
dart run bin/benchmark.dart --quick --workers 2         # لو الجهاز ثقل
dart run bin/benchmark.dart --quick --algorithms beam_search,multi_start
```


## شحنة الديمو SH-102

```bash
dart run bin/sh102.dart
```

يشغّل Block-Building وBeam Search وWall-Building على شحنة SH-102 (121 صندوق، حاوية 20GP) بميزانية 5 ثواني، ويطبع الاستغلال وعدد الصناديق والزمن ونسبة صناديق تعيق التفريغ ونتيجة المدقق. الخطط تنحفظ في `results/sh102/`.

## الخوارزميات

| الاسم في الكود | الخوارزمية | ثابتة؟ |
|---|---|---|
| `single_start` | Single-Start Extreme Points | نعم (تشتغل مرة وحدة) |
| `multi_start` | Multi-Start Extreme Points | لا (3 بذور في السريع) |
| `brkga` | Biased Random-Key Genetic Algorithm | لا |
| `block_building` | Block-Building | نعم |
| `beam_search` | Beam Search فوق الكتل | نعم |
| `wall_building` | Wall-Building: محاكاة الأسلوب اليدوي (George & Robinson, 1980) | نعم |

**كل الخوارزميات تاخذ نفس الميزانية الزمنية.** الخوارزميات التكرارية (Multi-Start وBRKGA وBeam Search) تستمر لين يخلص الوقت. أما الثابتة فتخلص بدري لأنها تبني خطة وحدة.

## القيود المطبقة

| النوع | القيد | ملاحظة |
|---|---|---|
| الحاوية | الاحتواء وعدم التداخل | |
| الحاوية | الحمولة القصوى | |
| الحاوية | مقاس فتحة الباب | الصندوق يدخل مستقيم، والمقطع (العرض × الارتفاع) لازم يكون أصغر من الباب |
| الصندوق | الاتجاهات المسموحة | |
| الصندوق | على الأرض فقط | |
| الصندوق | قابلية التكديس فوقه، ونفس النوع / نوع مختلف | |
| الصندوق | الهشاشة | ما ينحط فوق الهش شي (يتعطل للحالة MAX-D لأن مصدرها يفصل الهشاشة عن منع التكديس) |
| الخطة | الدعم الكامل | قاعدة الصندوق لازم تكون مدعومة 100% من الأرض أو من أسطح الصناديق تحته |
| الخطة | التحمّل (kg/cm²) | للحالات WT وMD والسيناريو SC-11، والحمل ينتقل للصناديق اللي تحت |
| الخطة | أولوية التفريغ | **معيار ثاني** بعد الاستغلال. الأولوية 1 تتفرّغ أول، فلازم تكون أقرب للباب |

**نظام الإحداثيات:** x على طول الحاوية، و x = 0 هو الجدار الخلفي، والباب عند x = الطول. ترتيب الصناديق في الخطة هو نفسه ترتيب التحميل الفعلي (من الخلف للباب).

**كل خطة يعيد فحصها مدقق مستقل** (`validatePlan`) بعد ما تخلص الخوارزمية. لو أي خطة خالفت قيد، تنحسب **INVALID** وتستبعد من الترتيب.

## الاستخدام داخل Flutter

في `pubspec.yaml` حق التطبيق:

```yaml
dependencies:
  container_loading:
    path: ../container_loading
```

```dart
import 'package:container_loading/container_loading.dart';

final result = planLoad(myCase, algorithm: 'beam_search', budget: const Duration(seconds: 5));
print(result.metrics['utilization_pct']);
for (final p in result.plan.placed) { /* p.x, p.y, p.z, p.dx, p.dy, p.dz للرسم الثلاثي الأبعاد */ }
```

الحساب ثقيل، فشغّليه في الخلفية بـ `Isolate.run(() => planLoad(...))` عشان الواجهة ما تعلّق.

## البيانات

الملف `tool/prepare_data.py` يحوّل `Sea_Container_Loading_Data.xlsx` لملفات JSON الموجودة في `data/`:

- `cases_quick.json`: من كل مجموعة BR1–7 وWT1–7 أول 10 حالات، ومن كل مجموعة MD أول 3 حالات بوجهتين و3 بخمس وجهات، وكل الحالات الحقيقية اللي فيها تفاصيل الصناديق، و11 سيناريو للقيود.
- `cases_full.json`: كل الحالات (1564).
- الحالات الحقيقية اللي ما فيها أبعاد داخلية للحاوية تستخدم مواصفات Hapag-Lloyd (20 قدم، 40 قدم، 40HC)، ومكتوب هالافتراض في `notes` لكل حالة.
