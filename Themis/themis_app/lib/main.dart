import 'package:flutter/material.dart';
import 'screens/dossier_screen.dart';
import 'screens/engine_screen.dart';
import 'screens/inspect_screen.dart';
import 'screens/metrics_screen.dart';
import 'services/audit_storage_service.dart';
import 'services/glass_perf_service.dart';
import 'theme/glass_theme.dart';
import 'theme/sober_theme.dart';
import 'widgets/glass/fluid_background.dart';
import 'widgets/glass/glass_bottom_bar.dart';
import 'widgets/sober/sober_bottom_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AuditStorageService.instance.ensureInitialized();
  runApp(const ThemisApp());
}

class ThemisApp extends StatelessWidget {
  const ThemisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PARAKH Legal Metrology Inspector',
      debugShowCheckedModeBanner: false,
      theme: GlassTheme.theme,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final FocusNode _dossierSearchFocus = FocusNode();

  void _openTab(int index) => setState(() => _currentIndex = index);

  void _onSearchFromBottomBar() {
    _openTab(1);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _dossierSearchFocus.requestFocus();
      }
    });
  }

  late final List<Widget> _screens = [
    InspectScreen(onOpenTab: _openTab),
    DossierScreen(searchFocusNode: _dossierSearchFocus),
    const MetricsScreen(),
    const EngineScreen(),
  ];

  @override
  void dispose() {
    _dossierSearchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds the shell on tier/sober switches. The tab screens are const
    // and keep their state; GlassContainer re-skins itself via its own
    // ListenableBuilder, so the glass theme is never disturbed.
    return ListenableBuilder(
      listenable: GlassPerfService.instance,
      builder: (context, _) {
        final sober = GlassPerfService.instance.soberMode;
        final viewport = Positioned.fill(
          child: RepaintBoundary(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        );

        Widget navBar = sober
            ? SafeArea(
                top: false,
                child: SoberBottomBar(
                  currentIndex: _currentIndex,
                  onTap: (index) => setState(() => _currentIndex = index),
                  onSearchTap: _onSearchFromBottomBar,
                ),
              )
            : SafeArea(
                top: false,
                child: GlassBottomBar(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() => _currentIndex = index);
                  },
                ),
              );

        final stack = Stack(
          children: [
            viewport,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: navBar,
            ),
          ],
        );

        return Scaffold(
          backgroundColor: sober ? SoberTheme.pageBg : GlassTheme.bgDark,
          // Sober: flat page background, wallpaper pipeline fully out.
          // Glass: existing fluid backdrop. Never both.
          body: sober
              ? Container(color: SoberTheme.pageBg, child: stack)
              : FluidBackground(child: stack),
        );
      },
    );
  }
}
