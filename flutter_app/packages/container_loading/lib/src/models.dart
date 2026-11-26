/// Core data types.
///
/// Coordinate system (millimetres):
///   x = along the container length. x = 0 is the back wall, the door is at x = length.
///   y = across the width.  z = height (z = 0 is the floor).
/// Boxes are loaded from the back wall towards the door, so a box with a lower
/// unloading priority number (unloaded earlier) should end up with a larger x.
library;

/// A rotation is a permutation of the box's source axes (0 = length, 1 = width, 2 = height).
/// The oriented size is (size[r[0]], size[r[1]], size[r[2]]); r[2] is the axis that stands vertical.
typedef Rotation = List<int>;

const List<Rotation> allRotations = [
  [0, 1, 2],
  [0, 2, 1],
  [1, 0, 2],
  [1, 2, 0],
  [2, 0, 1],
  [2, 1, 0],
];

bool sameRotation(Rotation a, Rotation b) => a[0] == b[0] && a[1] == b[1] && a[2] == b[2];

class ContainerSpec {
  final String id;
  final int length;
  final int width;
  final int height;
  final double? payloadKg;
  final int? doorWidth;
  final int? doorHeight;

  const ContainerSpec({
    required this.id,
    required this.length,
    required this.width,
    required this.height,
    this.payloadKg,
    this.doorWidth,
    this.doorHeight,
  });

  bool get hasDoor => doorWidth != null && doorHeight != null;
  int get volume => length * width * height;
  List<int> get size => [length, width, height];
}

class BoxItem {
  /// Unique id of this physical box (type id + running number).
  final String id;

  /// Box type. Boxes of the same type are identical.
  final String type;
  final List<int> size; // [length, width, height] in mm
  final double? weightKg;
  final List<Rotation> rotations;
  final bool floorOnly;
  final bool? stackable; // may anything be placed on top of this box?
  final bool? similarAbove; // may a box of the same type be placed on top?
  final bool? differentAbove; // may a box of another type be placed on top?
  final bool? fragile;

  /// Load-bearing strength in kg/cm2 of the top face when source axis i is vertical.
  final List<double>? pressure;

  /// Unloading priority: 1 = unloaded first (should be nearest the door). null = no priority.
  final int? priority;
  final String? contents;

  BoxItem({
    required this.id,
    required this.type,
    required this.size,
    this.weightKg,
    required this.rotations,
    this.floorOnly = false,
    this.stackable,
    this.similarAbove,
    this.differentAbove,
    this.fragile,
    this.pressure,
    this.priority,
    this.contents,
  });

  int get volume => size[0] * size[1] * size[2];
  double get weight => weightKg ?? 0.0;

  /// Priority used for ordering. Boxes without priority form one group (0).
  int get priorityKey => priority ?? 0;

  int get minDimension {
    int m = size[0];
    if (size[1] < m) m = size[1];
    if (size[2] < m) m = size[2];
    return m;
  }

  bool allowsRotation(Rotation r) {
    for (final allowed in rotations) {
      if (sameRotation(allowed, r)) return true;
    }
    return false;
  }
}

class Placement {
  final BoxItem box;
  final int x;
  final int y;
  final int z;
  final Rotation rotation;
  final int dx;
  final int dy;
  final int dz;

  Placement(this.box, this.x, this.y, this.z, this.rotation)
      : dx = box.size[rotation[0]],
        dy = box.size[rotation[1]],
        dz = box.size[rotation[2]];

  int get x2 => x + dx;
  int get y2 => y + dy;
  int get z2 => z + dz;
  int get volume => dx * dy * dz;

  /// Source axis standing vertical (index into box.pressure).
  int get verticalAxis => rotation[2];

  /// Top-face area in cm2 (1 cm2 = 100 mm2).
  double get topAreaCm2 => dx * dy / 100.0;

  Map<String, Object?> toJson() => {
        'box': box.id,
        'type': box.type,
        'x': x,
        'y': y,
        'z': z,
        'dx': dx,
        'dy': dy,
        'dz': dz,
        'rotation': rotation,
        'weightKg': box.weightKg,
        'priority': box.priority,
      };
}

class Plan {
  final List<Placement> placed;
  final bool timedOut;

  const Plan(this.placed, {this.timedOut = false});

  static const Plan empty = Plan(<Placement>[]);

  Plan withTimedOut() => Plan(placed, timedOut: true);

  int get volume {
    int v = 0;
    for (final p in placed) {
      v += p.volume;
    }
    return v;
  }
}

class CaseOptions {
  final bool support; // full base support required
  final bool stacking; // stackable / similar / different flags enforced
  final bool pressure; // load-bearing strength enforced
  final bool fragileBlocksStacking; // nothing may be placed on a fragile box

  const CaseOptions({
    this.support = true,
    this.stacking = true,
    this.pressure = false,
    this.fragileBlocksStacking = true,
  });
}

class LoadingCase {
  final String id;
  final String source;
  final String group;
  final ContainerSpec container;
  final List<BoxItem> boxes;
  final CaseOptions options;
  final double? referenceRatio;
  final String? referenceKind;
  final List<String> notes;

  LoadingCase({
    required this.id,
    required this.source,
    required this.group,
    required this.container,
    required this.boxes,
    this.options = const CaseOptions(),
    this.referenceRatio,
    this.referenceKind,
    this.notes = const [],
  });

  int get totalBoxVolume {
    int v = 0;
    for (final b in boxes) {
      v += b.volume;
    }
    return v;
  }
}

/// Wall-clock time budget shared by every algorithm.
class Deadline {
  final Stopwatch _watch = Stopwatch()..start();
  final int _limitMicros;

  Deadline(Duration budget) : _limitMicros = budget.inMicroseconds;

  bool get passed => _watch.elapsedMicroseconds >= _limitMicros;
  Duration get elapsed => _watch.elapsed;
}
