import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'plans_screen.dart';
import 'records_screens.dart';
import 'shipments_screen.dart';

/// Selected bottom tab (other screens can switch it, e.g. "Finish" goes home).
final ValueNotifier<int> shellTab = ValueNotifier<int>(0);

/// Main screen after sign-in: four tabs.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int get _tab => shellTab.value;

  void _onTab() => setState(() {});

  @override
  void initState() {
    super.initState();
    shellTab.addListener(_onTab);
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTab);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['navHome', 'navPlans', 'navShipments', 'navMore'];
    return Scaffold(
      appBar: AppBar(
        title: _tab == 0
            ? const Row(
                children: [
                  _Logo(),
                  SizedBox(width: 10),
                  Text('Senior Project 1', textDirection: TextDirection.ltr),
                ],
              )
            : Text(context.tr(titles[_tab])),
        actions: const [NotificationBell(), LangToggle(), SizedBox(width: 12)],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(onOpenTab: (i) => shellTab.value = i),
          const PlansScreen(),
          const ShipmentsScreen(),
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => shellTab.value = i,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: context.tr('navHome')),
          NavigationDestination(icon: const Icon(Icons.view_in_ar_outlined), selectedIcon: const Icon(Icons.view_in_ar), label: context.tr('navPlans')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: context.tr('navShipments')),
          NavigationDestination(icon: const Icon(Icons.menu), label: context.tr('navMore')),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(9)),
      child: const Icon(Icons.view_in_ar, size: 19, color: Colors.white),
    );
  }
}
