import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/plan_repository.dart';
import '../../data/records_repository.dart';
import '../../data/shipment_repository.dart';
import '../../domain/shipment.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'comparison_screen.dart';
import 'results_screen.dart';
import 'shipment_screen.dart';

/// Mixin: reload when data changes.
mixin _Reload<T extends StatefulWidget> on State<T> {
  Future<void> load();

  @override
  void initState() {
    super.initState();
    dataRevision.addListener(load);
    load();
  }

  @override
  void dispose() {
    dataRevision.removeListener(load);
    super.dispose();
  }
}

/// Operations records: saved plans / unsaved plans and draft shipments.
class OpsRecordsScreen extends StatefulWidget {
  const OpsRecordsScreen({super.key});

  @override
  State<OpsRecordsScreen> createState() => _OpsRecordsScreenState();
}

class _OpsRecordsScreenState extends State<OpsRecordsScreen> with _Reload {
  List<PlanSummary> _plans = const [];
  List<ShipmentSummary> _drafts = const [];
  bool _ready = false;

  @override
  Future<void> load() async {
    final user = AppScope.read(context).user;
    if (user == null) return;
    final plans = await PlanRepository().listForUser(user.id);
    final ships = await ShipmentRepository().listForUser(user.id);
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _drafts = ships.where((s) => s.shipment.status == 'draft').toList();
      _ready = true;
    });
  }

  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Widget _planTile(PlanSummary p) => AppCard(
        onTap: () => _open(ResultsScreen(planId: p.id)),
        child: Row(
          children: [
            Icon(p.mode == 'optimized' ? Icons.auto_awesome : Icons.bolt, color: AppColors.cyan),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.shipmentCode} · ${context.tr('mode_${p.mode}')}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${fmtNum(p.utilization, 1)}% · ${context.tr('loadedOf', {'a': p.loaded, 'b': p.total})} · ${fmtDateTime(p.createdAt)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final saved = _plans.where((p) => p.saved).toList();
    final unsaved = _plans.where((p) => !p.saved).toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('opsRecords')),
          bottom: TabBar(
            indicatorColor: AppColors.cyan,
            labelColor: AppColors.cyan,
            unselectedLabelColor: AppColors.muted,
            tabs: [
              Tab(text: '${context.tr('savedOps')} (${saved.length})'),
              Tab(text: '${context.tr('unsavedOps')} (${unsaved.length + _drafts.length})'),
            ],
          ),
        ),
        body: !_ready
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  saved.isEmpty
                      ? EmptyState(icon: Icons.bookmark_border, text: context.tr('noSavedOps'))
                      : ListView(padding: const EdgeInsets.all(16), children: [for (final p in saved) _planTile(p)]),
                  (unsaved.isEmpty && _drafts.isEmpty)
                      ? EmptyState(icon: Icons.edit_note, text: context.tr('noUnsavedOps'))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (unsaved.isNotEmpty) SectionTitle(context.tr('unsavedPlans')),
                            for (final p in unsaved) _planTile(p),
                            if (_drafts.isNotEmpty) SectionTitle(context.tr('draftShipments')),
                            for (final d in _drafts)
                              AppCard(
                                onTap: () => _open(ShipmentScreen(shipmentId: d.shipment.id)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_note, color: AppColors.warn),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(d.shipment.code, style: const TextStyle(fontWeight: FontWeight.w700)),
                                          Text(
                                            '${context.tr('boxesCount', {'n': fmtNum(d.boxes)})} · ${fmtDateTime(d.shipment.updatedAt)}',
                                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ],
              ),
      ),
    );
  }
}

/// Reports records: exported files and saved comparisons.
class ReportsRecordsScreen extends StatefulWidget {
  const ReportsRecordsScreen({super.key});

  @override
  State<ReportsRecordsScreen> createState() => _ReportsRecordsScreenState();
}

class _ReportsRecordsScreenState extends State<ReportsRecordsScreen> with _Reload {
  List<ReportRecord>? _list;

  @override
  Future<void> load() async {
    final user = AppScope.read(context).user;
    if (user == null) return;
    final l = await ReportRepository().listForUser(user.id);
    if (mounted) setState(() => _list = l);
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('reportRecords'))),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? EmptyState(icon: Icons.description_outlined, text: context.tr('noReports'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final r in list)
                      AppCard(
                        onTap: r.planId == null
                            ? null
                            : () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      r.kind == 'comparison' ? ComparisonScreen(planId: r.planId!) : ResultsScreen(planId: r.planId!),
                                )),
                        child: Row(
                          children: [
                            Icon(
                              r.kind == 'pdf'
                                  ? Icons.picture_as_pdf_outlined
                                  : r.kind == 'csv'
                                      ? Icons.table_chart_outlined
                                      : Icons.compare_arrows,
                              color: AppColors.cyan,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    '${context.tr('report_${r.kind}')}${r.fileName == null ? '' : ' · ${r.fileName}'} · ${fmtDateTime(r.createdAt)}',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                  ),
                                  if (r.kind == 'comparison' && r.data.isNotEmpty)
                                    Text(
                                      context.tr('compareLine', {
                                        's': fmtNum((r.data['system_util'] as num).toDouble(), 1),
                                        'm': fmtNum((r.data['manual_util'] as num).toDouble(), 1),
                                      }),
                                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                final ok =
                                    await confirmDialog(context, context.tr('deleteReportQ'), context.tr('delete'));
                                if (ok) await ReportRepository().delete(r.id);
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// In-app notifications; opening the screen marks them as read.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with _Reload {
  List<AppNotification>? _list;
  bool _marked = false;

  @override
  Future<void> load() async {
    final user = AppScope.read(context).user;
    if (user == null) return;
    final repo = NotificationRepository();
    final l = await repo.listForUser(user.id);
    if (!mounted) return;
    setState(() => _list = l);
    if (!_marked) {
      _marked = true;
      await repo.markAllRead(user.id);
    }
  }

  Map<String, Object> _args(AppNotification n) =>
      n.args.map((k, v) => MapEntry(k, k == 'mode' ? context.tr('mode_$v') : v));

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('notifications')),
        actions: [
          if (list != null && list.isNotEmpty)
            IconButton(
              tooltip: context.tr('clearAll'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final user = AppScope.read(context).user;
                if (user != null) await NotificationRepository().clear(user.id);
              },
            ),
        ],
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? EmptyState(icon: Icons.notifications_none, text: context.tr('noNotifications'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final n in list)
                      AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(n.read ? Icons.notifications_none : Icons.notifications_active,
                                color: n.read ? AppColors.muted : AppColors.cyan, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.tr(n.key, _args(n)),
                                      style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                                  Text(fmtDateTime(n.createdAt),
                                      style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// Bell with unread badge for the app bar.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with _Reload {
  int _unread = 0;

  @override
  Future<void> load() async {
    final user = AppScope.read(context).user;
    if (user == null) return;
    final n = await NotificationRepository().unreadCount(user.id);
    if (mounted) setState(() => _unread = n);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('notifications'),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 9 ? '9+' : '$_unread'),
        child: const Icon(Icons.notifications_none),
      ),
    );
  }
}
