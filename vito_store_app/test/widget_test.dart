import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vito_store_app/config/theme/app_theme.dart';
import 'package:vito_store_app/config/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('primary color matches vito-blue #0066CC', () {
      expect(AppColors.primary, const Color(0xFF0066CC));
    });

    test('dark background is true black for OLED', () {
      expect(AppColors.darkBackground, const Color(0xFF000000));
    });
  });

  group('AppTheme', () {
    testWidgets('light theme builds without error', (tester) async {
      final theme = AppTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, AppColors.primary);
    });

    testWidgets('dark theme builds without error', (tester) async {
      final theme = AppTheme.dark();
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, AppColors.darkPrimary);
    });
  });

  testWidgets('MaterialApp with theme renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const Scaffold(body: Text('VITO')),
      ),
    );
    expect(find.text('VITO'), findsOneWidget);
  });
}
