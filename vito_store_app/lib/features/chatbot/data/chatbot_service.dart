import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/chat_message.dart';

/// Servicio del chatbot "Asistente VITO".
///
/// Consume el endpoint REST del backend (el mismo que usa el widget web):
/// `POST /api/chatbot/assistant/public-query` (requiere sesión activa).
/// Mantiene un `sessionId` estable mientras la app está viva para darle
/// contexto conversacional al asistente.
class ChatbotService {
  ChatbotService(this._dio);

  final Dio _dio;
  String? _sessionId;

  /// Session id de la conversación actual (se genera bajo demanda).
  String get sessionId => _sessionId ??= _generateSessionId();

  static String _generateSessionId() {
    final rnd = Random.secure();
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rand =
        List.generate(10, (_) => rnd.nextInt(36).toRadixString(36)).join();
    return 'app-$ts-$rand';
  }

  /// Envía un mensaje al asistente y devuelve su respuesta en texto.
  ///
  /// [history] son los últimos mensajes visibles en la UI (sin los de
  /// "escribiendo..."), en orden cronológico; se envían los últimos 10.
  Future<String> ask({
    required String message,
    required List<ChatMessage> history,
  }) async {
    final historyPayload = history
        .where((m) => !m.isTyping && m.text.trim().isNotEmpty)
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    final resp = await _dio.post(
      ApiEndpoints.chatbotAssistantQuery,
      data: {
        'message': message,
        'explicitMessage': message,
        'rawMessage': message,
        'sessionId': sessionId,
        'pageContext': '/app',
        'history': historyPayload,
      },
    );

    final data = resp.data;
    final payload = data is Map<String, dynamic>
        ? (data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : data)
        : <String, dynamic>{};
    final answer = payload['answer']?.toString();
    if (answer == null || answer.trim().isEmpty) {
      return 'No pude responder esa pregunta en este momento. Intenta de nuevo.';
    }
    return answer;
  }

  /// Resetea la sesión del asistente en el servidor (best-effort) y genera
  /// una nueva para la próxima conversación.
  Future<void> resetSession() async {
    final previous = _sessionId;
    _sessionId = null;
    if (previous == null) return;
    try {
      await _dio
          .post(ApiEndpoints.chatbotAssistantReset, data: {'sessionId': previous})
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Best-effort: no bloquear la UI si falla el reset.
    }
  }
}

/// Provider del [ChatbotService].
final chatbotServiceProvider = Provider<ChatbotService>((ref) {
  return ChatbotService(ref.read(dioProvider));
});
