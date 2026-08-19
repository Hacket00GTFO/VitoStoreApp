import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../contact/data/contact_repository.dart';
import '../data/chatbot_service.dart';
import '../domain/chat_message.dart';

/// Respuestas rapidas sugeridas (espejo de QUICK_RESPONSES del ChatWidget web).
const List<String> _quickResponses = [
  '¿Cuáles son sus horarios de atención?',
  'Necesito una cotización',
  'Tengo un problema técnico',
  'Información sobre productos',
];

/// Palabras clave que sugieren intencion de contacto (espejo del ChatWidget web).
const _contactKeywords = ['contact', 'llam', 'email', 'cotiz', 'correo', 'teléfon', 'telefono'];

/// Bottom sheet con la interfaz del chatbot "Asistente VITO".
/// Muestra lista de mensajes (burbujas), indicador de escritura y campo de
/// entrada con boton de enviar.
class ChatbotSheet extends ConsumerStatefulWidget {
  const ChatbotSheet({super.key});

  /// Muestra el sheet modal.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ChatbotSheet(),
    );
  }

  @override
  ConsumerState<ChatbotSheet> createState() => _ChatbotSheetState();
}

class _ChatbotSheetState extends ConsumerState<ChatbotSheet> {
  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  // Formulario de contacto inline (espejo del ChatWidget web).
  bool _showContactForm = false;
  final _contactFormKey = GlobalKey<FormState>();
  final _cNameController = TextEditingController();
  final _cEmailController = TextEditingController();
  final _cPhoneController = TextEditingController();
  bool _sendingContact = false;

  @override
  void initState() {
    super.initState();
    // Mensaje de bienvenida.
    _messages.add(ChatMessage.bot(
      'Hola, soy el Asistente VITO. En que puedo ayudarte hoy?',
    ));
  }

  @override
  void dispose() {
    // Al cerrar el chat, resetear la sesión del asistente (best-effort).
    ref.read(chatbotServiceProvider).resetSession();
    _inputController.dispose();
    _scrollController.dispose();
    _cNameController.dispose();
    _cEmailController.dispose();
    _cPhoneController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isTyping) return;
    final service = ref.read(chatbotServiceProvider);
    setState(() {
      _messages.add(ChatMessage.user(text));
      _isTyping = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final answer = await service.ask(
        message: text,
        history: List<ChatMessage>.from(_messages),
      );
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage.bot(answer));
      });
      // Detectar intencion de contacto y ofrecer el formulario inline.
      final lower = text.toLowerCase();
      if (_contactKeywords.any((k) => lower.contains(k)) && !_showContactForm) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() {
            _messages.add(ChatMessage.bot(
              'Si deseas que te contactemos, por favor completa tus datos a continuacion.',
            ));
            _showContactForm = true;
          });
          _scrollToBottom();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage.bot(
          'No pude conectar con el asistente. Verifica tu conexion e intenta de nuevo.',
        ));
      });
    }
    _scrollToBottom();
  }

  /// Envia el formulario de contacto inline (reutiliza ContactRepository).
  Future<void> _submitContactForm() async {
    if (!_contactFormKey.currentState!.validate()) return;
    setState(() => _sendingContact = true);
    try {
      final repo = ref.read(contactRepositoryProvider);
      final ok = await repo.sendMessage(
        name: _cNameController.text.trim(),
        email: _cEmailController.text.trim(),
        phone: _cPhoneController.text.trim().isEmpty
            ? null
            : _cPhoneController.text.trim(),
        subject: 'Solicitud desde chatbot',
        message: 'El usuario solicito contacto desde el asistente VITO.',
      );
      if (!mounted) return;
      if (ok) {
        setState(() {
          _showContactForm = false;
          _messages.add(ChatMessage.bot(
            'Gracias por tus datos. Un asesor se comunicara contigo pronto.',
          ));
        });
        _cNameController.clear();
        _cEmailController.clear();
        _cPhoneController.clear();
      } else {
        setState(() {
          _messages.add(ChatMessage.bot(
            'No pude enviar tus datos. Intenta de nuevo mas tarde.',
          ));
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage.bot(
          'Ocurrio un error al enviar tus datos. Intenta de nuevo.',
        ));
      });
    } finally {
      if (mounted) setState(() => _sendingContact = false);
    }
    _scrollToBottom();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'El correo es obligatorio';
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!regex.hasMatch(value.trim())) return 'Ingresa un correo valido';
    return null;
  }

  String? _required(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field es obligatorio';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(LucideIcons.bot, color: theme.colorScheme.onPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asistente VITO',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        'En linea',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Lista de mensajes
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _MessageBubble(message: _messages[index]),
            ),
          ),
          // Respuestas rapidas (solo al inicio, como en el ChatWidget web).
          if (_messages.length <= 2 && !_showContactForm && !_isTyping)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final q in _quickResponses)
                    ActionChip(
                      label: Text(q, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _inputController.text = q;
                        _send();
                      },
                    ),
                ],
              ),
            ),
          // Formulario de contacto inline (espejo del ChatWidget web).
          if (_showContactForm)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Form(
                key: _contactFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Dejanos tus datos para contactarte',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cNameController,
                      decoration: const InputDecoration(
                        labelText: 'Tu nombre',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _required(v, 'El nombre'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Tu email',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Tu telefono (opcional)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _sendingContact
                              ? null
                              : () => setState(() => _showContactForm = false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _sendingContact ? null : _submitContactForm,
                            icon: _sendingContact
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(LucideIcons.send, size: 16),
                            label: Text(_sendingContact ? 'Enviando...' : 'Enviar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // Indicador de escritura
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TypingIndicator(color: theme.colorScheme.outline),
              ),
            ),
          // Campo de entrada
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje...',
                      prefixIcon: const Icon(LucideIcons.messageCircle),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(LucideIcons.send),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Burbuja de mensaje individual.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final color = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final onColor = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: message.isTyping
            ? _TypingIndicator(color: onColor.withValues(alpha: 0.7))
            : Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
              ),
      ),
    );
  }
}

/// Indicador animado de "escribiendo..." (tres puntos).
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.color});

  final Color color;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = (_controller.value + i * 0.2) % 1.0;
            final scale = 0.6 + (t < 0.5 ? t : 1 - t) * 0.8;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: widget.color,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
