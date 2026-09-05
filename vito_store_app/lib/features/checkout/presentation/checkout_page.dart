import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/env.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/cart_controller.dart';
import '../data/checkout_repository.dart';

/// Metodos de pago disponibles.
enum PaymentMethod { stripe, mercadopago, spei }

/// Extension con etiquetas legibles para [PaymentMethod].
extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.stripe:
        return 'Stripe (tarjeta)';
      case PaymentMethod.mercadopago:
        return 'MercadoPago';
      case PaymentMethod.spei:
        return 'SPEI (transferencia)';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.stripe:
        return LucideIcons.creditCard;
      case PaymentMethod.mercadopago:
        return LucideIcons.wallet;
      case PaymentMethod.spei:
        return LucideIcons.landmark;
    }
  }
}

/// Formatea un precio en MXN.
String _formatPrice(double amount) {
  return '\$${amount.toStringAsFixed(2)} MXN';
}

/// Pagina de checkout multi-paso.
///
/// Paso 1: Direccion de envio.
/// Paso 2: Metodo de pago (Stripe / MercadoPago / SPEI).
/// Paso 3: Resumen de orden + boton de pago.
/// Estado de exito: muestra numero de orden y enlace a /mis-transacciones.
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({this.success = false, super.key});

  final bool success;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  int _currentStep = 0;
  PaymentMethod _paymentMethod = PaymentMethod.stripe;
  bool _isProcessing = false;
  String? _error;
  String? _orderNumber;

  // Metodos de pago habilitados (cargados desde el backend).
  Set<String> _enabledMethods = {'stripe'};
  bool _methodsLoaded = false;

  // Opciones de envio.
  List<ShippingOption> _shippingOptions = [];
  ShippingOption? _selectedShipping;
  bool _loadingShipping = false;

  // Controllers de formulario de envio.
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-llenar nombre si hay usuario autenticado.
    Future.microtask(() {
      final user = ref.read(authControllerProvider).user;
      if (user != null && mounted) {
        final fullName = user.fullName.isNotEmpty ? user.fullName : user.email;
        if (_fullNameController.text.isEmpty) {
          _fullNameController.text = fullName;
        }
        if (_phoneController.text.isEmpty && user.phone != null) {
          _phoneController.text = user.phone!;
        }
      }
      _loadPaymentMethods();
    });
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final repo = ref.read(checkoutRepositoryProvider);
      final methods = await repo.getAvailablePaymentMethods();
      if (mounted) {
        setState(() {
          _enabledMethods = methods;
          _methodsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _methodsLoaded = true);
    }
  }

  Future<void> _loadShippingOptions() async {
    final zip = _zipController.text.trim();
    if (zip.isEmpty) return;
    setState(() => _loadingShipping = true);
    try {
      final repo = ref.read(checkoutRepositoryProvider);
      final options = await repo.getShippingOptions(zipCode: zip);
      if (mounted) {
        setState(() {
          _shippingOptions = options;
          _selectedShipping = options.isNotEmpty ? options.first : null;
          _loadingShipping = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingShipping = false);
    }
  }

  bool _isMethodEnabled(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.stripe:
        return _enabledMethods.contains('stripe');
      case PaymentMethod.mercadopago:
        return _enabledMethods.contains('mercadopago');
      case PaymentMethod.spei:
        return _enabledMethods.contains('spei');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.success || _orderNumber != null) {
      return _buildSuccess(context);
    }

    final cart = ref.watch(cartControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: cart.isEmpty
          ? EmptyCheckoutState(onAction: () => context.go('/tienda'))
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: _onStepContinue,
              onStepCancel: _onStepCancel,
              onStepTapped: (step) => setState(() => _currentStep = step),
              controlsBuilder: _controlsBuilder,
              steps: [
                _shippingStep(context),
                _paymentStep(context),
                _summaryStep(context, cart),
              ],
            ),
    );
  }

  // --- Stepper steps ---

  Step _shippingStep(BuildContext context) {
    return Step(
      title: const Text('Direccion de envio'),
      content: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(LucideIcons.user),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Telefono',
                prefixIcon: Icon(LucideIcons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Calle y numero',
                prefixIcon: Icon(LucideIcons.mapPin),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _zipController,
              decoration: const InputDecoration(labelText: 'Codigo postal'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              onChanged: (v) {
                if (v.trim().length >= 5) {
                  _loadShippingOptions();
                }
              },
            ),
            // Opciones de envio
            if (_loadingShipping) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
            if (!_loadingShipping && _shippingOptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Metodo de envio',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              ..._shippingOptions.map((option) => RadioListTile<ShippingOption>(
                    value: option,
                    groupValue: _selectedShipping,
                    title: Text(option.name),
                    subtitle: Text(option.estimatedDays),
                    secondary: Text(
                      option.cost > 0 ? _formatPrice(option.cost) : 'Gratis',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onChanged: (v) => setState(() => _selectedShipping = v),
                  )),
            ],
          ],
        ),
      ),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
    );
  }

  Step _paymentStep(BuildContext context) {
    return Step(
      title: const Text('Metodo de pago'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_methodsLoaded)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            ...PaymentMethod.values.map((method) {
              final enabled = _isMethodEnabled(method);
              return ListTile(
                enabled: enabled,
                leading: Icon(method.icon),
                title: Text(method.label),
                subtitle: enabled ? null : const Text('No disponible por el momento'),
                trailing: Radio<PaymentMethod>(
                  value: method,
                  // ignore: deprecated_member_use
                  groupValue: _paymentMethod,
                  // ignore: deprecated_member_use
                  onChanged: enabled ? (v) => setState(() => _paymentMethod = v!) : null,
                ),
                onTap: enabled ? () => setState(() => _paymentMethod = method) : null,
              );
            }),
        ],
      ),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
    );
  }

  Step _summaryStep(BuildContext context, CartState cart) {
    final shippingCost = _selectedShipping?.cost ?? 0;
    final grandTotal = cart.totalAmount + shippingCost;
    return Step(
      title: const Text('Resumen y pago'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de items.
          ...cart.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity}x ${item.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(_formatPrice(item.subtotal)),
                  ],
                ),
              )),
          const Divider(),
          _summaryRow(context, 'Subtotal', _formatPrice(cart.subtotal)),
          const SizedBox(height: 4),
          if (_selectedShipping != null) ...[
            _summaryRow(context, 'Envio (${_selectedShipping!.name})',
                _selectedShipping!.cost > 0 ? _formatPrice(_selectedShipping!.cost) : 'Gratis'),
            const SizedBox(height: 4),
          ],
          _summaryRow(context, 'Total', _formatPrice(grandTotal), isTotal: true),
          const SizedBox(height: 16),
          // Metodo de pago seleccionado.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_paymentMethod.icon, size: 20),
                const SizedBox(width: 8),
                Text('Pago via: ${_paymentMethod.label}'),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      isActive: _currentStep >= 2,
      state: _currentStep == 2 ? StepState.indexed : StepState.indexed,
    );
  }

  // --- Stepper controls ---

  Widget _controlsBuilder(BuildContext context, ControlsDetails details) {
    final isLastStep = _currentStep == 2;
    final cart = ref.read(cartControllerProvider);
    final shippingCost = _selectedShipping?.cost ?? 0;
    final grandTotal = cart.totalAmount + shippingCost;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
            FilledButton(
            onPressed: _isProcessing ? null : details.onStepContinue,
            child: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isLastStep ? 'Pagar ${_formatPrice(grandTotal)}' : 'Continuar'),
          ),
          if (_currentStep > 0) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: details.onStepCancel,
              child: const Text('Atras'),
            ),
          ],
        ],
      ),
    );
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      // Validar formulario de envio.
      if (!_formKey.currentState!.validate()) return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      return;
    }
    // Paso final: procesar pago.
    _processPayment();
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // --- Procesamiento de pago ---

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final repo = ref.read(checkoutRepositoryProvider);

      // 1. Crear la orden (el backend vacia el carrito en el servidor).
      final order = await repo.createOrder(
        shippingAddress: {
          'fullName': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'zip': _zipController.text.trim(),
        },
        paymentMethod: _paymentMethod.name,
        shippingMethodId: _selectedShipping?.id,
      );
      final orderId = order['id']?.toString() ?? '';
      final orderNumber =
          order['orderNumber']?.toString() ?? orderId;

      // 2. Procesar pago segun el metodo seleccionado.
      if (_paymentMethod == PaymentMethod.stripe &&
          Env.stripePublicKey.isNotEmpty &&
          orderId.isNotEmpty) {
        await _processStripePayment(repo, orderId, orderNumber);
      } else if (_paymentMethod == PaymentMethod.mercadopago &&
          orderId.isNotEmpty) {
        await _processMercadoPagoPayment(repo, orderId, orderNumber);
      } else if (_paymentMethod == PaymentMethod.spei &&
          orderId.isNotEmpty) {
        await _processSpeiPayment(repo, orderId, orderNumber);
      }

      // 3. Sincronizar carrito (el backend ya lo vacio) y mostrar exito.
      await _syncCart();

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _orderNumber = orderNumber.isNotEmpty ? orderNumber : '--';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Procesa pago con Stripe PaymentSheet.
  Future<void> _processStripePayment(
    CheckoutRepository repo, String orderId, String orderNumber) async {
    final clientSecret = await repo.getStripePaymentIntent(orderId: orderId);
    if (clientSecret.isEmpty) {
      throw Exception('No se pudo iniciar el pago con Stripe');
    }
    await stripe.Stripe.instance.initPaymentSheet(
      paymentSheetParameters: stripe.SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'VITO Technologies',
        style: ThemeMode.system,
      ),
    );
    try {
      await stripe.Stripe.instance.presentPaymentSheet();
    } on stripe.StripeException catch (e) {
      await _syncCart();
      setState(() {
        _isProcessing = false;
        _error =
            'Pago no completado. Tu orden $orderNumber quedo registrada como pendiente.';
        if (e.error.code != stripe.FailureCode.Canceled) {
          _error = 'Error en el pago: ${e.error.localizedMessage ?? e.error.message ?? e}';
        }
      });
      rethrow;
    }
  }

  /// Procesa pago con MercadoPago: abre la URL de checkout en el navegador.
  Future<void> _processMercadoPagoPayment(
    CheckoutRepository repo, String orderId, String orderNumber) async {
    final mpResult = await repo.getMercadoPagoPreference(orderId: orderId);
    if (!mpResult.isValid) {
      throw Exception('No se pudo iniciar el pago con MercadoPago');
    }
    // Abrir la URL de MercadoPago en el navegador del dispositivo.
    final uri = Uri.parse(mpResult.initPoint);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('No se pudo abrir MercadoPago. '
          'Tu orden $orderNumber quedo registrada como pendiente.');
    }
  }

  /// Procesa pago con SPEI: muestra los datos bancarios para transferencia.
  Future<void> _processSpeiPayment(
    CheckoutRepository repo, String orderId, String orderNumber) async {
    final spei = await repo.getSpeiPaymentData(orderId: orderId);
    if (!spei.isValid) {
      // El backend no tiene endpoint SPEI: la orden queda pendiente.
      return;
    }
    // Mostrar dialog con los datos bancarios.
    if (mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Pago por SPEI'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Realiza la transferencia con los siguientes datos:'),
              const SizedBox(height: 16),
              _speiDataRow('Banco', spei.bank),
              _speiDataRow('CLABE', spei.clabe),
              _speiDataRow('Monto', _formatPrice(spei.amount)),
              _speiDataRow('Referencia', spei.reference),
              _speiDataRow('Concepto', spei.concept),
              const SizedBox(height: 12),
              const Text(
                'Tu orden quedara pendiente hasta que confirmemos el pago.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  Widget _speiDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Future<void> _syncCart() async {
    try {
      await ref.read(cartControllerProvider.notifier).load();
    } catch (_) {
      // El carrito ya se vaci en el servidor; un error de red aqu no es crtico.
    }
  }

  // --- Vista de exito ---

  Widget _buildSuccess(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedido confirmado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.checkCircle,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Pedido realizado con exito!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Numero de orden: $_orderNumber',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Recibiras un correo de confirmacion pronto.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.go('/mis-transacciones'),
                icon: const Icon(LucideIcons.package),
                label: const Text('Ver mis transacciones'),
              ),
              const SizedBox(height: 12),
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

  // --- Helpers ---

  Widget _summaryRow(BuildContext context, String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isTotal
              ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Estado vacio cuando el carrito esta vacio al llegar al checkout.
class EmptyCheckoutState extends StatelessWidget {
  const EmptyCheckoutState({required this.onAction, super.key});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.shoppingCart, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text(
              'No hay items en el carrito para checkout.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              child: const Text('Explorar productos'),
            ),
          ],
        ),
      ),
    );
  }
}
