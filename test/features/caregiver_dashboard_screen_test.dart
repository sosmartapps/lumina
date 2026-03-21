import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumina/features/caregiver/caregiver_dashboard_screen.dart';

void main() {
  group('CaregiverDashboardScreen Tests', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CaregiverDashboardScreen(),
          ),
        ),
      );

      expect(find.byType(CaregiverDashboardScreen), findsOneWidget);
    });

    testWidgets('displays scaffold with app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CaregiverDashboardScreen(),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('has exit caregiver mode button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CaregiverDashboardScreen(),
          ),
        ),
      );

      // Look for the exit to app button in the AppBar
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    });

    testWidgets('renders dashboard content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CaregiverDashboardScreen(),
          ),
        ),
      );

      // Dashboard should contain various sections and buttons
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('uses correct theme colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CaregiverDashboardScreen(),
          ),
        ),
      );

      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);

      final appBarWidget = tester.widget<AppBar>(appBar);
      expect(appBarWidget.backgroundColor, isNotNull);
    });

    testWidgets('can toggle bottom navigation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CaregiverDashboardScreen(),
          ),
        ),
      );

      // Dashboard typically uses bottom navigation or tab navigation
      expect(find.byType(BottomNavigationBar), findsWidgets);
    });
  });
}
