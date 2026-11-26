/// Compares the loading algorithms on the project cases.
///
///   dart run bin/benchmark.dart --quick        (about 200 cases, 2 s per run)
///   dart run bin/benchmark.dart --full         (all cases, 5 s per run, several hours)
///
/// Options:
///   --budget <seconds>     time budget per run
///   --seeds <n>            seeds for the randomised algorithms (deterministic ones run once)
///   --algorithms a,b,c     subset of: single_start, multi_start, brkga, block_building, beam_search
///   --cases <file>         case file (default data/cases_quick.json or data/cases_full.json)
///   --groups BR1,WT,REAL   only cases whose group starts with one of these prefixes
///   --workers <n>          parallel runs (default: processor count - 1)
///   --out <folder>         output folder (default results)
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:container_loading/container_loading.dart';

class Job {
  final LoadingCase c;
  final String algorithm;
  final int seed;
  final int budgetMs;
  final bool savePlan;
  const Job(this.c, this.algorithm, this.seed, this.budgetMs, this.savePlan);
}

Map<String, Object?> runJob(Job job) {
  final c = job.c;
  final row = <String, Object?>{
    'case_id': c.id,
    'source': c.source,
    'group': c.group,
    'algorithm': job.algorithm,
    'seed': job.seed,
    'budget_s': job.budgetMs / 1000.0,
  };
  try {
    validateCase(c);
    final info = algorithmByName(job.algorithm);
    final deadline = Deadline(Duration(milliseconds: job.budgetMs));
    final plan = info.solve(c, deadline, job.seed);
    final elapsed = deadline.elapsed;
    final issues = validatePlan(c, plan);
    final metrics = evaluate(c, plan, elapsed, issues);
    row.addAll(metrics);
    row['reference_ratio_pct'] = c.referenceRatio == null ? null : c.referenceRatio! * 100.0;
    row['reference_kind'] = c.referenceKind ?? '';
    if (job.savePlan) row['_plan'] = planToJson(c, job.algorithm, plan, metrics);
  } catch (e) {
    row['valid'] = false;
    row['error'] = e.toString();
  }
  return row;
}

// Top-level on purpose: the closure sent to the isolate captures only [job].
Future<Map<String, Object?>> runInIsolate(Job job) => Isolate.run(() => runJob(job));

const columns = [
  'case_id', 'source', 'group', 'algorithm', 'seed', 'budget_s', 'valid', 'issues', 'first_issue', //
  'boxes_total', 'boxes_placed', 'boxes_unplaced', 'utilization_pct', 'upper_bound_pct', //
  'priority_inversions', 'priority_pairs', 'priority_inversion_pct', 'loaded_weight_kg', //
  'runtime_s', 'time_limit_reached', 'reference_ratio_pct', 'reference_kind', 'error',
];

String csvCell(Object? v) {
  if (v == null) return '';
  if (v is double) return v.toStringAsFixed(4);
  final s = v.toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n')) return '"${s.replaceAll('"', '""')}"';
  return s;
}

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final bool full = opts.containsKey('full');
  final String casesPath = opts['cases'] ?? (full ? 'data/cases_full.json' : 'data/cases_quick.json');
  final double budgetS = double.parse(opts['budget'] ?? (full ? '5' : '2'));
  final int seeds = int.parse(opts['seeds'] ?? (full ? '5' : '3'));
  final int workers = int.parse(opts['workers'] ?? '${max(1, Platform.numberOfProcessors - 1)}');
  final String outDir = opts['out'] ?? 'results';
  final algoNames = (opts['algorithms'] ?? algorithms.map((a) => a.name).join(','))
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  for (final n in algoNames) {
    algorithmByName(n); // fails early on a typo
  }
  final groupPrefixes = opts['groups']?.split(',').map((s) => s.trim()).toList();

  var cases = parseCases(await File(casesPath).readAsString());
  if (groupPrefixes != null) {
    cases = [
      for (final c in cases)
        if (groupPrefixes.any((g) => c.group.startsWith(g))) c
    ];
  }

  final int budgetMs = (budgetS * 1000).round();
  final jobs = <Job>[];
  for (final c in cases) {
    final bool save = c.group == 'REAL' || c.group == 'SCN';
    for (final name in algoNames) {
      final info = algorithmByName(name);
      final int runs = info.deterministic ? 1 : seeds;
      for (int s = 1; s <= runs; s++) {
        jobs.add(Job(c, name, s, budgetMs, save && s == 1));
      }
    }
  }

  final double estimateMin = jobs.length * budgetS / workers / 60.0;
  stdout.writeln('Cases: ${cases.length}  Algorithms: ${algoNames.join(', ')}');
  stdout.writeln('Runs: ${jobs.length}  Budget: ${budgetS}s  Workers: $workers  '
      'Upper time estimate: ${estimateMin.toStringAsFixed(0)} min');

  await Directory('$outDir/plans').create(recursive: true);
  final runsFile = File('$outDir/runs.csv').openWrite();
  runsFile.writeln(columns.join(','));

  final results = <Map<String, Object?>>[];
  int nextJob = 0;
  int done = 0;
  final watch = Stopwatch()..start();

  Future<void> worker() async {
    while (true) {
      final int i = nextJob++;
      if (i >= jobs.length) return;
      final row = await runInIsolate(jobs[i]);
      final plan = row.remove('_plan');
      if (plan != null) {
        final name = '${row['case_id']}__${row['algorithm']}.json'.replaceAll(RegExp(r'[^A-Za-z0-9_.\-]'), '_');
        await File('$outDir/plans/$name').writeAsString(_toJson(plan));
      }
      results.add(row);
      runsFile.writeln([for (final col in columns) csvCell(row[col])].join(','));
      done++;
      final util = row['utilization_pct'];
      final status = row['error'] != null ? 'ERROR ${row['error']}' : (row['valid'] == true ? 'OK' : 'INVALID ${row['first_issue']}');
      stdout.writeln('[${done.toString().padLeft(5)}/${jobs.length}] ${row['case_id']} ${row['algorithm']} '
          'seed=${row['seed']} ${util is double ? '${util.toStringAsFixed(2)}%' : '-'} $status');
    }
  }

  await Future.wait([for (int w = 0; w < workers; w++) worker()]);
  await runsFile.flush();
  await runsFile.close();

  _writeSummaries(results, algoNames, outDir);
  stdout.writeln('\nFinished in ${(watch.elapsed.inSeconds / 60).toStringAsFixed(1)} min. Results in $outDir/');
}

