import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:themis_app/screens/engine_screen.dart';
import 'package:themis_app/services/themis_api.dart';

void main() {
  group('EngineModelOption and Hardware Concurrency Tests', () {
    test('ThemisApiService defaults to mobileCompactInt8 and updates model option', () {
      final api = ThemisApiService();
      expect(api.modelOption, EngineModelOption.mobileCompactInt8);

      api.setModelOption(EngineModelOption.mobileAccurateInt8);
      expect(api.modelOption, EngineModelOption.mobileAccurateInt8);

      api.setModelOption(EngineModelOption.remoteServer);
      expect(api.modelOption, EngineModelOption.remoteServer);

      // Reset to compact
      api.setModelOption(EngineModelOption.mobileCompactInt8);
      expect(api.modelOption, EngineModelOption.mobileCompactInt8);
    });

    testWidgets('EngineScreen renders the 3 model tiers', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EngineScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Check for 3 distinct options
      expect(find.text('1. Mobile Native Fast (Compact INT8 • ~3.1 MB)'), findsOneWidget);
      expect(find.text('2. Mobile Native High-Accuracy (Accurate INT8 • ~27.3 MB)'), findsOneWidget);
      expect(find.text('3. Remote Themis Server (LAN / WAN Daemon)'), findsOneWidget);

      // Check for execution type indicators
      expect(find.text('Device ARM NEON • Zero Network'), findsOneWidget);
      expect(find.text('Device NPU / NNAPI • Zero Network'), findsOneWidget);
      expect(find.text('Rust Axum Daemon • LAN / WAN'), findsOneWidget);
    });
  });
}
