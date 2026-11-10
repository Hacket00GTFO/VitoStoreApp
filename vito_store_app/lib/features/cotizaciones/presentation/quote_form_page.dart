import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../account/data/account_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/quote_repository.dart';

/// Tipos de servicio especializado (enum del backend: SpecializedServiceType).
const List<(String, String)> quoteServiceTypes = [
  ('SOPORTE', 'Soporte Tecnico'),
  ('INFRAESTRUCTURA', 'Redes e Infraestructura'),
  ('ESPECIALIZADAS', 'Soluciones Especializadas'),
  ('ELEVACION', 'Plataformas de Elevacion'),
];

/// Opciones de tipo de proyecto por servicio (espejo de la web:
/// `SpecializedQuoteModal.projectTypeOptions`).
const Map<String, List<(String, String)>> quoteProjectTypes = {
  'SOPORTE': [
    ('mantenimiento', 'Mantenimiento preventivo'),
    ('reparacion', 'Reparacion'),
    ('soporte', 'Soporte tecnico'),
    ('poliza', 'Poliza de soporte'),
  ],
  'INFRAESTRUCTURA': [
    ('nuevo', 'Proyecto nuevo'),
    ('expansion', 'Expansion existente'),
    ('migracion', 'Migracion'),
    ('optimizacion', 'Optimizacion'),
  ],
  'ESPECIALIZADAS': [
    ('consultoria', 'Consultoria'),
    ('implementacion', 'Implementacion'),
    ('integracion', 'Integracion de sistemas'),
    ('desarrollo', 'Desarrollo a medida'),
  ],
  'ELEVACION': [
    ('renta', 'Renta de equipo'),
    ('venta', 'Compra de equipo'),
    ('mantenimiento', 'Mantenimiento'),
    ('capacitacion', 'Capacitacion de operadores'),
  ],
};

const List<(String, String)> quoteUrgencyOptions = [
  ('LOW', 'Baja'),
  ('NORMAL', 'Normal'),
  ('HIGH', 'Alta'),
  ('URGENT', 'Urgente'),
];

/// Formulario de cotizacion especializada (megaplan Fase 2.2).
///
/// Consumo `POST /specialized-quotes` (con sesion) o `/public` (sin sesion),
/// devolviendo el folio COT-2026-XXXX. Al enviarse con exito se ofrece
/// navegar a Cuenta (tab Cotizaciones) con el historial invalidado.
class QuoteFormPage extends ConsumerStatefulWidget {
  const QuoteFormPage({
    this.initialServiceType,
    this.initialServiceName,
    super.key,
  });

  final String? initialServiceType;
  final String? initialServiceName;

  @override
  ConsumerState<QuoteFormPage> createState() => _QuoteFormPageState();
}

class _QuoteFormPageState extends ConsumerState<QuoteFormPage> {
  final _formKey = GlobalKey<FormState>();
  late String _serviceType;
  late final TextEditingController _serviceNameCtrl;
  final _clientNameCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _projectType = '';
  String _urgency = 'NORMAL';
  DateTime? _preferredDate;

  bool _submitting = false;
  String? _createdQuoteNumber;

