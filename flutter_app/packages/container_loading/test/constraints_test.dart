// Unit tests: each constraint on its own.
import 'package:container_loading/container_loading.dart';
import 'package:test/test.dart';

const Rotation fixed = [0, 1, 2];

BoxItem box(String id, List<int> size,
        {double? weight = 10,
        List<Rotation> rotations = const [fixed],
        bool floorOnly = false,
        bool? stackable,
        bool? fragile,
        bool? similarAbove,
        bool? differentAbove,
        List<double>? pressure,
        int? priority,
        String? type}) =>
    BoxItem(
      id: id,
      type: type ?? id,
      size: size,
      weightKg: weight,
      rotations: rotations,
      floorOnly: floorOnly,
      stackable: stackable,
      fragile: fragile,
      similarAbove: similarAbove,
      differentAbove: differentAbove,
      pressure: pressure,
      priority: priority,
    );

LoadingCase caseOf(List<BoxItem> boxes,
        {double? payload = 1000,
        int? doorWidth = 200,
        int? doorHeight = 200,
        bool pressure = false,
        bool fragileBlocksStacking = true}) =>
    LoadingCase(
      id: 'T',
      source: 'test',
      group: 'TEST',
      container: ContainerSpec(
          id: 'C',
          length: 300,
          width: 200,
          height: 300,
          payloadKg: payload,
          doorWidth: doorWidth,
          doorHeight: doorHeight),
      boxes: boxes,
      options: CaseOptions(pressure: pressure, fragileBlocksStacking: fragileBlocksStacking),
    );

Placement at(BoxItem b, int x, int y, int z, [Rotation r = fixed]) => Placement(b, x, y, z, r);

