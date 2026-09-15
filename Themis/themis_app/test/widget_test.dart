import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:themis_app/main.dart';
import 'package:themis_app/screens/home_screen.dart';
import 'package:themis_app/widgets/primitives/themis_primitives.dart';

void main() {
  testWidgets('ThemisApp renders navigation bar and home screen by default', (WidgetTester tester) async {
    await tester.pumpWidget(const ThemisApp());
    await tester.pump(const Duration(milliseconds: 300));

    // Home screen renders with statutory app bar
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(ThemisAppBar), findsOneWidget);

    // Primary Guided Scan CTA is displayed prominently
    expect(find.text('START GUIDED SCAN (4 STEPS)'), findsOneWidget);

    // Navigation bar with 4 core tabs
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Dossiers'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Navigation icons
    expect(find.byIcon(CupertinoIcons.house_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.folder), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chart_pie), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.gear_alt), findsOneWidget);
  });

  testWidgets('ThemisApp bottom navigation switches tabs correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ThemisApp());
    await tester.pump(const Duration(milliseconds: 300));

    // Switch to Insights (Supervisor Dashboard)
    await tester.tap(find.text('Insights'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NATIONAL INTELLIGENCE'), findsOneWidget);

    // Switch to Settings (Engine & Diagnostics)
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ENGINE & CONFIGURATION'), findsOneWidget);

    // Switch back to Home
    await tester.tap(find.text('Home'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('START GUIDED SCAN (4 STEPS)'), findsOneWidget);
  });
}
