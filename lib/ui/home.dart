import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'assistant_page.dart';
import 'dashboard_page.dart';
import 'diagnostics_page.dart';
import 'maintenance_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // MZD_START_TAB is a build-time option used to capture store screenshots of each tab.
  int _tab = const int.fromEnvironment('MZD_START_TAB');

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final pages = [
          DashboardPage(state: s),
          MaintenancePage(state: s),
          DiagnosticsPage(state: s),
          AssistantPage(state: s),
          SettingsPage(state: s),
        ];
        final maintAlerts = s.maintenance.where((i) => s.statusOf(i).level.index <= 1).length;
        return Scaffold(
          body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.speed_outlined), selectedIcon: Icon(Icons.speed), label: 'Tablero'),
              NavigationDestination(
                icon: Badge(isLabelVisible: maintAlerts > 0, label: Text('$maintAlerts'), child: const Icon(Icons.build_outlined)),
                selectedIcon: const Icon(Icons.build),
                label: 'Servicio',
              ),
              NavigationDestination(
                icon: Badge(isLabelVisible: (s.dtcs?.isNotEmpty ?? false), label: Text('${s.dtcs?.length ?? 0}'), child: const Icon(Icons.health_and_safety_outlined)),
                selectedIcon: const Icon(Icons.health_and_safety),
                label: 'Diagnóstico',
              ),
              const NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'Asistente'),
              const NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Ajustes'),
            ],
          ),
        );
      },
    );
  }
}
