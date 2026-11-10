import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'auth_controller.dart';

/// Pagina de login. Replica del LoginPage de la web.
///
/// Soporta 2FA: tras email+password, si el backend responde `requiresCode`,
/// muestra la pantalla de codigo de 6 digitos.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _requiresCode = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_requiresCode) {
        final requiresCode = await ref.read(authControllerProvider.notifier).login(
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text,
            );
        if (requiresCode) {
          setState(() => _requiresCode = true);
        } else if (mounted) {
          final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
          context.go(redirect ?? '/');
        }
      } else {
        await ref.read(authControllerProvider.notifier).verifyLoginCode(
              email: _emailCtrl.text.trim(),
              code: _codeCtrl.text.trim(),
            );
        if (mounted) {
          final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
          context.go(redirect ?? '/');
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Reenvia el codigo 2FA (`POST /account/login-resend`).
  Future<void> _resendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    try {
      await ref.read(authRepositoryProvider).resendLoginCode(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Codigo reenviado a $email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo reenviar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesion')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_requiresCode) ...[
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(LucideIcons.mail),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.isEmpty || !v.contains('@'))
                        ? 'Email invalido'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: 'Contrasena',
                      prefixIcon: const Icon(LucideIcons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Olvidaste tu contrasena?'),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Ingresa el codigo de 6 digitos enviado a ${_emailCtrl.text}',
                    style: Theme.of(context).textTheme.bodyMedium,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _loading ? null : _resendCode,
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: const Text('Reenviar codigo'),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_requiresCode ? 'Verificar' : 'Entrar'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No tienes cuenta?'),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Registrate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
