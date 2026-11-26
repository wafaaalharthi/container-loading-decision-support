import 'containers.dart';

const List<String> kKinds = [
  'electronics',
  'glass',
  'iron_metal',
  'machinery',
  'wood_furniture',
  'food',
  'textiles',
  'paper',
  'other',
];

/// One line of the shipment: [quantity] identical boxes. Lengths in mm.
class BoxGroup {
  final int? id;
  final int? shipmentId;
  final String code; // B01, B02, ...
  final String kind;
  final String custom; // own category name when kind == other
  final String contents;
  final int lengthMm;
  final int widthMm;
  final int heightMm;
  final double weightKg;
  final int quantity;
  final int priority; // 1 = unloaded first
  final String orientation; // any | upright
  final bool fragile;
  final bool floorOnly;
  final bool stackable;
  final String stacking; // any | same | other
  final double? loadBearingKg;

  const BoxGroup({
    this.id,
    this.shipmentId,
    required this.code,
    required this.kind,
    this.custom = '',
    this.contents = '',
    required this.lengthMm,
    required this.widthMm,
    required this.heightMm,
    required this.weightKg,
    required this.quantity,
    this.priority = 1,
    this.orientation = 'any',
    this.fragile = false,
    this.floorOnly = false,
    this.stackable = true,
    this.stacking = 'any',
    this.loadBearingKg,
  });

  double get boxVolumeM3 => lengthMm * widthMm * heightMm / 1e9;
  double get totalVolumeM3 => boxVolumeM3 * quantity;
  double get totalWeightKg => weightKg * quantity;

  factory BoxGroup.fromRow(Map<String, Object?> r) => BoxGroup(
        id: r['id'] as int?,
        shipmentId: r['shipment_id'] as int?,
        code: r['code'] as String,
        kind: r['category'] as String? ?? 'other',
        custom: r['custom'] as String? ?? '',
        contents: r['contents'] as String? ?? '',
        lengthMm: r['length_mm'] as int,
        widthMm: r['width_mm'] as int,
        heightMm: r['height_mm'] as int,
        weightKg: (r['weight_kg'] as num).toDouble(),
        quantity: r['quantity'] as int,
        priority: r['priority'] as int? ?? 1,
        orientation: (r['upright'] as int? ?? 0) == 1 ? 'upright' : 'any',
        fragile: (r['fragile'] as int? ?? 0) == 1,
        floorOnly: (r['floor_only'] as int? ?? 0) == 1,
        stackable: (r['stackable'] as int? ?? 1) == 1,
        stacking: r['stacking'] as String? ?? 'any',
        loadBearingKg: (r['max_stack_kg'] as num?)?.toDouble(),
      );

  Map<String, Object?> toRow(int shipmentId) => {
        'shipment_id': shipmentId,
        'code': code,
        'category': kind,
        'custom': custom,
        'contents': contents,
        'length_mm': lengthMm,
        'width_mm': widthMm,
        'height_mm': heightMm,
        'weight_kg': weightKg,
        'quantity': quantity,
        'priority': priority,
        'upright': orientation == 'upright' ? 1 : 0,
        'fragile': fragile ? 1 : 0,
        'floor_only': floorOnly ? 1 : 0,
        'stackable': stackable ? 1 : 0,
        'stacking': stacking,
        'max_stack_kg': loadBearingKg,
      };

  BoxGroup withCode(String c) => BoxGroup(
        id: id,
        shipmentId: shipmentId,
        code: c,
        kind: kind,
        custom: custom,
        contents: contents,
        lengthMm: lengthMm,
        widthMm: widthMm,
        heightMm: heightMm,
        weightKg: weightKg,
        quantity: quantity,
        priority: priority,
        orientation: orientation,
        fragile: fragile,
        floorOnly: floorOnly,
        stackable: stackable,
        stacking: stacking,
        loadBearingKg: loadBearingKg,
      );

  /// IDs of the physical boxes, e.g. SH102-B02-01 ... SH102-B02-24.
  List<String> boxIds(String shipmentCode) {
    final prefix = shipmentCode.replaceAll('-', '').replaceAll(' ', '');
    final width = quantity.toString().length < 2 ? 2 : quantity.toString().length;
    return [for (var i = 1; i <= quantity; i++) '$prefix-$code-${i.toString().padLeft(width, '0')}'];
  }
}

class Shipment {
  final int id;
  final int userId;
  final String code;
  final String name;
  final ContainerDims container;
  final String status; // draft | reviewed
  final DateTime createdAt;
  final DateTime updatedAt;

  const Shipment({
    required this.id,
    required this.userId,
    required this.code,
    required this.name,
    required this.container,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Shipment.fromRow(Map<String, Object?> r) => Shipment(
        id: r['id'] as int,
        userId: r['user_id'] as int,
        code: r['code'] as String,
        name: r['name'] as String? ?? '',
        container: ContainerDims(
          code: r['container_code'] as String,
          length: r['cont_l'] as int,
          width: r['cont_w'] as int,
          height: r['cont_h'] as int,
          doorWidth: r['door_w'] as int,
          doorHeight: r['door_h'] as int,
          payloadKg: (r['payload_kg'] as num).toDouble(),
        ),
        status: r['status'] as String? ?? 'draft',
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );
}

/// Shipment plus totals for lists.
class ShipmentSummary {
  final Shipment shipment;
  final int groups;
  final int boxes;
  final double weightKg;
  const ShipmentSummary(this.shipment, this.groups, this.boxes, this.weightKg);
}

class ShipmentTotals {
  final int groups;
  final int boxes;
  final double weightKg;
  final double volumeM3;
  const ShipmentTotals(this.groups, this.boxes, this.weightKg, this.volumeM3);

  factory ShipmentTotals.of(List<BoxGroup> gs) {
    var b = 0;
    var kg = 0.0, v = 0.0;
    for (final g in gs) {
      b += g.quantity;
      kg += g.totalWeightKg;
      v += g.totalVolumeM3;
    }
    return ShipmentTotals(gs.length, b, kg, v);
  }
}

/// Next free group code: B01, B02, ...
String nextGroupCode(Iterable<String> used) {
  final taken = used.toSet();
  for (var i = 1; i < 1000; i++) {
    final c = 'B${i.toString().padLeft(2, '0')}';
    if (!taken.contains(c)) return c;
  }
  return 'B${taken.length + 1}';
}
