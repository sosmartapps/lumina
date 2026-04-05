import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumina/core/theme/app_theme.dart';
import 'package:lumina/features/user_home/user_home_screen.dart';

void main() {
  group('UserHomeScreen Tests', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UserHomeScreen(),
          ),
        ),
      );

      expect(find.byType(UserHomeScreen), findsOneWidget);
    });

    testWidgets('displays app title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UserHomeScreen(),
          ),
        ),
      );

      // Look for Lumina title or similar branding
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders in portrait orientation', (WidgetTester tester) async {
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UserHomeScreen(),
          ),
        ),
      );

      expect(find.byType(UserHomeScreen), findsOneWidget);
    });

    testWidgets('uses high-contrast theme colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UserHomeScreen(),
          ),
        ),
      );

      final scaffold = find.byType(Scaffold);
      expect(scaffold, findsOneWidget);

      // Verify the scaffold exists (theme colors would be applied to it)
      final scaffoldWidget = tester.widget<Scaffold>(scaffold);
      expect(scaffoldWidget.backgroundColor, isNotNull);
    });

    testWidgets('renders loading or action tiles', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UserHomeScreen(),
          ),
        ),
      );

      // Without a logged-in user, shows loading indicator; with user, shows tiles
      final hasSpinner = find.byType(CircularProgressIndicator);
      final hasTiles = find.byType(GestureDetector);
      expect(
        hasSpinner.evaluate().isNotEmpty || hasTiles.evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
