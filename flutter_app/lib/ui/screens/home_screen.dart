import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/shipment_repository.dart';
import '../../domain/shipment.dart';
import '../../state/app_state.dart';
import '../widgets/category_pie.dart';
import '../widgets/common.dart';
import 'new_shipment_screen.dart';
import 'records_screens.dart';
import 'shipment_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onOpenTab;
  const HomeScreen({super.key, required this.onOpenTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeStats _stats = HomeStats.empty;
  Shipment? _latest;
  List<BoxGroup> _latestGroups = const [];

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
    final user = AppScope.read(context).user;
    if (user == null) return;
    final repo = ShipmentRepository();
    final s = await StatsRepository().forUser(user.id);
    final list = await repo.listForUser(user.id);
    final latest = list.isEmpty ? null : list.first.shipment;
    final groups = latest == null ? <BoxGroup>[] : await repo.groups(latest.id);
    if (!mounted) return;
    setState(() {
      _stats = s;
      _latest = latest;
      _latestGroups = groups;
    });
  }

  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final user = context.app.user;
    final latest = _latest;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.tr('hello', {'name': user?.name ?? ''}),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(context.tr('homeSub'), style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(icon: Icons.inventory_2_outlined, label: context.tr('statShipments'), value: _stats.shipments, onTap: () => widget.onOpenTab(2)),
              const SizedBox(width: 8),
              _Stat(icon: Icons.view_in_ar_outlined, label: context.tr('statPlans'), value: _stats.savedPlans, onTap: () => widget.onOpenTab(1)),
              const SizedBox(width: 8),
              _Stat(
                icon: Icons.description_outlined,
                label: context.tr('statReports'),
                value: _stats.reports,
                onTap: () => _open(const ReportsRecordsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: context.tr('newPlan'),
            icon: Icons.add,
            onPressed: () => _open(const NewShipmentScreen()),
          ),
          SectionTitle(context.tr('composition')),
          AppCard(
            child: latest == null || _latestGroups.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(context.tr('noShipmentYet'), style: const TextStyle(color: AppColors.muted)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              latest.name.isEmpty ? latest.code : '${latest.code} · ${latest.name}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _open(ShipmentScreen(shipmentId: latest.id)),
                            child: Text(context.tr('openShipment')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      CategoryPie(groups: _latestGroups),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onTap;
  const _Stat({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.cyan),
            const SizedBox(height: 8),
            Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