void _writeSummaries(List<Map<String, Object?>> rows, List<String> algoNames, String outDir) {
  // Median over seeds for each (case, algorithm).
  final byCaseAlgo = <String, Map<String, List<Map<String, Object?>>>>{};
  final groupOf = <String, String>{};
  for (final r in rows) {
    final cid = r['case_id'] as String;
    groupOf[cid] = r['group'] as String;
    byCaseAlgo.putIfAbsent(cid, () => {}).putIfAbsent(r['algorithm'] as String, () => []).add(r);
  }

  double? median(List<double> v) {
    if (v.isEmpty) return null;
    final s = List<double>.of(v)..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  // case -> algo -> (util, inversion%, runtime, invalid count)
  final caseStats = <String, Map<String, List<double?>>>{};
  for (final e in byCaseAlgo.entries) {
    for (final a in e.value.entries) {
      final valid = a.value.where((r) => r['valid'] == true).toList();
      final invalid = a.value.length - valid.length;
      final util = median([for (final r in valid) (r['utilization_pct'] as num).toDouble()]);
      final inv = median([
        for (final r in valid)
          if (r['priority_inversion_pct'] != null) (r['priority_inversion_pct'] as num).toDouble()
      ]);
      final rt = median([for (final r in valid) (r['runtime_s'] as num).toDouble()]);
      caseStats.putIfAbsent(e.key, () => {})[a.key] = [util, inv, rt, invalid.toDouble()];
    }
  }

  // Rank algorithms inside each case (1 = best utilisation, ties share the average rank).
  final ranks = <String, Map<String, double>>{};
  for (final e in caseStats.entries) {
    final entries = [
      for (final a in algoNames)
        if (e.value[a] != null) MapEntry(a, e.value[a]![0] ?? -1.0)
    ]..sort((x, y) => y.value.compareTo(x.value));
    final r = <String, double>{};
    int i = 0;
    while (i < entries.length) {
      int j = i;
      while (j + 1 < entries.length && (entries[j + 1].value - entries[i].value).abs() < 1e-9) {
        j++;
      }
      final avg = (i + j) / 2 + 1;
      for (int k = i; k <= j; k++) {
        r[entries[k].key] = avg;
      }
      i = j + 1;
    }
    ranks[e.key] = r;
  }

  final groups = (groupOf.values.toSet().toList()..sort());
  final out = StringBuffer('group,algorithm,cases,mean_utilization_pct,mean_priority_inversion_pct,'
      'median_runtime_s,invalid_runs,mean_rank\n');
  final overall = <String, List<double>>{};
  for (final g in [...groups, 'ALL']) {
    for (final a in algoNames) {
      final utils = <double>[], invs = <double>[], rts = <double>[], rk = <double>[];
      double invalid = 0;
      for (final e in caseStats.entries) {
        if (g != 'ALL' && groupOf[e.key] != g) continue;
        final s = e.value[a];
        if (s == null) continue;
        if (s[0] != null) utils.add(s[0]!);
        if (s[1] != null) invs.add(s[1]!);
        if (s[2] != null) rts.add(s[2]!);
        invalid += s[3]!;
        final rr = ranks[e.key]![a];
        if (rr != null) rk.add(rr);
      }
      double? mean(List<double> v) => v.isEmpty ? null : v.reduce((x, y) => x + y) / v.length;
      out.writeln([
        g, a, utils.length, csvCell(mean(utils)), csvCell(mean(invs)), csvCell(median(rts)),
        invalid.toInt(), csvCell(mean(rk)),
      ].join(','));
      if (g == 'ALL') overall[a] = [mean(utils) ?? 0.0, mean(rk) ?? 0.0, median(rts) ?? 0.0, invalid];
    }
  }
  File('$outDir/summary_by_group.csv').writeAsStringSync(out.toString());

  final ordered = overall.entries.toList()..sort((x, y) => x.value[1].compareTo(y.value[1]));
  stdout.writeln('\nOverall (mean rank across cases, 1 = best):');
  for (final e in ordered) {
    stdout.writeln('  ${e.key.padRight(16)} mean rank ${e.value[1].toStringAsFixed(2)}  '
        'utilization ${e.value[0].toStringAsFixed(2)}%  median time ${e.value[2].toStringAsFixed(3)}s  '
        'invalid runs ${e.value[3].toInt()}');
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final m = <String, String>{};
  for (int i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final key = a.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      m[key] = args[++i];
    } else {
      m[key] = 'true';
    }
  }
  return m;
}

String _toJson(Object? v) => const JsonEncoder.withIndent('  ').convert(v);
