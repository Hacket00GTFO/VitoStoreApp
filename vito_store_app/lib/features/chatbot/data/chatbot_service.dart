import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: library_prefixes, conventional prefix for socket_io_client
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../../config/env.dart';
import '../domain/chat_message.dart';

/// Servicio del chatbot via Socket.IO.
/// Se conecta al backend (Env.apiBaseUrl) y expone un stream de mensajes
/// entrantes del asistente VITO.
class ChatbotService {
  ChatbotService() {
    _initSocket();
  }

  late final IO.Socket _socket;
  final _controller = StreamController<ChatMessage>.broadcast();
  bool _connected = false;

  /// Stream de mensajes entrantes del bot.
  Stream<ChatMessage> get messageStream => _controller.stream;

  /// Estado de conexion.
  bool get isConnected => _connected;

  void _initSocket() {
    // La URL base del backend (sin /api). Socket.IO se sirve en el mismo host.
    final base = Env.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    _socket = IO.io(
      base,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNewConnection()
          .build(),
    );

    _socket.onConnect((_) {
      _connected = true;
    });

    _socket.onDisconnect((_) {
      _connected = false;
    });

    _socket.onConnectError((_) {
      _connected = false;
    });

    // Evento de respuesta del bot.
    _socket.on('bot_message', (data) {
      final text = _extractText(data);
      if (text.isNotEmpty) {
        _controller.add(ChatMessage.bot(text));
      }
    });

    // Indicador de "escribiendo...".
    _socket.on('typing', (data) {
      _controller.add(ChatMessage.bot('...', isTyping: true));
    });
  }

  String _extractText(dynamic data) {
    if (data is String) return data;
    if (data is Map) {
      return (data['message']?.toString() ??
          data['text']?.toString() ??
          data['response']?.toString() ??
          '');
    }
    return '';
  }

  /// Conecta el socket (si no esta conectado).
  void connect() {
    if (!_socket.connected) {
      _socket.connect();
    }
  }

  /// Desconecta el socket.
  void disconnect() {
    if (_socket.connected) {
      _socket.disconnect();
    }
  }

  /// Envia un mensaje de texto al backend.
  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    connect();
    _socket.emit('user_message', {'message': text.trim()});
  }

  /// Libera recursos.
  void dispose() {
    disconnect();
    _controller.close();
    _socket.dispose();
  }
}

/// Provider del [ChatbotService].
final chatbotServiceProvider = Provider<ChatbotService>((ref) {
  final service = ChatbotService();
  ref.onDispose(service.dispose);
  return service;
});
