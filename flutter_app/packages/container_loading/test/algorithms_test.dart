// Integration tests: every algorithm on the constraint scenarios and on a few
// benchmark / real cases. Every plan must pass the independent validator.
import 'dart:io';

import 'package:container_loading/container_loading.dart';
import 'package:test/test.dart';

const budget = Duration(milliseconds: 800);

Map<String, LoadingCase> loadCases(String path) =>
    {for (final c in parseCases(File(path).readAsStringSync())) c.id: c};

PlanResult run(LoadingCase c, String algorithm) =>
    planLoad(c, algorithm: algorithm, budget: budget, seed: 7);

Set<String> placedTypes(Plan p) => {for (final x in p.placed) x.box.type};

int placedOfType(Plan p, String type) => p.placed.where((x) => x.box.type == type).length;

void main() {
  final scenarios = loadCases('data/scenarios.json');
  final quick = loadCases('data/cases_quick.json');

  for (final algo in algorithms) {
    group(algo.name, () {
      test('every scenario gives a valid plan', () {
        for (final c in scenarios.values) {
          final r = run(c, algo.name);
          expect(r.issues, isEmpty, reason: '${c.id}: ${r.issues.take(3)}');
          expect(r.plan.placed, isNotEmpty, reason: c.id);
        }
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('door: the 2345 mm wide fixed box never enters', () {
        final r = run(scenarios['SC-01-DOOR']!, algo.name);
        expect(placedTypes(r.plan).contains('WIDE'), isFalse);
      });

      test('payload: at most 28 one-tonne boxes', () {
        final r = run(scenarios['SC-02-PAYLOAD']!, algo.name);
        expect(r.plan.placed.length, lessThanOrEqualTo(28));
        expect(r.plan.placed.length, greaterThanOrEqualTo(20));
      });

      test('oversized box is left out, the others are loaded', () {
        final r = run(scenarios['SC-09-OVERSIZE']!, algo.name);
        expect(placedTypes(r.plan).contains('TOO-LONG'), isFalse);
        expect(placedOfType(r.plan, 'OK'), 20);
      });

      test('the team sample: all five boxes, no priority inversion', () {
        final r = run(scenarios['SC-10-SAMPLE5']!, algo.name);
        expect(r.plan.placed.length, 5);
        expect(r.metrics['priority_inversions'], 0);
      });

      test('floor-only machines stay on the floor', () {
        final r = run(scenarios['SC-04-FLOOR']!, algo.name);
        for (final p in r.plan.placed) {
          if (p.box.type == 'MACHINE') expect(p.z, 0);
        }
      });

      test('benchmark and real cases give valid plans', () {
        for (final id in ['BR1-001', 'BR7-001', 'WT3-001', 'MD2-001-D5', 'ATL-02', 'MAX-E']) {
          final c = quick[id]!;
          final r = run(c, algo.name);
          expect(r.issues, isEmpty, reason: '$id: ${r.issues.take(3)}');
          expect(r.metrics['utilization_pct'] as double, greaterThan(20.0), reason: id);
        }
      }, timeout: const Timeout(Duration(minutes: 2)));
    });
  }

  test('Beam Search is never worse than Block-Building (it starts from the greedy plan)', () {
    for (final id in ['BR1-001', 'BR4-002', 'MAX-E']) {
      final c = quick[id]!;
      final greedy = run(c, 'block_building').metrics['utilization_pct'] as double;
      final beam = planLoad(c, algorithm: 'beam_search', budget: const Duration(seconds: 2))
          .metrics['utilization_pct'] as double;
      expect(beam, greaterThanOrEqualTo(greedy - 1e-9), reason: id);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a time budget that has already passed still returns a valid plan', () {
    final c = quick['BR3-001']!;
    for (final algo in algorithms) {
      final deadline = Deadline(Duration.zero);
      final plan = algo.solve(c, deadline, 1);
      expect(validatePlan(c, plan), isEmpty, reason: algo.name);
    }
  });
}
