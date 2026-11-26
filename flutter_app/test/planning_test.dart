import 'package:container_packing_test/domain/containers.dart';
import 'package:container_packing_test/domain/planning.dart';
import 'package:container_packing_test/domain/sample.dart';
import 'package:container_packing_test/domain/shipment.dart';
import 'package:flutter_test/flutter_test.dart';

// SH-102 in a 20GP must give the same results as the recorded engine runs.
void main() {
  final ship = Shipment(
    id: 1,
    userId: 1,
    code: 'SH-102',
    name: '',
    container: containerPresets.first,
    status: 'reviewed',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('instant plan (Block-Building)', () async {
    final o = await runPlan(ship, sh102Groups, 'instant');
    expect(o.total, 121);
    expect(o.placed.length, 70);
    expect(o.utilization, closeTo(67.429, 0.01));
    expect(o.valid, isTrue);
    expect(o.placed.first.id, 'SH102-B02-24');
    expect(o.unplaced['SH102-B05-01'], 'reason_noOrientation');
  });

  test('optimized plan (Beam Search)', () async {
    final o = await runPlan(ship, sh102Groups, 'optimized');
    expect(o.placed.length, 91);
    expect(o.utilization, closeTo(74.876, 0.01));
    expect(o.valid, isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
