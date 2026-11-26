library;

import '../models.dart';
import 'block_building.dart';
import 'brkga.dart';
import 'extreme_points.dart';
import 'wall_building.dart';

typedef Solver = Plan Function(LoadingCase c, Deadline deadline, int seed);

class AlgorithmInfo {
  final String name;
  final String label;
  final Solver solve;

  /// Deterministic algorithms give the same plan for every seed, so they run once.
  final bool deterministic;

  const AlgorithmInfo(this.name, this.label, this.solve, this.deterministic);
}

const List<AlgorithmInfo> algorithms = [
  AlgorithmInfo('single_start', 'Single-Start Extreme Points', singleStart, true),
  AlgorithmInfo('multi_start', 'Multi-Start Extreme Points', multiStart, false),
  AlgorithmInfo('brkga', 'Biased Random-Key Genetic Algorithm', brkga, false),
  AlgorithmInfo('block_building', 'Block-Building', blockBuilding, true),
  AlgorithmInfo('beam_search', 'Beam Search (block based)', beamSearch, true),
  AlgorithmInfo('wall_building', 'Wall-Building (manual-style simulation)', wallBuilding, true),
];

AlgorithmInfo algorithmByName(String name) {
  for (final a in algorithms) {
    if (a.name == name) return a;
  }
  throw ArgumentError('Unknown algorithm "$name". Use one of: ${algorithms.map((a) => a.name).join(', ')}');
}
