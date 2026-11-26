import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';

/// 1 Shipment -> 2 Review -> 3 Planning -> 4 Results. [current] is 1-based.
class StepIndicator extends StatelessWidget {
  final int current;
  const StepIndicator({super.key, required this.current});

  static const _keys = ['step_shipment', 'step_review', 'step_planning', 'step_results'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          for (var i = 0; i < _keys.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: i < current ? AppColors.cyan : AppColors.border,
                ),
              ),
            _dot(context, i + 1, context.tr(_keys[i])),
          ],
        ],
      ),
    );
  }

  Widget _dot(BuildContext context, int n, String label) {
    final done = n < current;
    final active = n == current;
    final color = active || done ? AppColors.cyan : AppColors.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active ? AppColors.gradient : null,
            color: active ? null : (done ? AppColors.cyan.withValues(alpha: 0.18) : AppColors.panel),
            border: Border.all(color: color, width: active ? 0 : 1.2),
          ),
          child: done
              ? const Icon(Icons.check, size: 15, color: AppColors.cyan)
              : Text('$n',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800, color: active ? Colors.white : AppColors.muted)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }
}
