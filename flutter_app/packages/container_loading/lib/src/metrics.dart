/// Plan quality measures.
library;

import 'models.dart';

class PriorityCount {
  final int inversions;
  final int pairs;
  const PriorityCount(this.inversions, this.pairs);
}

/// Counts pairs of placed boxes with different priorities, and how many of those
/// pairs are inverted: the box unloaded first (lower priority number) sits deeper
/// in the container (its centre is further from the door at x = length).
PriorityCount priorityInversions(List<Placement> placed) {
  final known = <Placement>[for (final p in placed) if (p.box.priority != null) p];
  int bad = 0;
  int pairs = 0;
  for (int i = 0; i < known.length; i++) {
    final a = known[i];
    final int ca = 2 * a.x + a.dx;
    for (int j = i + 1; j < known.length; j++) {
      final b = known[j];
      final int pa = a.box.priority!;
      final int pb = b.box.priority!;
      if (pa == pb) continue;
      pairs++;
      final int cb = 2 * b.x + b.dx;
      // earlier-unloaded box must not be deeper than the later-unloaded one
      if (pa < pb && ca < cb) bad++;
      if (pb < pa && cb < ca) bad++;
    }
  }
  return PriorityCount(bad, pairs);
}

/// Lexicographic plan quality: more loaded volume first, then fewer priority inversions.
class Score implements Comparable<Score> {
  final int volume;
  final int inversions;
  const Score(this.volume, this.inversions);

  static const Score worst = Score(-1, 1 << 30);

  factory Score.of(Plan plan) {
    final inv = priorityInversions(plan.placed).inversions;
    return Score(plan.volume, inv);
  }

  @override
  int compareTo(Score other) {
    if (volume != other.volume) return volume.compareTo(other.volume);
    return other.inversions.compareTo(inversions);
  }

  bool betterThan(Score other) => compareTo(other) > 0;
}

Map<String, Object?> evaluate(LoadingCase c, Plan plan, Duration runtime, List<String> issues) {
  final int volume = plan.volume;
  final pc = priorityInversions(plan.placed);
  double weight = 0.0;
  for (final p in plan.placed) {
    weight += p.box.weight;
  }
  final double upperBound = c.totalBoxVolume < c.container.volume
      ? 100.0 * c.totalBoxVolume / c.container.volume
      : 100.0;
  return {
    'valid': issues.isEmpty,
    'issues': issues.length,
    'first_issue': issues.isEmpty ? '' : issues.first,
    'boxes_total': c.boxes.length,
    'boxes_placed': plan.placed.length,
    'boxes_unplaced': c.boxes.length - plan.placed.length,
    'utilization_pct': 100.0 * volume / c.container.volume,
    'upper_bound_pct': upperBound,
    'priority_inversions': pc.inversions,
    'priority_pairs': pc.pairs,
    'priority_inversion_pct': pc.pairs == 0 ? null : 100.0 * pc.inversions / pc.pairs,
    'loaded_weight_kg': weight,
    'runtime_s': runtime.inMicroseconds / 1e6,
    'time_limit_reached': plan.timedOut,
  };
}
