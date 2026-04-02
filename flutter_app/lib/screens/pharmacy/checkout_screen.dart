import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/models/order.dart';
import '../../core/services/activity_service.dart';
import '../../core/services/location_service.dart';
import '../activity/activity_screen.dart';

const _promoCodes = {
  'HEALTH10': 0.10,
  'SAVE20': 0.20,
  'WELCOME15': 0.15,
};

const double _deliveryFee = 15.0;
const double _freeDeliveryThreshold = 200.0;

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _cardNameCtrl = TextEditingController();

  String _paymentMethod = 'cash';
  bool _detectingLocation = false;
  bool _placingOrder = false;
  double? _detectedLat;
  double? _detectedLng;
  double _discountRate = 0.0;
  String _appliedPromo = '';
  String _promoError = '';
  bool _promoApplied = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _promoCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _cardNameCtrl.dispose();
    super.dispose();
  }

  void _applyPromo() {
    final code = _promoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    if (_promoCodes.containsKey(code)) {
      setState(() {
        _discountRate = _promoCodes[code]!;
        _appliedPromo = code;
        _promoApplied = true;
        _promoError = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Promo applied! ${(_discountRate * 100).toInt()}% discount'),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 2),
      ));
    } else {
      setState(() {
        _promoError = 'Invalid promo code';
        _promoApplied = false;
        _discountRate = 0.0;
        _appliedPromo = '';
      });
    }
  }

  void _removePromo() {
    setState(() {
      _discountRate = 0.0;
      _appliedPromo = '';
      _promoApplied = false;
      _promoError = '';
      _promoCtrl.clear();
    });
  }

  bool _validateCardInputs() {
    final number = _cardNumberCtrl.text.replaceAll(' ', '');
    final expiry = _expiryCtrl.text;
    final cvv = _cvvCtrl.text;
    final name = _cardNameCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('Please enter the cardholder name', isError: true);
      return false;
    }
    if (number.length < 16) {
      _showSnack('Please enter a valid 16-digit card number', isError: true);
      return false;
    }
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiry)) {
      _showSnack('Please enter a valid expiry date (MM/YY)', isError: true);
      return false;
    }
    // Check expiry is not in the past
    final parts = expiry.split('/');
    final month = int.tryParse(parts[0]) ?? 0;
    final year = int.tryParse('20${parts[1]}') ?? 0;
    final now = DateTime.now();
    if (month < 1 || month > 12) {
      _showSnack('Invalid expiry month', isError: true);
      return false;
    }
    if (year < now.year || (year == now.year && month < now.month)) {
      _showSnack('Card has expired', isError: true);
      return false;
    }
    if (cvv.length < 3) {
      _showSnack('Please enter a valid CVV', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _detectLocation() async {
    setState(() => _detectingLocation = true);
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (pos != null) {
      setState(() {
        _detectedLat = pos.latitude;
        _detectedLng = pos.longitude;
        _addressCtrl.text =
            LocationService.formatCoords(pos.latitude, pos.longitude);
        _detectingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location detected'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _detectingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not detect location. Please enter address manually.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _placeOrder() async {
    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      _showSnack('Please enter a delivery address', isError: true);
      return;
    }
    if (_paymentMethod == 'card' && !_validateCardInputs()) return;

    setState(() => _placingOrder = true);
    final cart = context.read<CartProvider>();
    final subtotal = cart.total;
    final delivery =
        subtotal >= _freeDeliveryThreshold ? 0.0 : _deliveryFee;
    final discount = subtotal * _discountRate;
    final grandTotal = subtotal + delivery - discount;

    final order = PharmacyOrder(
      id: const Uuid().v4(),
      items: cart.items
          .map((ci) => OrderItem(
                medicineId: ci.medicine.id,
                name: ci.medicine.name,
                quantity: ci.quantity,
                unitPrice: ci.medicine.price,
              ))
          .toList(),
      totalPrice: grandTotal,
      deliveryAddress: address,
      lat: _detectedLat,
      lng: _detectedLng,
      paymentMethod: _paymentMethod,
      createdAt: DateTime.now(),
    );

    await ActivityService.addOrder(order);
    cart.clear();

    if (!mounted) return;
    setState(() => _placingOrder = false);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.check_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Order Placed!',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Your order of ${order.totalItems} item${order.totalItems > 1 ? 's' : ''} has been placed.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              'Total: EGP ${grandTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.secondary),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ActivityScreen()),
                  (route) => route.isFirst,
                );
              },
              style: ElevatedButton.styleFrom(minimumSize: Size.zero),
              child: const Text('View My Orders'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : const Color(0xFF16A34A),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();
    final subtotal = cart.total;
    final delivery =
        subtotal >= _freeDeliveryThreshold ? 0.0 : _deliveryFee;
    final discount = subtotal * _discountRate;
    final grandTotal = subtotal + delivery - discount;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: _placingOrder
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Placing your order...',
                      style:
                          TextStyle(fontSize: 14, color: AppColors.textMuted)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Delivery Address
                  _SectionLabel(label: 'Delivery Address', isDark: isDark),
                  const SizedBox(height: 10),
                  _Card(
                    isDark: isDark,
                    child: Column(
                      children: [
                        TextField(
                          controller: _addressCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Street, building, apartment, city...',
                            prefixIcon: Icon(Icons.location_on_rounded),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                _detectingLocation ? null : _detectLocation,
                            icon: _detectingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location_rounded,
                                    size: 18),
                            label: Text(_detectingLocation
                                ? 'Detecting...'
                                : 'Use My Location'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              side: const BorderSide(
                                  color: AppColors.secondary),
                              foregroundColor: AppColors.secondary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Promo Code
                  _SectionLabel(label: 'Promo Code', isDark: isDark),
                  const SizedBox(height: 10),
                  _Card(
                    isDark: isDark,
                    child: _promoApplied
                        ? Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF16A34A), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$_appliedPromo — ${(_discountRate * 100).toInt()}% off applied!',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF16A34A)),
                                ),
                              ),
                              TextButton(
                                onPressed: _removePromo,
                                child: const Text('Remove',
                                    style:
                                        TextStyle(color: AppColors.error)),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _promoCtrl,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        hintText: 'Enter promo code',
                                        prefixIcon: const Icon(
                                            Icons.local_offer_rounded,
                                            size: 18),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        errorText: _promoError.isEmpty
                                            ? null
                                            : _promoError,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _applyPromo,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                    ),
                                    child: const Text('Apply'),
                                  ),
                                ],
                              ),
                              if (_promoError.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 12, bottom: 4),
                                  child: Text(_promoError,
                                      style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 12)),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Payment Method
                  _SectionLabel(label: 'Payment Method', isDark: isDark),
                  const SizedBox(height: 10),
                  _Card(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _PaymentOption(
                          icon: Icons.money_rounded,
                          label: 'Cash on Delivery',
                          subtitle: 'Pay when your order arrives',
                          value: 'cash',
                          groupValue: _paymentMethod,
                          isDark: isDark,
                          onChanged: (v) =>
                              setState(() => _paymentMethod = v!),
                        ),
                        const Divider(height: 1),
                        _PaymentOption(
                          icon: Icons.credit_card_rounded,
                          label: 'Credit / Debit Card',
                          subtitle: 'Pay securely with your card',
                          value: 'card',
                          groupValue: _paymentMethod,
                          isDark: isDark,
                          onChanged: (v) =>
                              setState(() => _paymentMethod = v!),
                        ),
                      ],
                    ),
                  ),

                  // Card Form (shown only when card is selected)
                  if (_paymentMethod == 'card') ...[
                    const SizedBox(height: 16),
                    _SectionLabel(label: 'Card Details', isDark: isDark),
                    const SizedBox(height: 10),
                    _Card(
                      isDark: isDark,
                      child: Column(
                        children: [
                          _CardField(
                            controller: _cardNameCtrl,
                            label: 'Cardholder Name',
                            icon: Icons.person_outline_rounded,
                            keyboard: TextInputType.name,
                            inputFormatters: [],
                            hint: 'Name on card',
                          ),
                          const Divider(height: 1),
                          _CardField(
                            controller: _cardNumberCtrl,
                            label: 'Card Number',
                            icon: Icons.credit_card_rounded,
                            keyboard: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              _CardNumberFormatter(),
                            ],
                            hint: '0000 0000 0000 0000',
                            maxLength: 19,
                          ),
                          const Divider(height: 1),
                          Row(
                            children: [
                              Expanded(
                                child: _CardField(
                                  controller: _expiryCtrl,
                                  label: 'Expiry',
                                  icon: Icons.calendar_month_outlined,
                                  keyboard: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    _ExpiryFormatter(),
                                  ],
                                  hint: 'MM/YY',
                                  maxLength: 5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CardField(
                                  controller: _cvvCtrl,
                                  label: 'CVV',
                                  icon: Icons.lock_outline_rounded,
                                  keyboard: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  hint: '•••',
                                  maxLength: 4,
                                  obscure: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Your payment info is encrypted & secure',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white38
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Order Summary
                  _SectionLabel(label: 'Order Summary', isDark: isDark),
                  const SizedBox(height: 10),
                  _Card(
                    isDark: isDark,
                    child: Column(
                      children: [
                        ...cart.items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.medicine.name} × ${item.quantity}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white70
                                              : AppColors.textPrimary),
                                    ),
                                  ),
                                  Text(
                                    'EGP ${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            )),
                        const Divider(),
                        _SummaryRow(
                          label: 'Subtotal',
                          value: 'EGP ${subtotal.toStringAsFixed(2)}',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 4),
                        _SummaryRow(
                          label: delivery == 0
                              ? 'Delivery (Free!)'
                              : 'Delivery Fee',
                          value: delivery == 0
                              ? 'EGP 0.00'
                              : 'EGP ${delivery.toStringAsFixed(2)}',
                          isDark: isDark,
                          valueColor: delivery == 0
                              ? const Color(0xFF16A34A)
                              : null,
                        ),
                        if (discount > 0) ...[
                          const SizedBox(height: 4),
                          _SummaryRow(
                            label:
                                'Discount (${ (_discountRate * 100).toInt()}%)',
                            value: '- EGP ${discount.toStringAsFixed(2)}',
                            isDark: isDark,
                            valueColor: const Color(0xFF16A34A),
                          ),
                        ],
                        const Divider(),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                            Text(
                              'EGP ${grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: AppColors.secondary),
                            ),
                          ],
                        ),
                        if (subtotal < _freeDeliveryThreshold)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Add EGP ${(_freeDeliveryThreshold - subtotal).toStringAsFixed(0)} more for free delivery!',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD97706)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _placeOrder,
                      child: const Text('Place Order'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Secure checkout',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

// ── Summary Row ────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : AppColors.textMuted)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ??
                    (isDark ? Colors.white : AppColors.textPrimary))),
      ],
    );
  }
}

// ── Card Field ─────────────────────────────────────────────────────────────────

class _CardField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final List<TextInputFormatter> inputFormatters;
  final String hint;
  final int? maxLength;
  final bool obscure;

  const _CardField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.keyboard,
    required this.inputFormatters,
    required this.hint,
    this.maxLength,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: const UnderlineInputBorder(),
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      ),
    );
  }
}

// ── Input Formatters ──────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i != 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length > 4) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary));
  }
}

// ── Card Widget ───────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _Card({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Payment Option ────────────────────────────────────────────────────────────

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
  final String groupValue;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AppColors.secondary,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(icon,
              size: 20,
              color:
                  selected ? AppColors.secondary : AppColors.textMuted),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.white : AppColors.textPrimary)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
