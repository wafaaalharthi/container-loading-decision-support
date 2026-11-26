import 'containers.dart';
import 'shipment.dart';

/// Field -> error key (same rules as the prototype).
Map<String, String> groupErrors(BoxGroup g) {
  final e = <String, String>{};
  if (!kKinds.contains(g.kind)) e['kind'] = 'errKind';
  for (final (f, v) in [('length', g.lengthMm), ('width', g.widthMm), ('height', g.heightMm)]) {
    if (v <= 0) {
      e[f] = 'errPositive';
    } else if (v > 50000) {
      e[f] = 'errTooLarge';
    }
  }
  if (g.weightKg <= 0) e['weight'] = 'errPositive';
  if (g.quantity < 1) {
    e['quantity'] = 'errWhole';
  } else if (g.quantity > 999) {
    e['quantity'] = 'errTooLarge';
  }
  if (g.priority < 1 || g.priority > 9) e['priority'] = 'errPriority';
  if (g.orientation != 'any' && g.orientation != 'upright') e['orientation'] = 'errOrientation';
  if (g.fragile && g.stackable) e['stackable'] = 'errFragileStack';
  if (g.stackable && !['any', 'same', 'other'].contains(g.stacking)) e['stacking'] = 'errStacking';
  final lb = g.loadBearingKg;
  if (g.stackable && lb != null && lb <= 0) e['loadBearing'] = 'errPositive';
  return e;
}

/// Allowed oriented sizes (l, w, h) in mm, duplicates removed.
List<List<int>> orientations(BoxGroup g) {
  final l = g.lengthMm, w = g.widthMm, h = g.heightMm;
  final raw = g.orientation == 'upright'
      ? [
          [l, w, h],
          [w, l, h],
        ]
      : [
          [l, w, h],
          [w, l, h],
          [l, h, w],
          [h, l, w],
          [w, h, l],
          [h, w, l],
        ];
  final seen = <String>{};
  return [
    for (final o in raw)
      if (seen.add(o.join('x'))) o,
  ];
}

/// Orientations that fit inside the container and through its door.
List<List<int>> fitOrientations(BoxGroup g, ContainerDims c) => [
      for (final o in orientations(g))
        if (o[0] <= c.length && o[1] <= c.width && o[2] <= c.height && o[1] <= c.doorWidth && o[2] <= c.doorHeight) o,
    ];

class InputStatus {
  final bool accepted;
  final String? reasonKey;
  const InputStatus(this.accepted, [this.reasonKey]);
}

InputStatus inputStatus(BoxGroup g, ContainerDims c) {
  if (groupErrors(g).isNotEmpty) return const InputStatus(false, 'reason_invalidData');
  if (g.weightKg > c.payloadKg) return const InputStatus(false, 'reason_overweight');
  if (fitOrientations(g, c).isEmpty) return const InputStatus(false, 'reason_noOrientation');
  return const InputStatus(true);
}
