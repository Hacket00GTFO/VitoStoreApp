import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Widget de estado de carga (skeleton/spinner).
/// Replica del LoadingSpinner de la web.
class LoadingState extends StatelessWidget {
  const LoadingState({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Widget de estado de error con boton reintentar.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget de estado vacio con ilustracion y CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.icon = LucideIcons.inbox,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget que maneja los 4 estados obligatorios (skill mobile-design):
/// loading, error, empty, content.
class StateView<T> extends StatelessWidget {
  const StateView({
    required this.asyncValue,
    required this.builder,
    this.emptyMessage,
    this.emptyIcon,
    this.emptyAction,
    this.emptyActionLabel,
    this.onRetry,
    super.key,
  });

  final AsyncValue<List<T>> asyncValue;
  final Widget Function(List<T> data) builder;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final VoidCallback? emptyAction;
  final String? emptyActionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: (data) {
        if (data.isEmpty) {
          return EmptyState(
            message: emptyMessage ?? 'No hay contenido',
            icon: emptyIcon ?? LucideIcons.inbox,
            actionLabel: emptyActionLabel,
            onAction: emptyAction,
          );
        }
        return builder(data);
      },
      loading: () => const LoadingState(),
      error: (err, _) => ErrorState(
        message: err.toString(),
        onRetry: onRetry,
      ),
    );
  }
}
