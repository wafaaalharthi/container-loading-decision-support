# Container Loading Decision Support – Group 8 (Senior Project 1)

Improving Container Space Utilization and Loading Efficiency Through Intelligent Decision Support.
University of Jeddah · Supervisor: Dr. Enas Jambi · Fall 2026

## Contents
| Folder | What it is |
|---|---|
| `flutter_app/lib` | Flutter application (Dart): screens, domain logic, SQLite data layer |
| `flutter_app/packages/container_loading` | Loading engine (pure Dart): 6 algorithms, independent validator, metrics, 67 unit tests, benchmark runner |
| `flutter_app/test` | Integration test (`planning_test.dart`) |
| `prototype` | Interactive design prototype (HTML/CSS/JavaScript) |
| `analysis` | Statistical analysis script (Python) and result tables |
| `sample_data` | SH-102 sample (xlsx/csv) and the collected dataset workbook |

## Run the app
Requires Flutter 3.47+ and an Android emulator or device.
```bash
flutter create --platforms=android .   # only if android/ is incomplete; keeps lib/ untouched
flutter pub get
flutter analyze
flutter run
```

## Tests
```bash
cd packages/container_loading && dart test      # 67 engine unit tests
cd ../.. && flutter test test/planning_test.dart  # SH-102: 70/121 instant, 91/121 optimized
```

## Comparison with real manual loading
Five published shipments (THAI-1, THAI-2, THAI-3, SALAM-1, KLONG-1) are stored in `packages/container_loading/data/manual_cases.json`.
```bash
cd packages/container_loading && dart run bin/manual_compare.dart
```

## Algorithms in the app
Instant plan = Block-Building · Optimized plan = Beam Search · Manual-style comparison = Wall-Building (George & Robinson, 1980).
