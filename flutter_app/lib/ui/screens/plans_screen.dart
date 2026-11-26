import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/plan_repository.dart';
import '../../data/shipment_repository.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'results_screen.dart';

/// Plans tab: every generated plan of the signed-in user, newest first.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<PlanSummary>? _list;

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
    final l = await PlanRepository().listForUser(user.id);
    if (mounted) setState(() => _list = l);
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      return EmptyState(icon: Icons.view_in_ar_outlined, text: context.tr('plansEmpty'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final p in list)
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultsScreen(planId: p.id))),
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
                      const SizedBox(height: 2),
                      Text(
                        '${fmtNum(p.utilization, 1)}% · ${context.tr('loadedOf', {'a': p.loaded, 'b': p.total})} · '
                        '${fmtDateTime(p.createdAt)}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(p.saved ? Icons.bookmark : Icons.bookmark_border,
                    color: p.saved ? AppColors.green : AppColors.muted, size: 20),
              ],
            ),
          ),
      ],
    );
  }
}
