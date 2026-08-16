/// Modelo de mensaje del chatbot (asistente VITO).
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.timestamp,
    this.isTyping = false,
  });

  factory ChatMessage.user(String text) {
    return ChatMessage(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.bot(String text, {bool isTyping = false}) {
    return ChatMessage(
      id: 'b-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      isTyping: isTyping,
    );
  }

  final String id;
  final String text;
  final bool isUser;
  final DateTime? timestamp;
  final bool isTyping;
}
