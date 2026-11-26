import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/shipment_repository.dart';
import '../../domain/containers.dart';
import '../../domain/shipment.dart';
import '../../domain/validation.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/container_selector.dart';
import '../widgets/step_indicator.dart';
import 'group_editor_screen.dart';
import 'import_screen.dart';
import 'review_screen.dart';

/// One shipment: container, totals, box groups and the actions on them.
class ShipmentScreen extends StatefulWidget {
  final int shipmentId;
  const ShipmentScreen({super.key, required this.shipmentId});

  @override
  State<ShipmentScreen> createState() => _ShipmentScreenState();
}

class _ShipmentScreenState extends State<ShipmentScreen> {
  final _repo = ShipmentRepository();
  Shipment? _ship;
  List<BoxGroup> _groups = const [];

  @override
  void initState() {
    super.initState();
    dataRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    dataRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final s = await _repo.get(widget.shipmentId);
    final g = await _repo.groups(widget.shipmentId);
    if (!mounted) return;
    setState(() {
      _ship = s;
      _groups = g;
    });
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _changeContainer() async {
    final s = _ship!;
    final picked = await Navigator.of(context).push<ContainerDims>(
      MaterialPageRoute(builder: (_) => _ContainerPickerPage(initial: s.container)),
    );
    if (picked != null) await _repo.updateContainer(s.id, picked);
  }

  Future<void> _deleteShipment() async {
    final ok = await confirmDialog(context, context.tr('deleteShipmentQ'), context.tr('delete'));
    if (!ok || !mounted) return;
    await _repo.delete(widget.shipmentId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = _ship;
    if (s == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final t = ShipmentTotals.of(_groups);
    final c = s.container;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.code, textDirection: TextDirection.ltr),
        actions: [
          IconButton(
            tooltip: context.tr('deleteShipment'),
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteShipment,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const StepIndicator(current: 1),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(s.name.isEmpty ? s.code : s.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    StatusChip(status: s.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('totalsLine', {
                    'g': t.groups,
                    'b': fmtNum(t.boxes),
                    'kg': fmtNum(t.weightKg),
                    'v': fmtNum(t.volumeM3, 1),
                  }),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          AppCard(
            onTap: _changeContainer,
            child: Row(
              children: [
                const Icon(Icons.local_shipping_outlined, color: AppColors.cyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr(c.titleKey), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        context.tr('insideDims', {
                          'l': mmToM(c.length),
                          'w': mmToM(c.width),
                          'h': mmToM(c.height),
                          'v': fmtNum(c.volumeM3, 1),
                        }),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(context.tr('changeContainer'), style: const TextStyle(color: AppColors.cyan, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlineAppButton(
                  label: context.tr('addGroup'),
                  icon: Icons.add,
                  onPressed: () => _push(GroupEditorScreen(shipmentId: s.id, existing: _groups)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlineAppButton(
                  label: context.tr('importFile'),
                  icon: Icons.upload_file,
                  onPressed: () => _push(ImportScreen(shipmentId: s.id, existing: _groups)),
                ),
              ),
            ],
          ),
          SectionTitle('${context.tr('groups')} (${_groups.length})'),
          if (_groups.isEmpty)
            EmptyState(icon: Icons.inventory_2_outlined, text: context.tr('noGroups'))
          else
            for (final g in _groups)
              GroupTile(
                group: g,
                status: inputStatus(g, c),
                onTap: () => _push(GroupEditorScreen(shipmentId: s.id, existing: _groups, group: g)),
              ),
          const SizedBox(height: 8),
          if (_groups.isNotEmpty) ...[
            OutlineAppButton(
              label: '${context.tr('reviewAll')} (${fmtNum(t.boxes)})',
              icon: Icons.fact_check_outlined,
              onPressed: () => _push(ReviewScreen(shipmentId: s.id)),
            ),
            const SizedBox(height: 10),
            GradientButton(
              label: context.tr('continuePlanning'),
              icon: Icons.arrow_forward,
              onPressed: _groups.any((g) => inputStatus(g, c).accepted)
                  ? () => continueToPlanning(context, s.id)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContainerPickerPage extends StatefulWidget {
  final ContainerDims initial;
  const _ContainerPickerPage({required this.initial});

  @override
  State<_ContainerPickerPage> createState() => _ContainerPickerPageState();
}

class _ContainerPickerPageState extends State<_ContainerPickerPage> {
  late ContainerDims? _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('chooseContainer'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ContainerSelector(initial: widget.initial, onChanged: (c) => setState(() => _picked = c)),
          const SizedBox(height: 12),
          GradientButton(
            label: context.tr('save'),
            icon: Icons.check,
            onPressed: _picked == null ? null : () => Navigator.of(context).pop(_picked),
          ),
        ],
      ),
    );
  }
}

/// Draft / reviewed badge.
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final ok = status == 'reviewed';
    final color = ok ? AppColors.green : AppColors.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.edit_note, size: 14, color: color),
          const SizedBox(width: 4),
          Text(context.tr('status_$status'), style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// One box group row with its accepted / rejected state.
class GroupTile extends StatelessWidget {
  final BoxGroup group;
  final InputStatus status;
  final VoidCallback? onTap;
  const GroupTile({super.key, required this.group, required this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = group;
    final flags = <String>[
      if (g.orientation == 'upright') context.tr('orient_upright'),
      if (g.fragile) context.tr('fragile'),
      if (g.floorOnly) context.tr('floorOnly'),
      if (!g.stackable && !g.fragile) '✕ ${context.tr('stackable')}',
    ];
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.group(g.code), borderRadius: BorderRadius.circular(9)),
            child: Text(g.code,
                style: const TextStyle(color: Color(0xFF0A1024), fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.contents.isEmpty ? context.tr('kind_${g.kind}') : g.contents,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('groupLine', {
                    'kind': g.contents.isEmpty ? (g.custom.isEmpty ? '' : g.custom) : context.tr('kind_${g.kind}'),
                    'dims': dimsCm(g.lengthMm, g.widthMm, g.heightMm),
                    'kg': fmtKg(g.weightKg),
                    'q': g.quantity,
                    'p': g.priority,
                  }).replaceFirst(RegExp(r'^ · '), ''),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (flags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(flags.join(' · '), style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                  ),
                if (!status.accepted)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${context.tr('rejected')}: ${context.tr(status.reasonKey!)}',
                        style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          Icon(status.accepted ? Icons.check_circle : Icons.error_outline,
              size: 20, color: status.accepted ? AppColors.green : AppColors.danger),
        ],
      ),
    );
  }
}

/// Yes / cancel dialog. Returns true when confirmed.
Future<bool> confirmDialog(BuildContext context, String message, String confirmLabel) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  return ok ?? false;
}
