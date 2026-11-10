import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  PaymentMethodsAvailability _availableMethods =
      const PaymentMethodsAvailability(stripe: true);
  bool _methodsLoaded = false;

  // Opciones de envio (cotizacion real del backend).
  List<ShippingOption> _shippingOptions = [];
  ShippingOption? _selectedShipping;
  bool _loadingShipping = false;
  String? _shippingError;

  // Controllers del formulario de envio (campos estructurados que exige el
  // backend: recipient, phone, street, exteriorNumber, interiorNumber?,
  // neighborhood, city, state, postalCode).
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _exteriorController = TextEditingController();
  final _interiorController = TextEditingController();
  final _neighborhoodController = TextEditingController();
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
      final availability = await repo.getAvailablePaymentMethods();
      if (mounted) {
        setState(() {
          _availableMethods = availability;
          _methodsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _methodsLoaded = true);
    }
  }

  /// Direccion estructurada completa para la cotizacion/orden, o null si
  /// faltan campos obligatorios (evita peticiones inutiles).
  ShippingDetails? get _shippingDetails {
    final recipient = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final street = _streetController.text.trim();
    final exterior = _exteriorController.text.trim();
    final neighborhood = _neighborhoodController.text.trim();
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();
    final zip = _zipController.text.trim();
    if (recipient.isEmpty ||
        phone.isEmpty ||
        street.isEmpty ||
        exterior.isEmpty ||
        neighborhood.isEmpty ||
        city.isEmpty ||
        state.isEmpty ||
        zip.isEmpty) {
      return null;
    }
    return ShippingDetails(
      recipient: recipient,
      phone: phone,
      street: street,
      exteriorNumber: exterior,
      interiorNumber: _interiorController.text.trim(),
      neighborhood: neighborhood,
      city: city,
      state: state,
      postalCode: zip,
    );
  }

  Future<void> _loadShippingOptions() async {
    final details = _shippingDetails;
    if (details == null) return;
    setState(() {
      _loadingShipping = true;
      _shippingError = null;
    });
    try {
      final repo = ref.read(checkoutRepositoryProvider);
      final result = await repo.getShippingOptions(shippingDetails: details);
      if (mounted) {
        setState(() {
          _shippingOptions = result.options;
          _selectedShipping =
              result.options.isNotEmpty ? result.options.first : null;
          _loadingShipping = false;
          _shippingError = result.options.isEmpty
              ? 'No hay servicios de envio disponibles para esta zona. '
                  'Reintenta con otra direccion o contacta a soporte.'
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e is DioException
            ? (e.response?.data is Map<String, dynamic>
                    ? (e.response!.data['error']?.toString() ??
                        'No se pudo cotizar el envio')
                    : 'No se pudo cotizar el envio')
            : 'No se pudo cotizar el envio. Revisa los datos e intenta de nuevo.';
        setState(() {
          _loadingShipping = false;
          _shippingError = msg;
        });
      }
    }
  }

  bool _isMethodEnabled(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.stripe:
        return _availableMethods.stripe;
      case PaymentMethod.mercadopago:
      case PaymentMethod.spei:
        // El backend solo tiene Stripe/paypal/spei en /payments/available y
        // los endpoints de cobro de MP/SPEI no existen todavia.
        return false;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _exteriorController.dispose();
    _interiorController.dispose();
    _neighborhoodController.dispose();
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
                labelText: 'Nombre completo (quien recibe)',
                prefixIcon: Icon(LucideIcons.user),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              onChanged: (_) => _onShippingFieldChanged(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Telefono',
                prefixIcon: Icon(LucideIcons.phone),
              ),
              keyboardType: TextInputType.phone,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              onChanged: (_) => _onShippingFieldChanged(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _streetController,
              decoration: const InputDecoration(
                labelText: 'Calle',
                prefixIcon: Icon(LucideIcons.mapPin),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              onChanged: (_) => _onShippingFieldChanged(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _exteriorController,
                    decoration: const InputDecoration(labelText: 'No. exterior'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    onChanged: (_) => _onShippingFieldChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _interiorController,
                    decoration:
                        const InputDecoration(labelText: 'No. interior (opcional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _neighborhoodController,
              decoration: const InputDecoration(labelText: 'Colonia'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              onChanged: (_) => _onShippingFieldChanged(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    onChanged: (_) => _onShippingFieldChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    onChanged: (_) => _onShippingFieldChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _zipController,
              decoration: const InputDecoration(labelText: 'Codigo postal'),
              keyboardType: TextInputType.number,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => (v == null || v.trim().length < 5) ? '5 digitos' : null,
              onChanged: (v) => _onShippingFieldChanged(),
            ),
            // Cotizacion de envio
            if (_loadingShipping) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ] else if (_shippingError != null) ...[
              const SizedBox(height: 16),
              Text(
                _shippingError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loadShippingOptions,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: const Text('Reintentar cotizacion'),
              ),
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
                    // ignore: deprecated_member_use
                    groupValue: _selectedShipping,
                    title: Text(option.name),
                    subtitle: option.carrierCode != null
                        ? Text('Transportista: ${option.carrierCode}')
                        : null,
                    secondary: Text(
                      option.cost > 0 ? _formatPrice(option.cost) : 'Gratis',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    // ignore: deprecated_member_use
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

  /// Recotiza el envio cuando el formulario pasa a estar completo.
  ///
  /// Se llama en cada cambio de campo; solo dispara la peticion cuando la
  /// direccion estructurada esta completa y hace debounce por frame.
  bool _shippingQuotePending = false;

  void _onShippingFieldChanged() {
    if (_shippingDetails == null || _loadingShipping) return;
    if (_shippingQuotePending) return;
    _shippingQuotePending = true;
    Future<void>.delayed(const Duration(milliseconds: 500)).then((_) {
      _shippingQuotePending = false;
      if (mounted && _shippingDetails != null && !_isProcessing) {
        _loadShippingOptions();
      }
    });
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
              Widget? subtitle;
              if (!enabled) {
                subtitle = const Text('Proximamente en el backend');
              } else if (method == PaymentMethod.stripe &&
                  Env.stripePublicKey.isEmpty) {
                subtitle = const Text(
                    'La instalacion no tiene la llave publica de Stripe: '
                    'la orden se creara pero el cobro se completa desde la web.');
              }
              return ListTile(
                enabled: enabled,
                leading: Icon(method.icon),
                title: Text(method.label),
                subtitle: subtitle,
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
      final details = _shippingDetails;
      if (details == null) {
        throw Exception('Faltan datos de envio. Completa el paso 1.');
      }

      // 1. Crear la orden con el contrato real del backend (shippingAddress y
      //    billingAddress como strings + shippingDetails estructurados + el
      //    quoteToken del envio elegido). El backend recalcula el total y
      //    vacia el carrito en el servidor.
      final order = await repo.createOrder(
        shippingAddress: details.toString(),
        billingAddress: details.toString(),
        shippingDetails: details,
        shippingQuoteToken: _selectedShipping?.quoteToken,
      );
      final orderId = order['id']?.toString() ?? '';
      final orderNumber = order['orderNumber']?.toString() ?? orderId;
      if (orderId.isEmpty) {
        throw Exception('El backend no devolvio la orden; intenta de nuevo.');
      }

      // 2. Cobrar. Hoy el unico metodo implementado y activo en el backend
      //    es Stripe (MercadoPago/SPEI estan deshabilitados / sin endpoints).
      if (_paymentMethod == PaymentMethod.stripe) {
        if (Env.stripePublicKey.isEmpty) {
          throw Exception(
              'El pago con tarjeta no esta disponible en esta instalacion '
              '(falta la llave publica de Stripe). Tu orden $orderNumber '
              'quedo registrada y puedes pagarla desde la web.');
        }
        await _processStripePayment(repo, orderId, orderNumber);
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
