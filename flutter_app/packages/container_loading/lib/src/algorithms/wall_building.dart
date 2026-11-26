/// Wall-Building: a simulation of traditional manual loading
/// (George & Robinson, 1980).
///
/// The container is filled with vertical walls across its width, from the back
/// wall towards the door. The first box of a wall fixes the wall depth; the rest
/// of the wall is filled column by column (across y, then up in z) with boxes
/// that fit inside that depth. Boxes are taken largest first, the way a loader
/// picks them up. Each wall holds one unloading-priority group, so boxes that
/// leave last go in first (LIFO). Deterministic.
library;

import '../models.dart';
import '../validator.dart';

/// Manual loading order: boxes unloaded last first, floor-only boxes early,
/// then larger volume first.
int compareManual(BoxItem a, BoxItem b) {
  if (a.priorityKey != b.priorityKey) return b.priorityKey.compareTo(a.priorityKey);
  if (a.floorOnly != b.floorOnly) return a.floorOnly ? -1 : 1;
  if (a.volume != b.volume) return b.volume.compareTo(a.volume);
  return a.id.compareTo(b.id);
}

Plan wallBuilding(LoadingCase c, Deadline deadline, int seed) {
  final k = c.container;
  final v = Validator(c);
  final remaining = List<BoxItem>.of(c.boxes)..sort(compareManual);
  final exhausted = <int>{};
  int wallX = 0;

  while (remaining.isNotEmpty && wallX < k.length) {
    if (deadline.passed) return Plan(List<Placement>.of(v.placed), timedOut: true);

    final int? group = _currentGroup(remaining, exhausted);
    if (group == null) break;
    final inGroup = <BoxItem>[for (final b in remaining) if (b.priorityKey == group) b];

    // The first box of the wall sets its depth.
    final lead = _placeAt(v, inGroup, remaining, wallX, 0, 0, k.length);
    if (lead == null) {
      exhausted.add(group);
      continue;
    }
    final int wallEnd = lead.x2;

    // Fill the rest of the wall: across the width first, then upwards.
    // When the group runs out, the next group tops up the same wall, pushed to
    // its door side so it never sits deeper than the boxes behind it.
    final points = <(int, int, int)>[];
    _addCorners(points, lead, wallEnd, k);
    int fillGroup = group;
    List<BoxItem> candidates = inGroup;
    bool front = false;
    while (true) {
      bool progress = true;
      while (progress && candidates.isNotEmpty) {
        if (deadline.passed) return Plan(List<Placement>.of(v.placed), timedOut: true);
        progress = false;
        points.sort((a, b) {
          if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
          if (a.$3 != b.$3) return a.$3.compareTo(b.$3);
          return a.$1.compareTo(b.$1);
        });
        for (int i = 0; i < points.length; i++) {
          final pt = points[i];
          final p = _placeAt(v, candidates, remaining, pt.$1, pt.$2, pt.$3, wallEnd, alignFront: front);
          if (p == null) continue;
          points.removeAt(i);
          points.removeWhere((q) =>
              p.x <= q.$1 && q.$1 < p.x2 && p.y <= q.$2 && q.$2 < p.y2 && p.z <= q.$3 && q.$3 < p.z2);
          _addCorners(points, p, wallEnd, k);
          progress = true;
          break;
        }
      }
      if (candidates.isNotEmpty) break; // this group still needs more walls
      final int? next = _currentGroup(remaining, exhausted, below: fillGroup);
      if (next == null) break;
      fillGroup = next;
      candidates = <BoxItem>[for (final b in remaining) if (b.priorityKey == next) b];
      front = true;
    }
    wallX = wallEnd;
  }
  return Plan(List<Placement>.of(v.placed));
}

int? _currentGroup(List<BoxItem> remaining, Set<int> exhausted, {int? below}) {
  int? best;
  for (final b in remaining) {
    final g = b.priorityKey;
    if (exhausted.contains(g)) continue;
    if (below != null && g >= below) continue;
    if (best == null || g > best) best = g;
  }
  return best;
}

/// Places the first box (in manual order) that fits at (x, y, z) without
/// reaching past [xLimit]; with [alignFront] the box touches [xLimit] instead.
/// Rotations showing the largest face to the door are tried first.
Placement? _placeAt(Validator v, List<BoxItem> candidates, List<BoxItem> remaining, int x, int y, int z,
    int xLimit, {bool alignFront = false}) {
  final triedTypes = <String>{};
  for (final box in candidates) {
    // Identical boxes give the same answer at the same point.
    if (!triedTypes.add(box.type)) continue;
    final rotations = List<Rotation>.of(box.rotations)
      ..sort((a, b) {
        final pa = Placement(box, 0, 0, 0, a), pb = Placement(box, 0, 0, 0, b);
        final int fa = pa.dy * pa.dz, fb = pb.dy * pb.dz;
        if (fa != fb) return fb.compareTo(fa);
        return pa.dx.compareTo(pb.dx);
      });
    for (final r in rotations) {
      final probe = Placement(box, x, y, z, r);
      final p = alignFront ? Placement(box, xLimit - probe.dx, y, z, r) : probe;
      if (p.x < 0 || p.x2 > xLimit) continue;
      final res = v.check(p);
      if (!res.ok) continue;
      v.add(p, res);
      candidates.remove(box);
      remaining.remove(box);
      return p;
    }
  }
  return null;
}

void _addCorners(List<(int, int, int)> points, Placement p, int wallEnd, ContainerSpec k) {
  for (final q in [(p.x, p.y2, p.z), (p.x, p.y, p.z2), (p.x2, p.y, p.z)]) {
    if (q.$1 >= wallEnd || q.$2 >= k.width || q.$3 >= k.height) continue;
    if (!points.contains(q)) points.add(q);
  }
}
