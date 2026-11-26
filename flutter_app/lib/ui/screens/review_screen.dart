import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/shipment_repository.dart';
import '../../domain/shipment.dart';
import '../../domain/validation.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/step_indicator.dart';
import 'all_boxes_screen.dart';
import 'planning_screen.dart';
import 'shipment_screen.dart' show StatusChip;

/// Marks the inputs as reviewed and opens step 3 (planning).
Future<void> continueToPlanning(BuildContext context, int shipmentId) async {
  final nav = Navigator.of(context);
  await ShipmentRepository().setStatus(shipmentId, 'reviewed');
  nav.push(MaterialPageRoute(builder: (_) => PlanningScreen(shipmentId: shipmentId)));
}

/// Checks on the inputs plus every box with its ID (search and group filter).
class ReviewScreen extends StatefulWidget {
  final int shipmentId;
  const ReviewScreen({super.key, required this.shipmentId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _repo = ShipmentRepository();
  Shipment? _ship;
  List<BoxGroup> _groups = const [];
  final _search = TextEditingController();
  String _query = '';
  String? _filter; // group code, null = all

  @override
  void initState() {
    super.initState();
    dataRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    dataRevision.removeListener(_load);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await _repo.get(widget.shipmentId);
    final g = await _repo.groups(widget.shipmentId);
    if (mounted) {
      setState(() {
        _ship = s;
        _groups = g;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _ship;
    if (s == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final c = s.container;
    final statuses = {for (final g in _groups) g.code: inputStatus(g, c)};
    final accepted = _groups.where((g) => statuses[g.code]!.accepted).toList();
    final rejected = _groups.where((g) => !statuses[g.code]!.accepted).toList();
    final ta = ShipmentTotals.of(accepted);
    final weightOver = ta.weightKg > c.payloadKg;
    final volumeOver = ta.volumeM3 > c.volumeM3;

    // Box list after search and filter
    final q = _query.trim().toLowerCase();
    final boxes = <(String, BoxGroup, bool)>[];
    for (final g in _groups) {
      if (_filter != null && g.code != _filter) continue;
      final ok = statuses[g.code]!.accepted;
      for (final id in g.boxIds(s.code)) {
        if (q.isEmpty || id.toLowerCase().contains(q) || g.contents.toLowerCase().contains(q)) {
          boxes.add((id, g, ok));
        }
      }
    }

    final header = <Widget>[
      const StepIndicator(current: 2),
      Row(
        children: [
          Expanded(
            child: Text('${s.code} · ${context.tr(c.titleKey)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          StatusChip(status: s.status),
        ],
      ),
      const SizedBox(height: 12),
      _check(
        context.tr('checkGroups'),
        rejected.isEmpty
            ? context.tr('groupsOk', {'n': _groups.length})
            : [
                context.tr('groupsBad', {'n': rejected.length}),
                for (final g in rejected)
                  context.tr('rejectedGroup', {'code': g.code, 'reason': context.tr(statuses[g.code]!.reasonKey!)}),
              ].join('\n'),
        rejected.isEmpty,
      ),
      _check(
        context.tr('checkWeight'),
        weightOver
            ? context.tr('weightOver', {'kg': fmtNum(ta.weightKg), 'p': fmtNum(c.payloadKg)})
            : context.tr('weightOk', {
                'kg': fmtNum(ta.weightKg),
                'p': fmtNum(c.payloadKg),
                'pct': fmtNum(ta.weightKg / c.payloadKg * 100, 1),
              }),
        !weightOver,
      ),
      _check(
        context.tr('checkVolume'),
        volumeOver
            ? context.tr('volumeOver', {'v': fmtNum(ta.volumeM3, 1), 'c': fmtNum(c.volumeM3, 1)})
            : context.tr('volumeOk', {
                'v': fmtNum(ta.volumeM3, 1),
                'c': fmtNum(c.volumeM3, 1),
                'pct': fmtNum(ta.volumeM3 / c.volumeM3 * 100, 1),
              }),
        !volumeOver,
      ),
      SectionTitle(context.tr('allBoxes')),
      TextField(
        controller: _search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: context.tr('searchBoxes'),
          isDense: true,
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _chip(context.tr('allGroups'), null),
            for (final g in _groups) _chip(g.code, g.code),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(context.tr('boxesCount', {'n': fmtNum(boxes.length)}),
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('reviewAll'))),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: header.length + boxes.length,
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          final (id, g, ok) = boxes[i - header.length];
          return BoxRow(id: id, group: g, accepted: ok);
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: accepted.isEmpty
              ? Text(context.tr('needGroups'), style: const TextStyle(color: AppColors.danger))
              : GradientButton(
                  label: context.tr('continuePlanning'),
                  icon: Icons.arrow_forward,
                  onPressed: () => continueToPlanning(context, s.id),
                ),
        ),
      ),
    );
  }

  Widget _chip(String label, String? code) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8, top: 4, bottom: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == code,
        onSelected: (_) => setState(() => _filter = code),
        selectedColor: AppColors.blue.withValues(alpha: 0.35),
      ),
    );
  }

  Widget _check(String title, String body, bool ok) {
    final color = ok ? AppColors.green : AppColors.warn;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
