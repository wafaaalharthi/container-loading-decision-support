import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/shipment.dart';
import '../../state/app_state.dart';

/// Donut chart of a shipment by category, by box count or by volume.
class CategoryPie extends StatefulWidget {
  final List<BoxGroup> groups;
  const CategoryPie({super.key, required this.groups});

  @override
  State<CategoryPie> createState() => _CategoryPieState();
}

class _CategoryPieState extends State<CategoryPie> {
  bool _byVolume = false;

  @override
  Widget build(BuildContext context) {
    // Sum per category, kept in the fixed category order
    final totals = <String, double>{};
    for (final g in widget.groups) {
      final k = kKinds.contains(g.kind) ? g.kind : 'other';
      totals[k] = (totals[k] ?? 0) + (_byVolume ? g.totalVolumeM3 : g.quantity.toDouble());
    }
    final slices = [
      for (final k in kKinds)
        if ((totals[k] ?? 0) > 0) (k, totals[k]!),
    ];
    final sum = slices.fold<double>(0, (a, s) => a + s.$2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              selectedBackgroundColor: AppColors.blue.withValues(alpha: 0.35),
              selectedForegroundColor: AppColors.cyan,
            ),
            segments: [
              ButtonSegment(value: false, label: Text(context.tr('byCount'))),
              ButtonSegment(value: true, label: Text(context.tr('byVolume'))),
            ],
            selected: {_byVolume},
            onSelectionChanged: (s) => setState(() => _byVolume = s.first),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: CustomPaint(
                painter: _DonutPainter([for (final s in slices) (AppColors.categories[s.$1]!, s.$2)]),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_byVolume ? fmtNum(sum, 1) : fmtNum(sum),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(_byVolume ? 'm³' : context.tr('boxesUnit'),
                          style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  for (final s in slices)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: AppColors.categories[s.$1], borderRadius: BorderRadius.circular(3)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(context.tr('kind_${s.$1}'),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                          ),
                          Text(
                            '${_byVolume ? fmtNum(s.$2, 1) : fmtNum(s.$2)} · ${fmtNum(s.$2 / sum * 100)}%',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
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
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(Color, double)> slices;
  _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, s) => a + s.$2);
    if (total <= 0) return;
    final stroke = size.width * 0.17;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: (size.width - stroke) / 2);
    final gap = slices.length > 1 ? 0.035 : 0.0; // small surface gap between slices
    var start = -math.pi / 2;
    for (final (color, v) in slices) {
      final sweep = v / total * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color;
      canvas.drawArc(rect, start + gap / 2, math.max(0.001, sweep - gap), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}
