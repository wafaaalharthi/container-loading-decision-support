/// Runs the demo shipment SH-102 (121 boxes, 20GP) through the app algorithms
/// and the manual-style simulation, prints the figures, and saves the plans.
///
///   dart run bin/sh102.dart                 (5 s budget, as in the app)
///   dart run bin/sh102.dart --budget 2
import 'dart:convert';
import 'dart:io';

import 'package:container_loading/container_loading.dart';

const algorithmsToRun = ['block_building', 'beam_search', 'wall_building'];

Future<void> main(List<String> args) async {
  final i = args.indexOf('--budget');
  final double budgetS = i >= 0 && i + 1 < args.length ? double.parse(args[i + 1]) : 5.0;
  final c = parseCases(await File('data/sh102.json').readAsString()).single;
  final outDir = Directory('results/sh102');
  await outDir.create(recursive: true);

  stdout.writeln('Case ${c.id}: ${c.boxes.length} boxes, container ${c.container.id}, budget ${budgetS}s\n');
  stdout.writeln('${'algorithm'.padRight(16)}${'util %'.padLeft(8)}${'loaded'.padLeft(10)}'
      '${'time s'.padLeft(9)}${'blocking %'.padLeft(12)}  validator');

  final summary = <Map<String, Object?>>[];
  for (final name in algorithmsToRun) {
    final r = planLoad(c, algorithm: name, budget: Duration(milliseconds: (budgetS * 1000).round()));
    final m = r.metrics;
    final util = (m['utilization_pct'] as double).toStringAsFixed(1);
    final loaded = '${m['boxes_placed']}/${m['boxes_total']}';
    final time = (m['runtime_s'] as double).toStringAsFixed(3);
    final inv = m['priority_inversion_pct'] == null ? '-' : (m['priority_inversion_pct'] as double).toStringAsFixed(1);
    final valid = r.issues.isEmpty ? 'passed' : 'FAILED (${r.issues.first})';
    stdout.writeln('${name.padRight(16)}${util.padLeft(8)}${loaded.padLeft(10)}${time.padLeft(9)}${inv.padLeft(12)}  $valid');
    summary.add({'algorithm': name, ...m});
    final plan = planToJson(c, name, r.plan, m);
    await File('${outDir.path}/SH-102__$name.json').writeAsString(const JsonEncoder.withIndent('  ').convert(plan));
  }
  await File('${outDir.path}/summary.json').writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
  stdout.writeln('\nPlans saved in ${outDir.path}/');
}
