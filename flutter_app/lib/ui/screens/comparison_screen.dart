import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/plan_repository.dart';
import '../../data/records_repository.dart';
import '../../data/shipment_repository.dart';
import '../../domain/planning.dart';
import '../../domain/shipment.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/plan_view.dart';

/// System plan vs. the manual-style Wall-Building simulation on the same shipment.
class ComparisonScreen extends StatefulWidget {
  final int planId;
  const ComparisonScreen({super.key, required this.planId});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  StoredPlan? _plan;
  Shipment? _ship;
  PlanOutcome? _manual;
  String? _error;
  bool _showManual = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final p = (await PlanRepository().get(widget.planId))!;
      final repo = ShipmentRepository();
      final s = (await repo.get(p.shipmentId))!;
      final g = await repo.groups(p.shipmentId);
      final m = await runPlan(s, g, 'manual');
      if (mounted) {
        setState(() {
          _plan = p;
          _ship = s;
          _manual = m;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _saveReport() async {
    final p = _plan!, m = _manual!, s = _ship!;
    final o = p.outcome;
    await ReportRepository().add(
      s.userId,
      p.id,
      'comparison',
      '${s.code} · ${context.tr('mode_${o.mode}')} / ${context.tr('manualSim')}',
      data: {
        'system_util': o.utilization,
        'manual_util': m.utilization,
        'system_loaded': o.placed.length,
        'manual_loaded': m.placed.length,
        'total': o.total,
        'system_blocking': o.blockingPct,
        'manual_blocking': m.blockingPct,
      },
    );
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('reportSaved'))));
  }

  @override
  Widget build(BuildContext context) {
    final p = _plan, m = _manual, s = _ship;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('compareTitle'))),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
          : (p == null || m == null || s == null)
              ? const Center(child: CircularProgressIndicator())
              : _body(context, p.outcome, m, s),
    );
  }

  Widget _body(BuildContext context, PlanOutcome o, PlanOutcome m, Shipment s) {
    String pct(double? v) => v == null ? '—' : '${fmtNum(v, 1)}%';
    String diff(double a, double b, {String unit = ''}) {
      final d = a - b;
      return '${d >= 0 ? '+' : '−'}${fmtNum(d.abs(), unit == '%' ? 1 : 0)}$unit';
    }

    final rows = <(String, String, String, String)>[
      (context.tr('utilization'), pct(o.utilization), pct(m.utilization), diff(o.utilization, m.utilization, unit: '%')),
      (
        context.tr('loadedBoxes'),
        '${o.placed.length}',
        '${m.placed.length}',
        diff(o.placed.length.toDouble(), m.placed.length.toDouble())
      ),
      (
        context.tr('unplacedBoxes'),
        '${o.unplaced.length}',
        '${m.unplaced.length}',
        diff(o.unplaced.length.toDouble(), m.unplaced.length.toDouble())
      ),
      (context.tr('loadedWeight'), fmtNum(o.weightKg), fmtNum(m.weightKg), diff(o.weightKg, m.weightKg)),
      (
        context.tr('blocking'),
        pct(o.blockingPct),
        pct(m.blockingPct),
        (o.blockingPct == null || m.blockingPct == null) ? '—' : diff(o.blockingPct!, m.blockingPct!, unit: '%')
      ),
      (context.tr('validator'), o.valid ? '✓' : '✕', m.valid ? '✓' : '✕', ''),
    ];

    const head = TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.muted);
    const cell = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('manualSim'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 4),
              Text(context.tr('manualSimSub'), style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.5)),
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Table(
            columnWidths: const {0: FlexColumnWidth(1.6), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(children: [
                const SizedBox(),
                Text(context.tr('systemPlan'), style: head),
                Text(context.tr('manualShort'), style: head),
                Text(context.tr('difference'), style: head),
              ]),
              for (final r in rows)
                TableRow(
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 0.6))),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text(r.$1, style: const TextStyle(fontSize: 12.5)),
                    ),
                    Text(r.$2, textDirection: TextDirection.ltr, style: cell.copyWith(color: AppColors.cyan)),
                    Text(r.$3, textDirection: TextDirection.ltr, style: cell),
                    Text(r.$4, textDirection: TextDirection.ltr, style: cell.copyWith(color: AppColors.muted)),
                  ],
                ),
            ],
          ),
        ),
        Text(
          context.tr('compareNote', {'mode': context.tr('mode_${o.mode}')}),
          style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text(context.tr('systemPlan'))),
            ButtonSegment(value: true, label: Text(context.tr('manualShort'))),
          ],
          selected: {_showManual},
          onSelectionChanged: (v) => setState(() => _showManual = v.first),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: PlanView(
            key: ValueKey(_showManual),
            container: s.container,
            boxes: _showManual ? m.placed : o.placed,
            height: 280,
          ),
        ),
        const SizedBox(height: 14),
        GradientButton(
          label: context.tr(_saved ? 'reportSaved' : 'saveComparison'),
          icon: Icons.description_outlined,
          onPressed: _saved ? null : _saveReport,
        ),
      ],
    );
  }
}
