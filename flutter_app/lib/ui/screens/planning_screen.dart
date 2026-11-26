import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/plan_repository.dart';
import '../../data/shipment_repository.dart';
import '../../domain/planning.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/step_indicator.dart';
import 'results_screen.dart';

/// Step 3: choose instant or optimized and run the engine.
class PlanningScreen extends StatefulWidget {
  final int shipmentId;
  const PlanningScreen({super.key, required this.shipmentId});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  String _mode = 'instant';
  bool _running = false;
  int _elapsed = 0;
  Timer? _timer;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _running = true;
      _elapsed = 0;
      _error = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _elapsed++));
    try {
      final repo = ShipmentRepository();
      final s = (await repo.get(widget.shipmentId))!;
      final groups = await repo.groups(widget.shipmentId);
      final outcome = await runPlan(s, groups, _mode);
      final planId = await PlanRepository().insert(s, outcome);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultsScreen(planId: planId)));
    } catch (e) {
      if (mounted) setState(() => _error = context.tr('planFailed', {'e': e.toString()}));
    } finally {
      _timer?.cancel();
      if (mounted) setState(() => _running = false);
    }
  }

  Widget _option(String mode, IconData icon) {
    final on = _mode == mode;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: on ? AppColors.blue.withValues(alpha: 0.18) : AppColors.panel.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: on ? AppColors.cyan : AppColors.border, width: on ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _running ? null : () => setState(() => _mode = mode),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: on ? AppColors.cyan : AppColors.muted, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('mode_$mode'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(context.tr('mode_${mode}Sub'), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: on ? AppColors.cyan : AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_running,
      child: Scaffold(
        appBar: AppBar(title: Text(context.tr('planningTitle'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const StepIndicator(current: 3),
            _option('instant', Icons.bolt),
            _option('optimized', Icons.auto_awesome),
            const SizedBox(height: 8),
            if (_running)
              AppCard(
                child: Row(
                  children: [
                    const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    const SizedBox(width: 14),
                    Expanded(child: Text(context.tr('running', {'s': _elapsed}))),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ),
            GradientButton(
              label: context.tr('generate'),
              icon: Icons.play_arrow,
              busy: _running,
              onPressed: _generate,
            ),
          ],
        ),
      ),
    );
  }
}
