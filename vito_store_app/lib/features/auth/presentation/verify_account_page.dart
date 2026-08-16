import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'auth_controller.dart';

/// Pagina de verificacion de cuenta. Codigo de 6 digitos enviado por email.
class VerifyAccountPage extends ConsumerStatefulWidget {
  const VerifyAccountPage({super.key});

  @override
  ConsumerState<VerifyAccountPage> createState() => _VerifyAccountPageState();
}

class _VerifyAccountPageState extends ConsumerState<VerifyAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Email puede venir como query param desde registro.
    final email = GoRouterState.of(context).uri.queryParameters['email'];
    if (email != null) _emailCtrl.text = email;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.verifyEmail(email: _emailCtrl.text.trim(), code: _codeCtrl.text.trim());
      setState(() => _success = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta verificada. Ya puedes iniciar sesion.')),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) context.go('/login');
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_emailCtrl.text.isEmpty) return;
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.resendVerification(_emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Codigo reenviado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(LucideIcons.mailCheck, size: 48, color: Color(0xFF0066CC)),
                const SizedBox(height: 16),
                Text(
                  'Ingresa el codigo de 6 digitos enviado a tu email',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(LucideIcons.mail)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email invalido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Codigo de verificacion',
                    prefixIcon: Icon(LucideIcons.shieldCheck),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (v) => (v == null || v.length != 6) ? '6 digitos' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading || _success ? null : _verify,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verificar'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _resend,
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Reenviar codigo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
