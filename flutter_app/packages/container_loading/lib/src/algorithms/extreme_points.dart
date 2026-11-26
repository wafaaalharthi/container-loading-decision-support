/// Box-by-box construction on extreme points, and the two algorithms built on it:
/// Single-Start and Multi-Start.
library;

import 'dart:math';

import '../metrics.dart';
import '../models.dart';
import '../validator.dart';

/// Default loading order: boxes unloaded last (highest priority number) first,
/// floor-only boxes early, then larger volume first.
int compareBase(BoxItem a, BoxItem b) {
  if (a.priorityKey != b.priorityKey) return b.priorityKey.compareTo(a.priorityKey);
  if (a.floorOnly != b.floorOnly) return a.floorOnly ? -1 : 1;
  if (a.volume != b.volume) return b.volume.compareTo(a.volume);
  return a.id.compareTo(b.id);
}

List<BoxItem> baseOrder(List<BoxItem> boxes) => List<BoxItem>.of(boxes)..sort(compareBase);

/// Builds one plan by placing the boxes in [order], each at the deepest,
/// lowest feasible extreme point (sorted by x, then z, then y).
///
/// Extreme points are the corners created by each placed box, projected back
/// towards the walls (Crainic, Perboli & Tadei, 2008).
Plan constructExtremePoints(LoadingCase c, List<BoxItem> order, Deadline deadline) {
  final v = Validator(c);
  final points = <(int, int, int)>{(0, 0, 0)};
  List<(int, int, int)> sorted = [(0, 0, 0)];
  bool dirty = false;
  final failedTypes = <String>{};
  int counter = 0;

  for (final box in order) {
    if (deadline.passed) return Plan(List<Placement>.of(v.placed), timedOut: true);
    // Identical boxes that failed once will fail again: the free space only shrinks.
    if (failedTypes.contains(box.type)) continue;
    if (dirty) {
      sorted = points.toList()
        ..sort((a, b) {
          if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
          if (a.$3 != b.$3) return a.$3.compareTo(b.$3);
          return a.$2.compareTo(b.$2);
        });
      dirty = false;
    }

    Placement? chosen;
    CheckResult? chosenResult;
    for (final pt in sorted) {
      if ((++counter & 255) == 0 && deadline.passed) {
        return Plan(List<Placement>.of(v.placed), timedOut: true);
      }
      final seen = <int>{};
      for (final r in box.rotations) {
        final p = Placement(box, pt.$1, pt.$2, pt.$3, r);
        final int key = p.dx * 1000003 + p.dy * 1009 + p.dz;
        if (!seen.add(key) && !c.options.pressure) continue;
        final res = v.check(p);
        if (!res.ok) continue;
        // Prefer the rotation that reaches least towards the door, then the larger footprint.
        if (chosen == null ||
            p.x2 < chosen.x2 ||
            (p.x2 == chosen.x2 && p.dx * p.dy > chosen.dx * chosen.dy)) {
          chosen = p;
          chosenResult = res;
        }
      }
      if (chosen != null) break;
    }
    if (chosen == null || chosenResult == null) {
      failedTypes.add(box.type);
      continue;
    }
    v.add(chosen, chosenResult);
    _updatePoints(points, chosen, v.placed, c.container);
    dirty = true;
  }
  return Plan(List<Placement>.of(v.placed));
}

int axisStart(Placement q, int axis) => axis == 0 ? q.x : (axis == 1 ? q.y : q.z);
int axisEnd(Placement q, int axis) => axis == 0 ? q.x2 : (axis == 1 ? q.y2 : q.z2);

void _updatePoints(Set<(int, int, int)> points, Placement p, List<Placement> placed, ContainerSpec k) {
  final corners = <List<int>>[
    [p.x2, p.y, p.z],
    [p.x, p.y2, p.z],
    [p.x, p.y, p.z2],
  ];
  for (int axis = 0; axis < 3; axis++) {
    final corner = corners[axis];
    points.add((corner[0], corner[1], corner[2]));
    for (int proj = 0; proj < 3; proj++) {
      if (proj == axis) continue;
      // Slide the corner back along axis [proj] until it meets a wall or a box face.
      int best = 0;
      for (final q in placed) {
        final int qEnd = axisEnd(q, proj);
        if (qEnd > corner[proj] || qEnd <= best) continue;
        bool inside = true;
        for (int i = 0; i < 3; i++) {
          if (i == proj) continue;
          if (!(axisStart(q, i) <= corner[i] && corner[i] < axisEnd(q, i))) {
            inside = false;
            break;
          }
        }
        if (inside) best = qEnd;
      }
      final projected = List<int>.of(corner);
      projected[proj] = best;
      points.add((projected[0], projected[1], projected[2]));
    }
  }
  points.removeWhere((pt) =>
      pt.$1 >= k.length ||
      pt.$2 >= k.width ||
      pt.$3 >= k.height ||
      (p.x <= pt.$1 && pt.$1 < p.x2 && p.y <= pt.$2 && pt.$2 < p.y2 && p.z <= pt.$3 && pt.$3 < p.z2));
}

/// Single-Start: one construction with the default order. Deterministic.
Plan singleStart(LoadingCase c, Deadline deadline, int seed) =>
    constructExtremePoints(c, baseOrder(c.boxes), deadline);

/// Multi-Start: repeats the construction with different box orders until the
/// time budget is used, and keeps the best plan. Orders always respect the
/// unloading-priority groups; only the order inside a group changes.
Plan multiStart(LoadingCase c, Deadline deadline, int seed) {
  final rng = Random(seed);
  final base = baseOrder(c.boxes);
  Plan best = Plan.empty;
  Score bestScore = Score.worst;
  int attempt = 0;
  bool cut = false;
  while (!deadline.passed) {
    final List<BoxItem> order;
    if (attempt == 0) {
      order = base;
    } else if (attempt == 1) {
      order = _sortedWithin(base, (b) => -(b.size[0] * b.size[1]).toDouble()); // largest base first
    } else if (attempt == 2) {
      order = _sortedWithin(base, (b) => -b.size[2].toDouble()); // tallest first
    } else if (attempt == 3) {
      order = _sortedWithin(base, (b) => -b.weight); // heaviest first
    } else {
      // Volume order with random noise: keeps big boxes early but varies the sequence.
      final noise = <String, double>{};
      for (final b in base) {
        noise[b.id] = -b.volume * exp(0.6 * (rng.nextDouble() - 0.5));
      }
      order = _sortedWithin(base, (b) => noise[b.id]!);
    }
    attempt++;
    final plan = constructExtremePoints(c, order, deadline);
    final s = Score.of(plan);
    if (s.betterThan(bestScore)) {
      best = plan;
      bestScore = s;
    }
    if (plan.timedOut) {
      cut = true;
      break;
    }
  }
  return cut ? best.withTimedOut() : best;
}

List<BoxItem> _sortedWithin(List<BoxItem> base, double Function(BoxItem) key) {
  final keys = <String, double>{for (final b in base) b.id: key(b)};
  return List<BoxItem>.of(base)
    ..sort((a, b) {
      if (a.priorityKey != b.priorityKey) return b.priorityKey.compareTo(a.priorityKey);
      if (a.floorOnly != b.floorOnly) return a.floorOnly ? -1 : 1;
      final int k = keys[a.id]!.compareTo(keys[b.id]!);
      if (k != 0) return k;
      return a.id.compareTo(b.id);
    });
}
