/// Constraint checking.
///
/// [Validator] checks placements one at a time against everything placed so far.
/// It is used both inside the algorithms (to accept or reject a move) and by
/// [validatePlan], which re-checks a finished plan independently of the
/// algorithm that produced it.
library;

import 'models.dart';

const double _eps = 1e-9;

/// Reasons a placement can be rejected. They appear in the results files.
class Violation {
  static const duplicate = 'duplicate_box';
  static const orientation = 'orientation';
  static const bounds = 'container_bounds';
  static const door = 'door_opening';
  static const payload = 'payload_limit';
  static const floorOnly = 'floor_only';
  static const overlap = 'overlap';
  static const support = 'full_support';
  static const stacking = 'stacking_forbidden';
  static const loadBearing = 'load_bearing';
}

bool boxesOverlap(int ax, int ay, int az, int adx, int ady, int adz, int bx, int by, int bz, int bdx, int bdy,
    int bdz) {
  return ax < bx + bdx && bx < ax + adx && ay < by + bdy && by < ay + ady && az < bz + bdz && bz < az + adz;
}

bool placementsOverlap(Placement a, Placement b) =>
    boxesOverlap(a.x, a.y, a.z, a.dx, a.dy, a.dz, b.x, b.y, b.z, b.dx, b.dy, b.dz);

/// May [top] rest directly on [below]?
bool allowsOnTop(BoxItem below, BoxItem top, CaseOptions options) {
  if (!options.stacking) return true;
  if (below.stackable == false) return false;
  if (options.fragileBlocksStacking && below.fragile == true) return false;
  final bool sameType = below.type == top.type;
  final bool? flag = sameType ? below.similarAbove : below.differentAbove;
  if (flag == false) return false;
  return true;
}

/// Contact between a box and one of the boxes directly underneath it.
class Support {
  final Placement lower;
  final double share; // fraction of the upper box's base resting on [lower]
  const Support(this.lower, this.share);
}

class CheckResult {
  final String? violation;
  final List<Support> supports;
  final Map<String, double> loadIncrements;

  const CheckResult(this.violation, this.supports, this.loadIncrements);

  bool get ok => violation == null;
}

class _Undo {
  final Placement placement;
  final Map<String, double> loadIncrements;
  _Undo(this.placement, this.loadIncrements);
}

class Validator {
  final LoadingCase loadingCase;
  final List<Placement> placed;
  final Set<String> _ids;
  double totalWeight;

  /// Load (kg) currently resting on each placed box, including load passed down from higher boxes.
  final Map<String, double> carried;

  /// Supports of each placed box (used to pass load downwards).
  final Map<String, List<Support>> supportsOf;

  final List<_Undo> _log = [];

  Validator(this.loadingCase)
      : placed = <Placement>[],
        _ids = <String>{},
        totalWeight = 0.0,
        carried = <String, double>{},
        supportsOf = <String, List<Support>>{};

  Validator._copy(Validator other)
      : loadingCase = other.loadingCase,
        placed = List<Placement>.of(other.placed),
        _ids = Set<String>.of(other._ids),
        totalWeight = other.totalWeight,
        carried = Map<String, double>.of(other.carried),
        supportsOf = Map<String, List<Support>>.of(other.supportsOf);

  Validator clone() => Validator._copy(this);

  ContainerSpec get container => loadingCase.container;
  CaseOptions get options => loadingCase.options;

  bool contains(String boxId) => _ids.contains(boxId);

  CheckResult check(Placement p) {
    final box = p.box;
    final c = container;
    const noSupports = <Support>[];
    const noLoads = <String, double>{};

    if (_ids.contains(box.id)) return const CheckResult(Violation.duplicate, noSupports, noLoads);
    if (!box.allowsRotation(p.rotation)) return const CheckResult(Violation.orientation, noSupports, noLoads);
    if (p.x < 0 || p.y < 0 || p.z < 0 || p.x2 > c.length || p.y2 > c.width || p.z2 > c.height) {
      return const CheckResult(Violation.bounds, noSupports, noLoads);
    }
    if (c.hasDoor && (p.dy > c.doorWidth! || p.dz > c.doorHeight!)) {
      return const CheckResult(Violation.door, noSupports, noLoads);
    }
    if (c.payloadKg != null && totalWeight + box.weight > c.payloadKg! + _eps) {
      return const CheckResult(Violation.payload, noSupports, noLoads);
    }
    if (box.floorOnly && p.z != 0) return const CheckResult(Violation.floorOnly, noSupports, noLoads);
    for (final q in placed) {
      if (placementsOverlap(p, q)) return const CheckResult(Violation.overlap, noSupports, noLoads);
    }
    if (p.z == 0) return const CheckResult(null, noSupports, noLoads);
    if (!options.support) return const CheckResult(null, noSupports, noLoads);

    // Full support: the whole base must rest on top faces at height p.z.
    // Placed boxes never overlap, so the contact areas can simply be added.
    final supports = <Support>[];
    final int baseArea = p.dx * p.dy;
    int covered = 0;
    for (final q in placed) {
      if (q.z2 != p.z) continue;
      final int ox = _overlap1d(p.x, p.x2, q.x, q.x2);
      if (ox <= 0) continue;
      final int oy = _overlap1d(p.y, p.y2, q.y, q.y2);
      if (oy <= 0) continue;
      final int area = ox * oy;
      covered += area;
      supports.add(Support(q, area / baseArea));
    }
    if (covered < baseArea) return const CheckResult(Violation.support, noSupports, noLoads);

    for (final s in supports) {
      if (!allowsOnTop(s.lower.box, box, options)) {
        return const CheckResult(Violation.stacking, noSupports, noLoads);
      }
    }

    if (!options.pressure || box.weight <= 0) return CheckResult(null, supports, noLoads);

    // Pass the new box's weight down through every box underneath it.
    final increments = <String, double>{};
    final lowerOf = <String, Placement>{};
    final pending = <Support>[];
    final pendingLoad = <double>[];
    for (final s in supports) {
      pending.add(s);
      pendingLoad.add(box.weight * s.share);
    }
    while (pending.isNotEmpty) {
      final s = pending.removeLast();
      final double load = pendingLoad.removeLast();
      final String id = s.lower.box.id;
      increments[id] = (increments[id] ?? 0.0) + load;
      lowerOf[id] = s.lower;
      final below = supportsOf[id];
      if (below != null) {
        for (final b in below) {
          pending.add(b);
          pendingLoad.add(load * b.share);
        }
      }
    }
    for (final entry in increments.entries) {
      final q = lowerOf[entry.key]!;
      final strength = q.box.pressure;
      if (strength == null) continue;
      final double limit = strength[q.verticalAxis] * q.topAreaCm2;
      if ((carried[entry.key] ?? 0.0) + entry.value > limit + _eps) {
        return const CheckResult(Violation.loadBearing, noSupports, noLoads);
      }
    }
    return CheckResult(null, supports, increments);
  }

