import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:themis_app/main.dart';
import 'package:themis_app/services/glass_perf_service.dart';
import 'package:themis_app/widgets/sober/sober_bottom_bar.dart';

void main() {
  testWidgets('ThemisApp renders navigation bar and dashboard by default', (WidgetTester tester) async {
    await tester.pumpWidget(const ThemisApp());
    await tester.pump(const Duration(milliseconds: 300));

    // By default, sober bottom bar is rendered with navigation icons
    expect(find.byType(SoberBottomBar), findsOneWidget);
    expect(find.descendant(of: find.byType(SoberBottomBar), matching: find.byIcon(CupertinoIcons.house_fill)), findsOneWidget);
    expect(find.descendant(of: find.byType(SoberBottomBar), matching: find.byIcon(CupertinoIcons.calendar)), findsOneWidget);
    expect(find.descendant(of: find.byType(SoberBottomBar), matching: find.byIcon(CupertinoIcons.folder_fill)), findsOneWidget);
    expect(find.descendant(of: find.byType(SoberBottomBar), matching: find.byIcon(CupertinoIcons.gear_alt_fill)), findsOneWidget);
  });

  testWidgets('Glass mode renders glass navigation bar and inspection tabs', (WidgetTester tester) async {
    // Switch to glass mode to test glass navigation and scan tab selectors
    GlassPerfService.instance.setSoberMode(false);

    await tester.pumpWidget(const ThemisApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('INSPECT'), findsOneWidget);
    expect(find.text('Single Panel'), findsOneWidget);
    expect(find.text('Full SKU (Multi)'), findsOneWidget);
    expect(find.text('Server Path'), findsOneWidget);

    // Switch to Full SKU (Multi)
    await tester.tap(find.text('Full SKU (Multi)'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Multi-Panel Pooled SKU Audit'), findsOneWidget);
    expect(find.text('PRODUCT SKU NAME (OPTIONAL)'), findsOneWidget);

    // Switch back to sober mode to restore baseline state
    GlassPerfService.instance.setSoberMode(true);
  });
}