void main() {
  group('geometry', () {
    test('touching faces are not an overlap, one millimetre inside is', () {
      final a = box('a', [100, 100, 100]);
      final b = box('b', [100, 100, 100]);
      expect(placementsOverlap(at(a, 0, 0, 0), at(b, 100, 0, 0)), isFalse);
      expect(placementsOverlap(at(a, 0, 0, 0), at(b, 0, 100, 0)), isFalse);
      expect(placementsOverlap(at(a, 0, 0, 0), at(b, 99, 0, 0)), isTrue);
    });

    test('container bounds', () {
      final a = box('a', [100, 100, 100]);
      final v = Validator(caseOf([a]));
      expect(v.check(at(a, 201, 0, 0)).violation, Violation.bounds);
      expect(v.check(at(a, 200, 0, 0)).ok, isTrue);
    });

    test('overlap with a placed box', () {
      final a = box('a', [100, 100, 100]);
      final b = box('b', [100, 100, 100]);
      final v = Validator(caseOf([a, b]));
      expect(v.tryAdd(at(a, 0, 0, 0)), isNull);
      expect(v.check(at(b, 50, 0, 0)).violation, Violation.overlap);
    });
  });

  group('container rules', () {
    test('door opening is checked on the width x height cross-section', () {
      final tall = box('tall', [50, 50, 210]);
      final v = Validator(caseOf([tall], doorHeight: 200));
      expect(v.check(at(tall, 0, 0, 0)).violation, Violation.door);
    });

    test('payload: exactly at the limit is allowed, above is not', () {
      final a = box('a', [100, 100, 100], weight: 600);
      final b = box('b', [100, 100, 100], weight: 400);
      final c = box('c', [100, 100, 100], weight: 400.01);
      final v = Validator(caseOf([a, b, c]));
      expect(v.tryAdd(at(a, 0, 0, 0)), isNull);
      expect(v.check(at(c, 100, 0, 0)).violation, Violation.payload);
      expect(v.check(at(b, 100, 0, 0)).ok, isTrue);
    });
  });

  group('box rules', () {
    test('orientation not in the allowed list is rejected', () {
      final a = box('a', [100, 50, 80]);
      final v = Validator(caseOf([a]));
      expect(v.check(at(a, 0, 0, 0, [2, 1, 0])).violation, Violation.orientation);
    });

    test('floor-only box cannot be lifted', () {
      final base = box('base', [100, 100, 100]);
      final f = box('f', [100, 100, 100], floorOnly: true);
      final v = Validator(caseOf([base, f]));
      v.tryAdd(at(base, 0, 0, 0));
      expect(v.check(at(f, 0, 0, 100)).violation, Violation.floorOnly);
    });

    test('full support: partial support is rejected, two boxes together are accepted', () {
      final l = box('l', [100, 100, 100], type: 'T');
      final r = box('r', [100, 100, 100], type: 'T');
      final top = box('top', [200, 100, 50]);
      final v = Validator(caseOf([l, r, top]));
      v.tryAdd(at(l, 0, 0, 0));
      expect(v.check(at(top, 0, 0, 100)).violation, Violation.support);
      v.tryAdd(at(r, 100, 0, 0));
      expect(v.check(at(top, 0, 0, 100)).ok, isTrue);
      expect(v.check(at(top, 0, 0, 101)).violation, Violation.support); // floating
    });

    test('non-stackable box', () {
      final base = box('base', [100, 100, 100], stackable: false);
      final top = box('top', [100, 100, 50]);
      final v = Validator(caseOf([base, top]));
      v.tryAdd(at(base, 0, 0, 0));
      expect(v.check(at(top, 0, 0, 100)).violation, Violation.stacking);
    });

    test('fragile box blocks stacking only when the case says so', () {
      final base = box('base', [100, 100, 100], fragile: true);
      final top = box('top', [100, 100, 50]);
      final v1 = Validator(caseOf([base, top]));
      v1.tryAdd(at(base, 0, 0, 0));
      expect(v1.check(at(top, 0, 0, 100)).violation, Violation.stacking);
      final v2 = Validator(caseOf([base, top], fragileBlocksStacking: false));
      v2.tryAdd(at(base, 0, 0, 0));
      expect(v2.check(at(top, 0, 0, 100)).ok, isTrue);
    });

    test('similar / different box above', () {
      final base = box('base', [100, 100, 100], type: 'A', similarAbove: true, differentAbove: false);
      final same = box('same', [100, 100, 100], type: 'A');
      final other = box('other', [100, 100, 100], type: 'B');
      final v = Validator(caseOf([base, same, other]));
      v.tryAdd(at(base, 0, 0, 0));
      expect(v.check(at(other, 0, 0, 100)).violation, Violation.stacking);
      expect(v.check(at(same, 0, 0, 100)).ok, isTrue);
    });

    test('load bearing is passed down through a stack', () {
      // 100 x 100 mm top face = 100 cm2. Strength 0.1 kg/cm2 -> 10 kg; 1 kg/cm2 -> 100 kg.
      final weak = box('weak', [100, 100, 100], weight: 1, pressure: [0.1, 0.1, 0.1]);
      final mid = box('mid', [100, 100, 100], weight: 4, pressure: [1, 1, 1]);
      final top = box('top', [100, 100, 50], weight: 7, pressure: [1, 1, 1]);
      final v = Validator(caseOf([weak, mid, top], pressure: true));
      expect(v.tryAdd(at(weak, 0, 0, 0)), isNull);
      expect(v.tryAdd(at(mid, 0, 0, 100)), isNull); // weak carries 4 kg
      // top adds 7 kg to mid (fine) and 7 kg to weak: 11 kg > 10 kg
      expect(v.check(at(top, 0, 0, 200)).violation, Violation.loadBearing);
    });

    test('rollback restores weight and load', () {
      final a = box('a', [100, 100, 100], weight: 5, pressure: [1, 1, 1]);
      final b = box('b', [100, 100, 100], weight: 5, pressure: [1, 1, 1]);
      final v = Validator(caseOf([a, b], pressure: true));
      v.tryAdd(at(a, 0, 0, 0));
      final m = v.mark;
      v.tryAdd(at(b, 0, 0, 100));
      expect(v.carried['a'], closeTo(5, 1e-9));
      v.rollback(m);
      expect(v.placed.length, 1);
      expect(v.totalWeight, closeTo(5, 1e-9));
      expect(v.carried['a'], closeTo(0, 1e-9));
    });
  });

  group('plan checks and metrics', () {
    test('validatePlan reports overlaps and unknown boxes', () {
      final a = box('a', [100, 100, 100]);
      final b = box('b', [100, 100, 100]);
      final stranger = box('x', [10, 10, 10]);
      final c = caseOf([a, b]);
      final issues = validatePlan(c, Plan([at(a, 0, 0, 0), at(b, 50, 0, 0), at(stranger, 250, 0, 0)]));
      expect(issues, contains('b: ${Violation.overlap}'));
      expect(issues, contains('x: unknown_box'));
    });

    test('priority inversions: earlier unloading must be nearer the door (larger x)', () {
      final first = box('first', [10, 10, 10], priority: 1);
      final second = box('second', [10, 10, 10], priority: 2);
      final good = priorityInversions([at(second, 0, 0, 0), at(first, 10, 0, 0)]);
      final bad = priorityInversions([at(first, 0, 0, 0), at(second, 10, 0, 0)]);
      expect(good.inversions, 0);
      expect(good.pairs, 1);
      expect(bad.inversions, 1);
    });

    test('validateCase rejects missing weight under a payload limit', () {
      final a = box('a', [100, 100, 100], weight: null);
      expect(() => validateCase(caseOf([a])), throwsFormatException);
    });
  });
}
