import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/shipment.dart';
import '../../state/app_state.dart';

/// One physical box: ID, group color, contents and accepted / rejected state.
class BoxRow extends StatelessWidget {
  final String id;
  final BoxGroup group;
  final bool accepted;
  const BoxRow({super.key, required this.id, required this.group, required this.accepted});

  @override
  Widget build(BuildContext context) {
    final g = group;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: AppColors.group(g.code), borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(id,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                Text(
                  context.tr('boxLine', {
                    'what': g.contents.isEmpty ? context.tr('kind_${g.kind}') : g.contents,
                    'dims': dimsCm(g.lengthMm, g.widthMm, g.heightMm),
                    'kg': fmtKg(g.weightKg),
                  }),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            context.tr(accepted ? 'accepted' : 'rejected'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accepted ? AppColors.green : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
