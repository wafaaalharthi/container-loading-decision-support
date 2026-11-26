/// Container loading decision-support engine.
///
/// Typical use inside the Flutter app:
///
/// ```dart
/// final result = planLoad(myCase, budget: const Duration(seconds: 5));
/// print(result.metrics['utilization_pct']);
/// ```
library;

import 'src/algorithms/registry.dart';
import 'src/metrics.dart';
import 'src/models.dart';
import 'src/validator.dart';

export 'src/algorithms/block_building.dart' show blockBuilding, beamSearch;
export 'src/algorithms/brkga.dart' show brkga;
export 'src/algorithms/extreme_points.dart' show singleStart, multiStart, baseOrder;
export 'src/algorithms/registry.dart';
export 'src/algorithms/wall_building.dart' show wallBuilding, compareManual;
export 'src/case_io.dart';
export 'src/metrics.dart';
export 'src/models.dart';
export 'src/validator.dart';

class PlanResult {
  final Plan plan;
  final List<String> issues;
  final Map<String, Object?> metrics;
  const PlanResult(this.plan, this.issues, this.metrics);
}

/// Validates the inputs, runs one algorithm within [budget], and re-checks the plan.
PlanResult planLoad(
  LoadingCase c, {
  String algorithm = 'beam_search',
  Duration budget = const Duration(seconds: 5),
  int seed = 1,
}) {
  validateCase(c);
  final info = algorithmByName(algorithm);
  final deadline = Deadline(budget);
  final plan = info.solve(c, deadline, seed);
  final elapsed = deadline.elapsed;
  final issues = validatePlan(c, plan);
  return PlanResult(plan, issues, evaluate(c, plan, elapsed, issues));
}
