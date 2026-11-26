import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/shipment_repository.dart';
import '../../domain/shipment.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'new_shipment_screen.dart';
import 'shipment_screen.dart';

/// Shipments tab: all shipments of the signed-in user.
class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key});

  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final _repo = ShipmentRepository();
  List<ShipmentSummary>? _list;

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
    final l = await _repo.listForUser(user.id);
    if (mounted) setState(() => _list = l);
  }

  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (list == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GradientButton(
          label: context.tr('newShipment'),
          icon: Icons.add,
          onPressed: () => _open(const NewShipmentScreen()),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty) EmptyState(icon: Icons.inventory_2_outlined, text: context.tr('shipmentsEmpty')),
        for (final item in list)
          AppCard(
            onTap: () => _open(ShipmentScreen(shipmentId: item.shipment.id)),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppColors.cyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.shipment.name.isEmpty ? item.shipment.code : '${item.shipment.code} · ${item.shipment.name}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${context.tr(item.shipment.container.titleKey)}\n'
                        '${context.tr('boxesCount', {'n': fmtNum(item.boxes)})} · ${fmtNum(item.weightKg)} ${context.tr('kg')}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.45),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: item.shipment.status),
              ],
            ),
          ),
      ],
    );
  }
}
