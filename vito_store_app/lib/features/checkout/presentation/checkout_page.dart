import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
    });
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
            ),
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
        children: PaymentMethod.values.map((method) {
          return ListTile(
            leading: Icon(method.icon),
            title: Text(method.label),
            trailing: Radio<PaymentMethod>(
              value: method,
              // ignore: deprecated_member_use
              groupValue: _paymentMethod,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            onTap: () => setState(() => _paymentMethod = method),
          );
        }).toList(),
      ),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
    );
  }

  Step _summaryStep(BuildContext context, CartState cart) {
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
          _summaryRow(context, 'Total', _formatPrice(cart.totalAmount), isTotal: true),
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
                : Text(isLastStep ? 'Pagar ${_formatPrice(ref.read(cartControllerProvider).totalAmount)}' : 'Continuar'),
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
      final cart = ref.read(cartControllerProvider);

      // 1. Crear la orden.
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
      );

      // 2. Si es Stripe, crear PaymentIntent.
      if (_paymentMethod == PaymentMethod.stripe) {
        await repo.getStripePaymentIntent(
          orderId: order['id']?.toString() ?? '',
          amount: cart.totalAmount,
        );
      }

      // 3. Vaciar carrito y mostrar exito.
      await ref.read(cartControllerProvider.notifier).clear();

      setState(() {
        _isProcessing = false;
        _orderNumber = order['orderNumber']?.toString() ?? order['id']?.toString() ?? '--';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = e.toString();
      });
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
