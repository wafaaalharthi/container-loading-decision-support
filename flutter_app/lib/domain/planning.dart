import 'dart:isolate';

import 'package:container_loading/container_loading.dart' as eng;

import 'shipment.dart';
import 'validation.dart';

/// One placed box in loading order. Lengths in mm, x = 0 is the back wall.
class PlanBox {
  final String id; // display id, e.g. SH102-B02-24
  final String group; // B02
  final int x, y, z, dx, dy, dz;
  const PlanBox(this.id, this.group, this.x, this.y, this.z, this.dx, this.dy, this.dz);

  /// Short label printed on the box, e.g. B02-24
  String get label {
    final i = id.indexOf('-');
    return i < 0 ? id : id.substring(i + 1);
  }
}

class PlanOutcome {
  final String mode; // instant | optimized
  final String algorithm;
  final List<PlanBox> placed;
  final Map<String, String> unplaced; // display id -> reason key
  final int total;
  final double utilization; // %
  final double weightKg;
  final double timeMs;
  final double? blockingPct; // % of priority pairs where an early-unload box sits deeper
  final bool valid;
  final int issues;

  const PlanOutcome({
    required this.mode,
    required this.algorithm,
    required this.placed,
    required this.unplaced,
    required this.total,
    required this.utilization,
    required this.weightKg,
    required this.timeMs,
    required this.blockingPct,
    required this.valid,
    required this.issues,
  });
}

const kAlgorithmFor = {'instant': 'block_building', 'optimized': 'beam_search', 'manual': 'wall_building'};

// Instant plans finish far below this; the optimized search usually stops on its own
const kBudgetFor = {
  'instant': Duration(seconds: 5),
  'optimized': Duration(seconds: 30),
  'manual': Duration(seconds: 5),
};

/// Builds the engine case. Box ids follow the engine data format (TYPE#n) so results
/// match the recorded benchmark runs; [idMap] converts them back to display ids.
(eng.LoadingCase, Map<String, String>, Map<String, String>) buildCase(Shipment s, List<BoxGroup> groups) {
  final prefix = s.code.replaceAll('-', '').replaceAll(' ', '');
  final c = s.container;
  final boxes = <eng.BoxItem>[];
  final idMap = <String, String>{};
  final groupOf = <String, String>{};
  for (final g in groups) {
    if (groupErrors(g).isNotEmpty) continue; // invalid data never reaches the engine
    final type = '$prefix-${g.code}';
    final display = g.boxIds(s.code);
    final rotations = g.orientation == 'upright'
        ? const <eng.Rotation>[
            [0, 1, 2],
            [1, 0, 2],
          ]
        : eng.allRotations;
    for (var i = 1; i <= g.quantity; i++) {
      final id = g.quantity == 1 ? type : '$type#$i';
      idMap[id] = display[i - 1];
      groupOf[id] = g.code;
      boxes.add(eng.BoxItem(
        id: id,
        type: type,
        size: [g.lengthMm, g.widthMm, g.heightMm],
        weightKg: g.weightKg,
        rotations: rotations,
        floorOnly: g.floorOnly,
        stackable: g.stackable && !g.fragile,
        similarAbove: g.stackable && g.stacking == 'other' ? false : null,
        differentAbove: g.stackable && g.stacking == 'same' ? false : null,
        fragile: g.fragile,
        priority: g.priority,
        contents: g.contents,
      ));
    }
  }
  final lc = eng.LoadingCase(
    id: s.code,
    source: 'APP',
    group: 'APP',
    container: eng.ContainerSpec(
      id: c.code,
      length: c.length,
      width: c.width,
      height: c.height,
      payloadKg: c.payloadKg,
      doorWidth: c.doorWidth,
      doorHeight: c.doorHeight,
    ),
    boxes: boxes,
    options: const eng.CaseOptions(support: true, stacking: true, pressure: false, fragileBlocksStacking: true),
  );
  return (lc, idMap, groupOf);
}

/// Runs the engine in a background isolate so the UI stays responsive.
Future<PlanOutcome> runPlan(Shipment s, List<BoxGroup> groups, String mode) async {
  final (lc, idMap, groupOf) = buildCase(s, groups);
  final algorithm = kAlgorithmFor[mode]!;
  final budget = kBudgetFor[mode]!;
  final r = await Isolate.run(() => eng.planLoad(lc, algorithm: algorithm, budget: budget));

  final placed = [
    for (final p in r.plan.placed)
      PlanBox(idMap[p.box.id]!, groupOf[p.box.id]!, p.x, p.y, p.z, p.dx, p.dy, p.dz),
  ];
  final placedIds = {for (final b in placed) b.id};

  // Every box that is not in the plan gets a reason
  final unplaced = <String, String>{};
  var total = 0;
  for (final g in groups) {
    final st = inputStatus(g, s.container);
    for (final id in g.boxIds(s.code)) {
      total++;
      if (placedIds.contains(id)) continue;
      unplaced[id] = st.accepted ? 'reason_engineNotLoaded' : st.reasonKey!;
    }
  }

  final m = r.metrics;
  return PlanOutcome(
    mode: mode,
    algorithm: algorithm,
    placed: placed,
    unplaced: unplaced,
    total: total,
    utilization: (m['utilization_pct'] as num).toDouble(),
    weightKg: (m['loaded_weight_kg'] as num).toDouble(),
    timeMs: (m['runtime_s'] as num).toDouble() * 1000,
    blockingPct: (m['priority_inversion_pct'] as num?)?.toDouble(),
    valid: m['valid'] as bool,
    issues: m['issues'] as int,
  );
}
