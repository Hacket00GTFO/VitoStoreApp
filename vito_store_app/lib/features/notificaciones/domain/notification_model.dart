import 'package:intl/intl.dart';

/// Modelo de notificacion. Refleja la estructura consumida via `/api/notifications`.
class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      read: (json['read'] as bool?) ?? (json['isRead'] as bool?) ?? false,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  final String id;
  final String title;
  final String message;
  final bool read;
  final DateTime? createdAt;

  /// Fecha formateada para mostrar en UI.
  String get formattedDate {
    if (createdAt == null) return '--';
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return fmt.format(createdAt!);
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
