// Wall-Building (manual-style simulation) and the SH-102 demo shipment.
import 'dart:io';

import 'package:container_loading/container_loading.dart';
import 'package:test/test.dart';

void main() {
  final sh102 = parseCases(File('data/sh102.json').readAsStringSync()).single;

  test('SH-102 case matches the demo shipment', () {
    expect(sh102.boxes.length, 121);
    final kg = sh102.boxes.fold<double>(0, (s, b) => s + b.weight);
    expect(kg, closeTo(5996, 1e-6));
    expect(sh102.totalBoxVolume / 1e9, closeTo(35.73, 0.01));
  });

  for (final name in ['block_building', 'beam_search', 'wall_building']) {
    test('$name gives a valid SH-102 plan without the pipe crate', () {
      final r = planLoad(sh102, algorithm: name, budget: const Duration(seconds: 1));
      expect(r.issues, isEmpty, reason: '${r.issues.take(3)}');
      expect(r.plan.placed, isNotEmpty);
      expect(r.plan.placed.any((p) => p.box.type == 'SH102-B05'), isFalse); // 6.4 m long, 20GP is 5.9 m
    }, timeout: const Timeout(Duration(minutes: 1)));
  }

  test('wall-building loads priority groups from the back wall to the door', () {
    final plan = wallBuilding(sh102, Deadline(const Duration(seconds: 5)), 1);
    expect(validatePlan(sh102, plan), isEmpty);
    expect(priorityInversions(plan.placed).inversions, 0);
    // Placement order is loading order: groups go from last-unloaded to first-unloaded.
    int? lastPriority;
    for (final p in plan.placed) {
      final pr = p.box.priorityKey;
      if (lastPriority != null) expect(pr, lessThanOrEqualTo(lastPriority));
      lastPriority = pr;
    }
  });

  test('wall-building is deterministic', () {
    final a = wallBuilding(sh102, Deadline(const Duration(seconds: 5)), 1);
    final b = wallBuilding(sh102, Deadline(const Duration(seconds: 5)), 9);
    expect(a.placed.length, b.placed.length);
    for (int i = 0; i < a.placed.length; i++) {
      expect(a.placed[i].box.id, b.placed[i].box.id);
      expect([a.placed[i].x, a.placed[i].y, a.placed[i].z], [b.placed[i].x, b.placed[i].y, b.placed[i].z]);
    }
  });

  test('wall-building keeps fragile and floor-only rules on SH-102', () {
    final plan = wallBuilding(sh102, Deadline(const Duration(seconds: 5)), 1);
    for (final p in plan.placed) {
      if (p.box.floorOnly) expect(p.z, 0);
    }
    for (final top in plan.placed) {
      for (final low in plan.placed) {
        final onTop = low.z2 == top.z && low.x < top.x2 && top.x < low.x2 && low.y < top.y2 && top.y < low.y2;
        if (onTop) expect(low.box.fragile == true, isFalse, reason: '${top.box.id} on fragile ${low.box.id}');
      }
    }
  });
}
