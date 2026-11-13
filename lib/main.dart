import 'package:flutter/material.dart';

import 'car/car_screens.dart';
import 'state/app_state.dart';
import 'ui/home.dart';

const soulRed = Color(0xFFC8102E);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  // Car screens are set up at startup (not from a phone screen) so CarPlay / Android Auto
  // can launch the app without the phone UI being opened first.
  CarScreens(state).start();
  runApp(MzdOwnerApp(state: state));
  // Reconnect on launch when there's something to connect to (demo, or a remembered adapter),
  // so getting in the car and opening CarPlay is enough.
  if (state.demoMode || state.adapterId != null) state.connect();
}

class MzdOwnerApp extends StatelessWidget {
  const MzdOwnerApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: soulRed,
      brightness: Brightness.dark,
      primary: soulRed,
      surface: const Color(0xFF111215),
    );
    return MaterialApp(
      title: 'Mi Mazda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0B0C0E),
        cardTheme: CardThemeData(
          color: const Color(0xFF17191D),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFF262A31))),
          margin: EdgeInsets.zero,
        ),
        navigationBarTheme: const NavigationBarThemeData(backgroundColor: Color(0xFF111215), indicatorColor: Color(0x33C8102E)),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0B0C0E), surfaceTintColor: Colors.transparent, centerTitle: false),
      ),
      home: HomeShell(state: state),
    );
  }
}
