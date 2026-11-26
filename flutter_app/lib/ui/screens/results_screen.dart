import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/plan_repository.dart';
import '../../data/shipment_repository.dart';
import '../../domain/containers.dart';
import '../../domain/export.dart';
import '../../domain/planning.dart';
import '../../domain/shipment.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/plan_view.dart';
import '../widgets/step_indicator.dart';
import 'comparison_screen.dart';
import 'export_screens.dart';
import 'planning_screen.dart';
import 'shell.dart' show shellTab;
import 'shipment_screen.dart' show confirmDialog;

/// Step 4: metrics, 3D view, steps and unplaced boxes of one plan.
class ResultsScreen extends StatefulWidget {
  final int planId;
  const ResultsScreen({super.key, required this.planId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _plans = PlanRepository();
  StoredPlan? _plan;
  Shipment? _ship;
  List<BoxGroup> _groups = const [];
  PlanBox? _selected;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Back to the home tab, asking first when the plan is not saved.
  Future<void> _finish() async {
    final p = _plan;
    if (p != null && !p.saved) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(ctx.tr('finishTitle')),
          content: Text(ctx.tr('finishQ')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: Text(ctx.tr('finishNoSave'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(ctx.tr('saveAndFinish'))),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == 'save') await _plans.markSaved(widget.planId);
    }
    if (!mounted) return;
    shellTab.value = 0;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _export(String kind) async {
    final p = _plan!, s = _ship!;
    final app = AppScope.read(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final byCode = {for (final g in _groups) g.code: g};
    final name = '${s.code}_${p.outcome.mode}_plan.$kind';
    final title = '${s.code} · ${app.t('mode_${p.outcome.mode}')}';
    setState(() => _exporting = true);
    try {
      if (kind == 'pdf') {
        // PDF opens in the app first; saving happens from the preview
        final bytes = await planPdf(s, p.outcome, byCode, await renderPlanPng(s.container, p.outcome.placed));
        nav.push(MaterialPageRoute(
          builder: (_) => PdfViewScreen(bytes: bytes, fileName: name, planId: p.id, title: title),
        ));
      } else {
        nav.push(MaterialPageRoute(
          builder: (_) => CsvViewScreen(
            bytes: planCsv(s, p.outcome, byCode, app.lang),
            rows: planCsvRows(p.outcome, byCode, app.lang),
            fileName: name,
            planId: p.id,
            title: title,
          ),
        ));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(app.t('exportFailed', {'e': e.toString()}))));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _exportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.cyan),
              title: Text(ctx.tr('exportPdf')),
              subtitle: Text(ctx.tr('exportPdfSub')),
              onTap: () {
                Navigator.pop(ctx);
                _export('pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined, color: AppColors.cyan),
              title: Text(ctx.tr('exportCsv')),
              subtitle: Text(ctx.tr('exportCsvSub')),
              onTap: () {
                Navigator.pop(ctx);
                _export('csv');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final p = await _plans.get(widget.planId);
    if (p == null) return;
    final repo = ShipmentRepository();
    final s = await repo.get(p.shipmentId);
    final g = await repo.groups(p.shipmentId);
    if (mounted) {
      setState(() {
        _plan = p;
        _ship = s;
        _groups = g;
      });
    }
  }

  Future<void> _save() async {
    await _plans.markSaved(widget.planId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('planSaved'))));
    _load();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, context.tr('deletePlanQ'), context.tr('delete'));
    if (!ok) return;
    await _plans.delete(widget.planId);
    if (mounted) Navigator.of(context).pop();
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final p = _plan, s = _ship;
    if (p == null || s == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final o = p.outcome;
    final c = s.container;
    final byCode = {for (final g in _groups) g.code: g};

    Widget metric(IconData icon, String label, String value, {String? sub, Color? color}) => Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 16, color: AppColors.cyan),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(value,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                if (sub != null) Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('${context.tr('resultsTitle')} · ${s.code}'),
        actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const StepIndicator(current: 4),
          Row(
            children: [
              Expanded(
                child: Text('${context.tr('mode_${o.mode}')} · ${context.tr(c.titleKey)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              _SavedChip(saved: p.saved),
            ],
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
              container: c,
              boxes: o.placed,
              height: 300,
              highlightId: _selected?.id,
              onTapBox: (b) => setState(() => _selected = b),
            ),
          ),
          const SizedBox(height: 6),
          Text(context.tr('viewHint'), style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          if (_selected != null) BoxInfoCard(box: _selected!, group: byCode[_selected!.group]),
          const SizedBox(height: 10),
          Row(children: [
            metric(Icons.pie_chart_outline, context.tr('utilization'), '${fmtNum(o.utilization, 1)}%'),
            const SizedBox(width: 8),
            metric(Icons.inventory_2_outlined, context.tr('loadedBoxes'),
                context.tr('loadedOf', {'a': o.placed.length, 'b': o.total})),
          ]),
          Row(children: [
            metric(Icons.scale_outlined, context.tr('loadedWeight'), '${fmtNum(o.weightKg)} ${context.tr('kg')}',
                sub: '/ ${fmtNum(c.payloadKg)} ${context.tr('kg')}'),
            const SizedBox(width: 8),
            metric(Icons.timer_outlined, context.tr('planTime'),
                o.timeMs < 1000 ? '${fmtNum(o.timeMs)} ms' : context.tr('secondsShort', {'s': fmtNum(o.timeMs / 1000, 1)})),
          ]),
          Row(children: [
            metric(Icons.swap_vert, context.tr('blocking'),
                o.blockingPct == null ? '—' : '${fmtNum(o.blockingPct!, 1)}%'),
            const SizedBox(width: 8),
            metric(o.valid ? Icons.verified_outlined : Icons.error_outline, context.tr('validator'),
                o.valid ? '✓' : '✕', color: o.valid ? AppColors.green : AppColors.danger),
          ]),
          Text(
            '${o.valid ? context.tr('validOk') : context.tr('validBad', {'n': o.issues})}\n${context.tr('blockingSub')}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          OutlineAppButton(
            label: context.tr('steps'),
            icon: Icons.format_list_numbered,
            onPressed: () => _push(PlanViewerScreen(container: c, boxes: o.placed, groups: byCode, steps: true)),
          ),
          const SizedBox(height: 8),
          OutlineAppButton(
            label: context.tr('view3d'),
            icon: Icons.view_in_ar,
            onPressed: () => _push(PlanViewerScreen(container: c, boxes: o.placed, groups: byCode, steps: false)),
          ),
          const SizedBox(height: 8),
          OutlineAppButton(
            label: '${context.tr('unplacedBoxes')} (${o.unplaced.length})',
            icon: Icons.report_gmailerrorred,
            onPressed: () => _push(UnplacedScreen(unplaced: o.unplaced, groups: byCode)),
          ),
          const SizedBox(height: 8),
          OutlineAppButton(
            label: context.tr('compareManual'),
            icon: Icons.compare_arrows,
            onPressed: () => _push(ComparisonScreen(planId: p.id)),
          ),
          const SizedBox(height: 8),
          OutlineAppButton(
            label: context.tr(_exporting ? 'exporting' : 'export'),
            icon: Icons.ios_share,
            onPressed: _exporting ? null : _exportSheet,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!p.saved) ...[
                Expanded(
                  child: GradientButton(label: context.tr('savePlan'), icon: Icons.save_outlined, onPressed: _save),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlineAppButton(label: context.tr('finish'), icon: Icons.check, onPressed: _finish),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.of(context)
                .pushReplacement(MaterialPageRoute(builder: (_) => PlanningScreen(shipmentId: s.id))),
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('anotherPlan')),
          ),
        ],
      ),
    );
  }
}

class _SavedChip extends StatelessWidget {
  final bool saved;
  const _SavedChip({required this.saved});

  @override
  Widget build(BuildContext context) {
    final color = saved ? AppColors.green : AppColors.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(context.tr(saved ? 'saved' : 'unsaved'),
          style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

/// Details of one placed box.
class BoxInfoCard extends StatelessWidget {
  final PlanBox box;
  final BoxGroup? group;
  final String? title;
  const BoxInfoCard({super.key, required this.box, this.group, this.title});

  @override
  Widget build(BuildContext context) {
    final g = group;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: AppColors.group(box.group), borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!, style: const TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.w700)),
                Text(box.id,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 15)),
                if (g != null)
                  Text(g.contents.isEmpty ? context.tr('kind_${g.kind}') : '${g.contents} · ${context.tr('kind_${g.kind}')}',
                      style: const TextStyle(fontSize: 13)),
                Text(context.tr('position', {'p': '\u2066${box.x}, ${box.y}, ${box.z}\u2069'}),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                Text(context.tr('sizeMm', {'s': '\u2066${box.dx}×${box.dy}×${box.dz}\u2069'}),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen 3D view; in steps mode a slider builds the load box by box.
class PlanViewerScreen extends StatefulWidget {
  final ContainerDims container;
  final List<PlanBox> boxes;
  final Map<String, BoxGroup> groups;
  final bool steps;
  const PlanViewerScreen({
    super.key,
    required this.container,
    required this.boxes,
    required this.groups,
    required this.steps,
  });

  @override
  State<PlanViewerScreen> createState() => _PlanViewerScreenState();
}

class _PlanViewerScreenState extends State<PlanViewerScreen> {
  late int _step = widget.boxes.isEmpty ? 0 : 1;
  PlanBox? _selected;

  @override
  Widget build(BuildContext context) {
    final n = widget.boxes.length;
    final current = widget.steps && _step > 0 ? widget.boxes[_step - 1] : _selected;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(widget.steps ? 'steps' : 'view3d'))),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => PlanView(
                container: widget.container,
                boxes: widget.boxes,
                height: box.maxHeight,
                visibleCount: widget.steps ? _step : null,
                highlightId: current?.id,
                onTapBox: widget.steps ? null : (b) => setState(() => _selected = b),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.tr('doorNote'), style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                if (current != null)
                  BoxInfoCard(
                    box: current,
                    group: widget.groups[current.group],
                    title: widget.steps ? context.tr('stepN', {'k': _step, 'n': n}) : null,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(context.tr('tapBox'), style: const TextStyle(color: AppColors.muted)),
                  ),
                if (widget.steps && n > 0) ...[
                  Slider(
                    value: _step.toDouble(),
                    min: 1,
                    max: n.toDouble(),
                    divisions: n > 1 ? n - 1 : null,
                    onChanged: (v) => setState(() => _step = v.round()),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlineAppButton(
                          label: context.tr('previous'),
                          onPressed: _step > 1 ? () => setState(() => _step--) : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GradientButton(
                          label: context.tr('next'),
                          onPressed: _step < n ? () => setState(() => _step++) : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Boxes left out of the plan, each with its reason.
class UnplacedScreen extends StatelessWidget {
  final Map<String, String> unplaced;
  final Map<String, BoxGroup> groups;
  const UnplacedScreen({super.key, required this.unplaced, required this.groups});

  @override
  Widget build(BuildContext context) {
    final items = unplaced.entries.toList();
    return Scaffold(
      appBar: AppBar(title: Text('${context.tr('unplacedBoxes')} (${items.length})')),
      body: items.isEmpty
          ? EmptyState(icon: Icons.check_circle_outline, text: context.tr('noUnplaced'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final e = items[i];
                final code = e.key.split('-').length >= 2 ? e.key.split('-')[1] : '';
                final g = groups[code];
                return AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(color: AppColors.group(code), borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                            if (g != null)
                              Text(g.contents.isEmpty ? context.tr('kind_${g.kind}') : g.contents,
                                  style: const TextStyle(fontSize: 12.5)),
                            Text(context.tr(e.value), style: const TextStyle(color: AppColors.warn, fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
