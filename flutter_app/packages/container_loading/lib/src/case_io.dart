/// Reads cases from the JSON files produced from the project workbook.
library;

import 'dart:convert';

import 'models.dart';

List<LoadingCase> parseCases(String jsonText) {
  final root = jsonDecode(jsonText) as Map<String, dynamic>;
  final list = root['cases'] as List<dynamic>;
  return [for (final c in list) caseFromJson(c as Map<String, dynamic>)];
}

LoadingCase caseFromJson(Map<String, dynamic> j) {
  final cj = j['container'] as Map<String, dynamic>;
  final size = _ints(cj['size']);
  final door = cj['door'] == null ? null : _ints(cj['door']);
  final container = ContainerSpec(
    id: cj['id'] as String,
    length: size[0],
    width: size[1],
    height: size[2],
    payloadKg: _double(cj['payload']),
    doorWidth: door?[0],
    doorHeight: door?[1],
  );
  final oj = (j['options'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  final options = CaseOptions(
    support: (oj['support'] as bool?) ?? true,
    stacking: (oj['stacking'] as bool?) ?? true,
    pressure: (oj['pressure'] as bool?) ?? false,
    fragileBlocksStacking: (oj['fragileBlocksStacking'] as bool?) ?? true,
  );
  final boxes = <BoxItem>[];
  for (final raw in j['boxes'] as List<dynamic>) {
    final b = raw as Map<String, dynamic>;
    final String type = b['type'] as String;
    final int qty = (b['qty'] as num?)?.toInt() ?? 1;
    final rotations = b['rotations'] == null
        ? allRotations
        : <Rotation>[for (final r in b['rotations'] as List<dynamic>) _ints(r)];
    final pressure = b['pressure'] == null
        ? null
        : <double>[for (final v in b['pressure'] as List<dynamic>) (v as num).toDouble()];
    for (int i = 1; i <= qty; i++) {
      boxes.add(BoxItem(
        id: qty == 1 ? type : '$type#$i',
        type: type,
        size: _ints(b['size']),
        weightKg: _double(b['weight']),
        rotations: rotations,
        floorOnly: (b['floorOnly'] as bool?) ?? false,
        stackable: b['stackable'] as bool?,
        similarAbove: b['similarAbove'] as bool?,
        differentAbove: b['differentAbove'] as bool?,
        fragile: b['fragile'] as bool?,
        pressure: pressure,
        priority: (b['priority'] as num?)?.toInt(),
        contents: b['contents'] as String?,
      ));
    }
  }
  final ref = (j['reference'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  return LoadingCase(
    id: j['id'] as String,
    source: (j['source'] as String?) ?? '',
    group: (j['group'] as String?) ?? '',
    container: container,
    boxes: boxes,
    options: options,
    referenceRatio: _double(ref['ratio']),
    referenceKind: ref['kind'] as String?,
    notes: [for (final n in (j['notes'] as List<dynamic>?) ?? const <dynamic>[]) n as String],
  );
}

List<int> _ints(dynamic v) => [for (final x in v as List<dynamic>) (x as num).toInt()];

double? _double(dynamic v) => v == null ? null : (v as num).toDouble();

Map<String, Object?> planToJson(LoadingCase c, String algorithm, Plan plan, Map<String, Object?> metrics) {
  final placedIds = {for (final p in plan.placed) p.box.id};
  return {
    'case': c.id,
    'algorithm': algorithm,
    'container': {
      'size': c.container.size,
      'door': c.container.hasDoor ? [c.container.doorWidth, c.container.doorHeight] : null,
      'payloadKg': c.container.payloadKg,
      'doorAt': 'x = length',
    },
    'metrics': metrics,
    // Placement order = loading order (back wall first).
    'placed': [for (final p in plan.placed) p.toJson()],
    'unplaced': [for (final b in c.boxes) if (!placedIds.contains(b.id)) b.id],
  };
}
