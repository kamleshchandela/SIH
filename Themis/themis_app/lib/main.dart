import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'screens/dossier_screen.dart';
import 'screens/engine_screen.dart';
import 'screens/home_screen.dart';
import 'screens/metrics_screen.dart';
import 'services/audit_storage_service.dart';
import 'theme/theme.dart';

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
      title: 'Themis — Legal Metrology Compliance Inspector',
      debugShowCheckedModeBanner: false,
      theme: ThemisTheme.sunlightTheme,
      darkTheme: ThemisTheme.darkSlateTheme,
      themeMode: ThemeMode.light, // Sunlight Light Theme default for field operations
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

  void _openTab(int index) => setState(() => _currentIndex = index);

  late final List<Widget> _screens = [
    HomeScreen(onNavigateTab: _openTab),
    const DossierScreen(),
    // Dashboard screen wrapped in Dark Slate Theme per design specification
    Theme(
      data: ThemisTheme.darkSlateTheme,
      child: const Scaffold(
        backgroundColor: ThemisTheme.darkSlateBg,
        body: MetricsScreen(),
      ),
    ),
    const EngineScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkTab = _currentIndex == 2; // Insights/Dashboard is dark slate

    return Scaffold(
      backgroundColor: isDarkTab ? ThemisTheme.darkSlateBg : ThemisTheme.sunlightBg,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkTab ? ThemisTheme.darkSlateSurface : ThemisTheme.sunlightSurface,
          border: Border(
            top: BorderSide(
              color: isDarkTab ? ThemisTheme.darkSlateBorder : ThemisTheme.sunlightBorder,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: CupertinoIcons.house,
                  activeIcon: CupertinoIcons.house_fill,
                  label: 'Home',
                  isDark: isDarkTab,
                ),
                _buildNavItem(
                  index: 1,
                  icon: CupertinoIcons.folder,
                  activeIcon: CupertinoIcons.folder_fill,
                  label: 'Dossiers',
                  isDark: isDarkTab,
                ),
                _buildNavItem(
                  index: 2,
                  icon: CupertinoIcons.chart_pie,
                  activeIcon: CupertinoIcons.chart_pie_fill,
                  label: 'Insights',
                  isDark: isDarkTab,
                ),
                _buildNavItem(
                  index: 3,
                  icon: CupertinoIcons.gear_alt,
                  activeIcon: CupertinoIcons.gear_alt_fill,
                  label: 'Settings',
                  isDark: isDarkTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final selectedColor = ThemisTheme.amberPrimary;
    final unselectedColor = isDark ? ThemisTheme.darkSlateTextMuted : ThemisTheme.sunlightTextMuted;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 22,
                color: isSelected ? selectedColor : unselectedColor,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? selectedColor : unselectedColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