  /// Adds a placement that has already passed [check].
  void add(Placement p, CheckResult result) {
    placed.add(p);
    _ids.add(p.box.id);
    totalWeight += p.box.weight;
    if (result.supports.isNotEmpty) supportsOf[p.box.id] = result.supports;
    result.loadIncrements.forEach((id, load) {
      carried[id] = (carried[id] ?? 0.0) + load;
    });
    _log.add(_Undo(p, result.loadIncrements));
  }

  /// Checks and adds in one step. Returns the violation, or null when the box was added.
  String? tryAdd(Placement p) {
    final r = check(p);
    if (r.ok) add(p, r);
    return r.violation;
  }

  int get mark => _log.length;

  /// Removes everything added after [mark] (used to try a block of boxes tentatively).
  void rollback(int mark) {
    while (_log.length > mark) {
      final u = _log.removeLast();
      placed.removeLast();
      _ids.remove(u.placement.box.id);
      totalWeight -= u.placement.box.weight;
      supportsOf.remove(u.placement.box.id);
      u.loadIncrements.forEach((id, load) {
        carried[id] = (carried[id] ?? 0.0) - load;
      });
    }
  }
}

int _overlap1d(int a1, int a2, int b1, int b2) {
  final int lo = a1 > b1 ? a1 : b1;
  final int hi = a2 < b2 ? a2 : b2;
  return hi - lo;
}

/// Checks the case data itself before any algorithm runs. Throws [FormatException].
void validateCase(LoadingCase c) {
  final k = c.container;
  if (k.length <= 0 || k.width <= 0 || k.height <= 0) {
    throw FormatException('${c.id}: container dimensions must be positive');
  }
  if (k.hasDoor && (k.doorWidth! <= 0 || k.doorHeight! <= 0)) {
    throw FormatException('${c.id}: door dimensions must be positive');
  }
  if (k.payloadKg != null && k.payloadKg! < 0) throw FormatException('${c.id}: negative payload');
  final ids = <String>{};
  for (final b in c.boxes) {
    if (!ids.add(b.id)) throw FormatException('${c.id}: duplicate box id ${b.id}');
    if (b.size.length != 3 || b.size.any((v) => v <= 0)) {
      throw FormatException('${c.id}: invalid size for ${b.id}');
    }
    if (b.rotations.isEmpty) throw FormatException('${c.id}: no allowed rotation for ${b.id}');
    if (b.weightKg != null && b.weightKg! < 0) throw FormatException('${c.id}: negative weight for ${b.id}');
    if (k.payloadKg != null && b.weightKg == null) {
      throw FormatException('${c.id}: weight missing for ${b.id} while a payload limit is active');
    }
    if (b.priority != null && b.priority! < 1) throw FormatException('${c.id}: priority must be >= 1 (${b.id})');
    if (c.options.pressure && (b.pressure == null || b.pressure!.length != 3)) {
      throw FormatException('${c.id}: load-bearing values missing for ${b.id}');
    }
  }
}

/// Re-checks a finished plan from scratch. Returns a list of problems (empty = valid).
List<String> validatePlan(LoadingCase c, Plan plan) {
  final issues = <String>[];
  final known = <String, BoxItem>{for (final b in c.boxes) b.id: b};
  final ordered = List<Placement>.of(plan.placed)
    ..sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      if (a.x != b.x) return a.x.compareTo(b.x);
      return a.y.compareTo(b.y);
    });
  final v = Validator(c);
  for (final p in ordered) {
    if (!identical(known[p.box.id], p.box)) {
      issues.add('${p.box.id}: unknown_box');
      continue;
    }
    final r = v.check(p);
    if (r.ok) {
      v.add(p, r);
    } else {
      issues.add('${p.box.id}: ${r.violation}');
    }
  }
  return issues;
}