  @override
  void initState() {
    super.initState();
    // Acepta el serviceType que llega por query (o null); si no es uno de los
    // valores validos del backend, usa SOPORTE.
    final valid = quoteServiceTypes
        .any(((String, String) t) => t.$1 == widget.initialServiceType);
    _serviceType = valid ? widget.initialServiceType! : 'SOPORTE';
    _serviceNameCtrl = TextEditingController(text: widget.initialServiceName ?? '');
    _projectType = quoteProjectTypes[_serviceType]?.first.$1 ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillContact());
  }

  /// Precarga nombre/email/telefono del perfil (`service-request-data`).
  Future<void> _prefillContact() async {
    final auth = ref.read(authControllerProvider);
    if (auth.user != null) {
      _clientNameCtrl.text =
          auth.user!.fullName.isNotEmpty ? auth.user!.fullName : _clientNameCtrl.text;
      _clientEmailCtrl.text = _clientEmailCtrl.text.isEmpty
          ? (auth.user!.email)
          : _clientEmailCtrl.text;
      if (_clientPhoneCtrl.text.isEmpty && auth.user!.phone != null) {
        _clientPhoneCtrl.text = auth.user!.phone!;
      }
    }
    // El backend puede tener datos mas completos (companyName en perfil).
    try {
      final data = await ref.read(quoteContactDataProvider.future);
      if (!mounted) return;
      setState(() {
        if (_clientNameCtrl.text.isEmpty && data.clientName != null) {
          _clientNameCtrl.text = data.clientName!;
        }
        if (_clientEmailCtrl.text.isEmpty && data.clientEmail != null) {
          _clientEmailCtrl.text = data.clientEmail!;
        }
        if (_clientPhoneCtrl.text.isEmpty && data.clientPhone != null) {
          _clientPhoneCtrl.text = data.clientPhone!;
        }
        if (_companyNameCtrl.text.isEmpty && data.companyName != null) {
          _companyNameCtrl.text = data.companyName!;
        }
      });
    } catch (_) {
      // Prefill best-effort.
    }
  }

  @override
  void dispose() {
    _serviceNameCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientEmailCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _companyNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _budgetCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final isAuthenticated =
        ref.read(authControllerProvider).isAuthenticated;
    try {
      final repo = ref.read(quoteRepositoryProvider);
      final quote = await repo.createQuote(
        serviceType: _serviceType,
        serviceName: _serviceNameCtrl.text.trim(),
        clientName: _clientNameCtrl.text.trim(),
        clientEmail: _clientEmailCtrl.text.trim(),
        clientPhone: _clientPhoneCtrl.text.trim(),
        companyName: _companyNameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        projectType: _projectType,
        urgency: _urgency,
        budget: _budgetCtrl.text.trim(),
        preferredDate: _preferredDate != null
            ? '${_preferredDate!.year.toString().padLeft(4, '0')}-${_preferredDate!.month.toString().padLeft(2, '0')}-${_preferredDate!.day.toString().padLeft(2, '0')}'
            : null,
        location: _locationCtrl.text.trim(),
        authenticated: isAuthenticated,
      );
      // El historial de la app cachea 4 listas: invalidar para que la nueva
      // cotizacion aparezca en el tab Cotizaciones de /mis-transacciones.
      ref.invalidate(accountHistoryProvider);
      if (mounted) {
        setState(() => _createdQuoteNumber =
            quote.quoteNumber.isNotEmpty ? quote.quoteNumber : 'COT-—');
      }
    } catch (e) {
      if (!mounted) return;
      String message = 'No se pudo enviar la cotizacion. Intenta de nuevo.';
      String? details;
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          details = data['error']?.toString();
        }
        if (e.response?.statusCode == 429) {
          message =
              'Demasiadas cotizaciones desde esta red. Espera unos minutos.';
        } else if (e.response?.statusCode == 400) {
          message = 'Valida los campos: faltan datos requeridos.';
        }
      }
      if (details != null && details.isNotEmpty) {
        message = '$message ($details)';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_createdQuoteNumber != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cotizacion enviada')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.badgeCheck,
                    size: 64, color: Color(0xFF16A34A)),
                const SizedBox(height: 24),
                Text('Cotizacion registrada',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  'Folio $_createdQuoteNumber',
                  style: theme.textTheme.titleMedium?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Un especialista la revisara y te contactara con la propuesta.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/mis-transacciones'),
                  icon: const Icon(LucideIcons.listChecks),
                  label: const Text('Ver mis cotizaciones'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final projectOptions =
        quoteProjectTypes[_serviceType] ?? const <(String, String)>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar cotizacion')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Datos del servicio',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _serviceType,
              decoration: const InputDecoration(
                labelText: 'Tipo de servicio',
                prefixIcon: Icon(LucideIcons.layers),
              ),
              items: [
                for (final (String value, String label) in quoteServiceTypes)
                  DropdownMenuItem(value: value, child: Text(label)),
              ],
              onChanged: (v) => setState(() {
                _serviceType = v ?? _serviceType;
                final options = quoteProjectTypes[_serviceType];
                _projectType = options?.first.$1 ?? '';
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _serviceNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Servicio requerido *',
                hintText: 'p.ej. Instalacion de red en sucursal Guadalajara',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Describe el servicio (requerido)'
                  : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            if (projectOptions.isNotEmpty)
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: projectOptions.any(((String, String) t) => t.$1 == _projectType)
                    ? _projectType
                    : projectOptions.first.$1,
                decoration: const InputDecoration(
                  labelText: 'Tipo de proyecto',
                  prefixIcon: Icon(LucideIcons.hammer),
                ),
                items: [
                  for (final (String value, String label) in projectOptions)
                    DropdownMenuItem(value: value, child: Text(label)),
                ],
                onChanged: (v) => setState(() => _projectType = v ?? ''),
              ),
            const SizedBox(height: 20),
            Text('Datos de contacto',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre completo *',
                prefixIcon: Icon(LucideIcons.user),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El nombre es requerido';
                if (v.trim().length < 2) return 'Minimo 2 caracteres';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientEmailCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo electronico *',
                prefixIcon: Icon(LucideIcons.mail),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El correo es requerido';
                }
                if (!v.trim().contains('@') || !v.trim().contains('.')) {
                  return 'Correo invalido';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientPhoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Telefono',
                prefixIcon: Icon(LucideIcons.phone),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _companyNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Empresa',
                prefixIcon: Icon(LucideIcons.building2),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            Text('Detalles del proyecto',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text('Urgencia', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              selected: {_urgency},
              segments: [
                for (final (String value, String label) in quoteUrgencyOptions)
                  ButtonSegment(value: value, label: Text(label)),
              ],
              onSelectionChanged: (s) => setState(() => _urgency = s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _budgetCtrl,
              decoration: const InputDecoration(
                labelText: 'Presupuesto estimado',
                hintText: 'p.ej. \$50,000 MXN',
                prefixIcon: Icon(LucideIcons.banknote),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha preferida de inicio',
                  prefixIcon: Icon(LucideIcons.calendar),
                  suffixIcon: Icon(LucideIcons.chevronDown),
                ),
                child: Text(
                  _preferredDate != null
                      ? '${_preferredDate!.day}/${_preferredDate!.month}/${_preferredDate!.year}'
                      : 'Sin preferencia',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Ubicacion del proyecto',
                prefixIcon: Icon(LucideIcons.mapPin),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 5,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Describe tu requerimiento',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.send),
              label: Text(_submitting ? 'Enviando...' : 'Enviar cotizacion'),
            ),
            const SizedBox(height: 8),
            Text(
              'Campos con * son requeridos. Responderemos a tu correo con el '
              'detalle. Puedes seguir el folio desde tu Cuenta.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _preferredDate = picked);
  }
}
