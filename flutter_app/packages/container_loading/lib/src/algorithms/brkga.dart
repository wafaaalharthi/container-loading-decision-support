/// Biased Random-Key Genetic Algorithm (Gonçalves & Resende, 2011 style).
///
/// Each chromosome holds one random key per box. Decoding sorts the boxes by
/// (unloading-priority group, key) and builds the plan with the extreme-point
/// construction. Elite chromosomes are copied, the rest are produced by biased
/// crossover (an elite parent passes each gene with probability 0.7) plus a few
/// fresh random chromosomes (mutants). Runs until the time budget is used.
library;

import 'dart:math';

import '../metrics.dart';
import '../models.dart';
import 'extreme_points.dart';

const int _population = 24;
const int _elite = 5;
const int _mutants = 4;
const double _eliteBias = 0.7;

Plan brkga(LoadingCase c, Deadline deadline, int seed) {
  final rng = Random(seed);
  final base = baseOrder(c.boxes);
  final int n = base.length;
  if (n < 2) return constructExtremePoints(c, base, deadline);

  List<double> randomKeys() => [for (int i = 0; i < n; i++) rng.nextDouble()];

  List<BoxItem> decode(List<double> keys) {
    final idx = [for (int i = 0; i < n; i++) i];
    idx.sort((a, b) {
      final pa = base[a].priorityKey;
      final pb = base[b].priorityKey;
      if (pa != pb) return pb.compareTo(pa);
      final int k = keys[a].compareTo(keys[b]);
      return k != 0 ? k : a.compareTo(b);
    });
    return [for (final i in idx) base[i]];
  }

  // First chromosome reproduces the default order, so BRKGA starts from Single-Start's plan.
  var population = <List<double>>[
    [for (int i = 0; i < n; i++) i / n],
    for (int i = 1; i < _population; i++) randomKeys(),
  ];

  Plan best = Plan.empty;
  Score bestScore = Score.worst;
  bool cut = false;
  final known = Map<List<double>, Score>.identity();

  while (!deadline.passed) {
    final scored = <(Score, List<double>)>[];
    for (final keys in population) {
      final cached = known[keys];
      if (cached != null) {
        scored.add((cached, keys)); // elite copied unchanged: no need to decode again
        continue;
      }
      final plan = constructExtremePoints(c, decode(keys), deadline);
      final s = Score.of(plan);
      if (s.betterThan(bestScore)) {
        best = plan;
        bestScore = s;
      }
      if (plan.timedOut) {
        cut = true;
        break;
      }
      known[keys] = s;
      scored.add((s, keys));
    }
    if (cut || deadline.passed) break;
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    final elite = [for (int i = 0; i < _elite && i < scored.length; i++) scored[i].$2];
    final others = [for (int i = _elite; i < scored.length; i++) scored[i].$2];
    final next = <List<double>>[...elite];
    for (int i = 0; i < _mutants; i++) {
      next.add(randomKeys());
    }
    while (next.length < _population) {
      final a = elite[rng.nextInt(elite.length)];
      final b = others.isEmpty ? randomKeys() : others[rng.nextInt(others.length)];
      next.add([for (int g = 0; g < n; g++) rng.nextDouble() < _eliteBias ? a[g] : b[g]]);
    }
    known.removeWhere((k, _) => !elite.any((e) => identical(e, k)));
    population = next;
  }
  return cut ? best.withTimedOut() : best;
}
