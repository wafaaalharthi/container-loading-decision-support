/// Compares the app algorithms with published manual loading results.
/// Each case lists its containers in order (loaded volume is reported in m3); the boxes left over after one
/// container are planned again in the next one, until every box is loaded.
///
///   dart run bin/manual_compare.dart              (30 s budget per container, as in the app)
///   dart run bin/manual_compare.dart --budget 10
import 'dart:convert';
import 'dart:io';

import 'package:container_loading/container_loading.dart';

const algorithmsToRun = ['block_building', 'beam_search', 'wall_building'];

Future<void> main(List<String> args) async {
  final i = args.indexOf('--budget');
  final double budgetS = i >= 0 && i + 1 < args.length ? double.parse(args[i + 1]) : 30.0;
  final root = jsonDecode(await File('data/manual_cases.json').readAsString()) as Map<String, dynamic>;
  final out = <Map<String, Object?>>[];

  for (final raw in root['cases'] as List<dynamic>) {
    final j = raw as Map<String, dynamic>;
    final seq = j['sequence'] as List<dynamic>;
    final manual = j['manual'] as Map<String, dynamic>;
    stdout.writeln('\n=== ${j['id']}  (manual: ${manual['containers']} with ${manual['boxes']} boxes)');
    if (manual['note'] != null) stdout.writeln('    ${manual['note']}');

    for (final alg in algorithmsToRun) {
      // The first container defines the full case; later containers take the leftovers.
      var current = caseFromJson({...j, 'container': seq.first});
      final total = current.boxes.length;
      final perContainer = <Map<String, Object?>>[];
      for (int k = 0; k < seq.length && current.boxes.isNotEmpty; k++) {
        if (k > 0) {
          final cj = caseFromJson({...j, 'container': seq[k], 'boxes': <dynamic>[]}).container;
          current = LoadingCase(id: current.id, source: current.source, group: current.group,
              container: cj, boxes: current.boxes, options: current.options);
        }
        final r = planLoad(current, algorithm: alg, budget: Duration(milliseconds: (budgetS * 1000).round()));
        final placed = {for (final p in r.plan.placed) p.box.id};
        final loadedM3 = r.plan.placed.fold<int>(0, (a, p) => a + p.volume) / 1e9;
        perContainer.add({
          'container': current.container.id,
          'boxes': r.plan.placed.length,
          'loaded_m3': double.parse(loadedM3.toStringAsFixed(2)),
          'utilization_pct': r.metrics['utilization_pct'],
          'valid': r.issues.isEmpty,
        });
        current = LoadingCase(id: current.id, source: current.source, group: current.group,
            container: current.container, boxes: [for (final b in current.boxes) if (!placed.contains(b.id)) b],
            options: current.options);
      }
      final left = current.boxes.length;
      final line = perContainer
          .map((c) => '${c['container']}: ${c['boxes']} (${(c['utilization_pct'] as double).toStringAsFixed(1)}%, ${c['loaded_m3']} m3${c['valid'] == true ? '' : ', INVALID'})')
          .join(' + ');
      stdout.writeln('${alg.padRight(16)} containers ${perContainer.length}  $line  left $left of $total');
      out.add({'case': j['id'], 'algorithm': alg, 'manual': manual, 'containers': perContainer, 'left': left, 'total': total});
    }
  }
  await Directory('results').create(recursive: true);
  await File('results/manual_compare.json').writeAsString(const JsonEncoder.withIndent('  ').convert(out));
  stdout.writeln('\nSaved results/manual_compare.json');
}
