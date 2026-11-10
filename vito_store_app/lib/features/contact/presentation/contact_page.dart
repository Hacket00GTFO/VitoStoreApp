import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/contact_repository.dart';

/// Datos de contacto de VITO Technologies (externalizados para facil mantenimiento).
class _ContactData {
  static const String phone = '+52 81 1116 3774';
  static const String phoneDisplay = '81 1116 3774';
  static const String email = 'contacto@vitotechnologies.com';
  static const String fullAddress = 'Monterrey, Nuevo Leon, Mexico';
  static const String mapsUrl =
      'https://www.google.com/maps/search/?api=1&query=VITO+Technologies+Monterrey+Nuevo+Leon';
}

/// Pagina de contacto.
/// Formulario con validacion + datos de contacto y placeholder de mapa.
/// Acepta [initialSubject] para prefijar el asunto (p.ej. desde Servicios).
class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({this.initialSubject, super.key});

  final String? initialSubject;

  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSubject != null && widget.initialSubject!.isNotEmpty) {
      _subjectController.text = widget.initialSubject!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(contactRepositoryProvider);
      final ok = await repo.sendMessage(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      if (ok) {
        _formKey.currentState!.reset();
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _subjectController.clear();
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensaje enviado correctamente. Te contactaremos pronto.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar el mensaje. Intenta de nuevo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String message = 'Error: $e';
      if (e is DioException) {
        // El backend responde 400 con el detalle Joi (`{error:"Body validation failed: ...",details:[...]}`)
        // y 429 (publicQuota: 5 mensajes / 15 min por IP).
        final data = e.response?.data;
        final backendError = data is Map<String, dynamic>
            ? (data['error']?.toString())
            : null;
        if (e.response?.statusCode == 429) {
          message = 'Demasiados mensajes enviados desde esta red. '
              'Espera unos minutos e intenta de nuevo.';
        } else if (backendError != null && backendError.isNotEmpty) {
          message = backendError;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateName(String? value) {
    // Schema del backend: name min 2 max 100.
    if (value == null || value.trim().isEmpty) return 'El nombre es obligatorio';
    if (value.trim().length < 2) return 'El nombre debe tener al menos 2 caracteres';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'El correo es obligatorio';
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!regex.hasMatch(value.trim())) return 'Ingresa un correo valido';
    return null;
  }

  String? _validateSubject(String? value) {
    // Schema del backend: subject min 5 max 200 (si no, responde 400).
    if (value == null || value.trim().isEmpty) return 'El asunto es obligatorio';
    if (value.trim().length < 5) return 'El asunto debe tener al menos 5 caracteres';
    if (value.trim().length > 200) return 'El asunto debe tener 200 caracteres o menos';
    return null;
  }

  String? _validateMessage(String? value) {
    // Schema del backend: message min 10 max 5000 (si no, responde 400).
    if (value == null || value.trim().isEmpty) return 'El mensaje es obligatorio';
    if (value.trim().length < 10) return 'El mensaje debe tener al menos 10 caracteres';
    if (value.trim().length > 5000) return 'El mensaje debe tener 5000 caracteres o menos';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contacto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Envianos un mensaje',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(LucideIcons.user),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateName,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo electronico',
                      prefixIcon: Icon(LucideIcons.mail),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefono (opcional)',
                      prefixIcon: Icon(LucideIcons.phone),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Asunto',
                      prefixIcon: Icon(LucideIcons.tag),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateSubject,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Mensaje',
                      prefixIcon: Icon(LucideIcons.messageSquare),
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    maxLength: 5000,
                    validator: _validateMessage,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.send),
                    label: Text(_submitting ? 'Enviando...' : 'Enviar mensaje'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Datos de contacto
            Text('Informacion de contacto',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _ContactInfoTile(
              icon: LucideIcons.phone,
              title: 'Telefono',
              value: _ContactData.phoneDisplay,
              onTap: () => launchUrl(Uri.parse('tel:${_ContactData.phone.replaceAll(' ', '')}')),
            ),
            _ContactInfoTile(
              icon: LucideIcons.mail,
              title: 'Correo',
              value: _ContactData.email,
              onTap: () => launchUrl(Uri.parse('mailto:${_ContactData.email}')),
            ),
            _ContactInfoTile(
              icon: LucideIcons.mapPin,
              title: 'Direccion',
              value: _ContactData.fullAddress,
              onTap: () => launchUrl(Uri.parse(_ContactData.mapsUrl)),
            ),
            const SizedBox(height: 24),
            // Mapa interactivo — abre Google Maps al tocar.
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(_ContactData.mapsUrl),
                  mode: LaunchMode.externalApplication),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fondo con gradiente simulando mapa.
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.surfaceContainerHighest,
                            ],
                          ),
                        ),
                        child: CustomPaint(
                          painter: _MapGridPainter(
                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      // Pin central.
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.mapPin,
                                size: 40, color: theme.colorScheme.primary),
                            const SizedBox(height: 4),
                            Text('VITO Technologies',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                )),
                            Text('Toca para abrir en Maps',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ContactInfoTile extends StatelessWidget {
  const _ContactInfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: theme.textTheme.labelMedium),
        subtitle: Text(value, style: theme.textTheme.bodyMedium),
        trailing: onTap != null
            ? Icon(LucideIcons.chevronRight, size: 18, color: theme.colorScheme.outline)
            : null,
        onTap: onTap,
      ),
    );
  }
}

/// Painter que dibuja una grilla simulando un mapa (sin dependencia de Google Maps).
class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // Lineas verticales.
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Lineas horizontales.
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
