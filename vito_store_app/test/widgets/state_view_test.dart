import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vito_store_app/shared/widgets/state_view.dart';

void main() {
  // Helper to wrap a widget in a MaterialApp so theme/text styles resolve.
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('StateView', () {
    testWidgets('shows loading indicator when async value is loading',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          StateView<String>(
            asyncValue: const AsyncLoading<List<String>>(),
            builder: (data) => ListView(children: data.map((e) => Text(e)).toList()),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LoadingState), findsOneWidget);
    });

    testWidgets('shows empty state with message when data is empty',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          StateView<String>(
            asyncValue: const AsyncData<List<String>>([]),
            emptyMessage: 'No hay productos',
            builder: (data) => ListView(children: data.map((e) => Text(e)).toList()),
          ),
        ),
      );

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No hay productos'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows default empty message when none provided and data empty',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          StateView<String>(
            asyncValue: const AsyncData<List<String>>([]),
            builder: (data) => ListView(children: data.map((e) => Text(e)).toList()),
          ),
        ),
      );

      expect(find.text('No hay contenido'), findsOneWidget);
    });

    testWidgets('shows error state with retry button when there is an error',
        (tester) async {
      var retryPressed = false;

      await tester.pumpWidget(
        wrap(
          StateView<String>(
            asyncValue: const AsyncError<List<String>>(
              'Fallo de red',
              StackTrace.empty,
            ),
            onRetry: () => retryPressed = true,
            builder: (data) => ListView(children: data.map((e) => Text(e)).toList()),
          ),
        ),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Fallo de red'), findsOneWidget);
      // The retry button is a FilledButton labeled 'Reintentar'.
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();

      expect(retryPressed, isTrue);
    });

    testWidgets('shows error state without retry button when onRetry is null',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          StateView<String>(
            asyncValue: const AsyncError<List<String>>(
              'Error sin retry',
              StackTrace.empty,
            ),
            builder: (data) => ListView(children: data.map((e) => Text(e)).toList()),
          ),
        ),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Error sin retry'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('shows builder content when data is present', (tester) async {
      const items = ['Item A', 'Item B', 'Item C'];

      await tester.pumpWidget(
        wrap(
          StateView<String>(
            asyncValue: const AsyncData<List<String>>(items),
            builder: (data) => Column(
              children: data.map((e) => Text(e)).toList(),
            ),
          ),
        ),
      );

      expect(find.text('Item A'), findsOneWidget);
      expect(find.text('Item B'), findsOneWidget);
      expect(find.text('Item C'), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(LoadingState), findsNothing);
    });

    testWidgets('shows empty action button when provided and data is empty',
        (tester) async {
      var actionPressed = false;

      await tester.pumpWidget(
        wrap(
          StateView<String>(
            asyncValue: const AsyncData<List<String>>([]),
            emptyMessage: 'Carrito vacio',
            emptyActionLabel: 'Ir a la tienda',
            emptyAction: () => actionPressed = true,
            builder: (data) => ListView(children: data.map((e) => Text(e)).toList()),
          ),
        ),
      );

      expect(find.text('Ir a la tienda'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);

      await tester.tap(find.text('Ir a la tienda'));
      await tester.pump();

      expect(actionPressed, isTrue);
    });
  });
}
