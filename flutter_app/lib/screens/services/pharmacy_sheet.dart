import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/medicine.dart';

class PharmacySheet extends StatefulWidget {
  final void Function(String message) onOrdered;

  const PharmacySheet({super.key, required this.onOrdered});

  @override
  State<PharmacySheet> createState() => _PharmacySheetState();
}

class _PharmacySheetState extends State<PharmacySheet> {
  List<Medicine> _all = [];
  List<Medicine> _filtered = [];
  bool _loading = true;
  String _selectedCategory = 'All';

  static const _categories = [
    'All', 'Pain Relief', 'Antibiotics', 'Vitamins',
    'Digestive', 'Diabetes', 'Allergy', 'Supplements',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final meds = await ApiService.getMedicines();
      if (mounted) {
        setState(() {
          _all = meds;
          _filtered = meds;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter(String category) {
    setState(() {
      _selectedCategory = category;
      _filtered = category == 'All'
          ? _all
          : _all.where((m) => m.category == category).toList();
    });
  }

  Future<void> _order(Medicine medicine) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _OrderDialog(medicine: medicine),
    );
    if (result == null || !mounted) return;
    Navigator.pop(context);
    final qty = result['quantity'] as int;
    final address = result['address'] as String;
    final payment = result['payment'] as String;
    widget.onOrdered(
      'I want to order $qty x ${medicine.name} (${medicine.category}). '
      'Total: EGP ${(medicine.price * qty).toStringAsFixed(2)}. '
      'Delivery address: $address. Payment: $payment.',
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Pain Relief':
        return Icons.healing_rounded;
      case 'Antibiotics':
        return Icons.biotech_rounded;
      case 'Vitamins':
        return Icons.emoji_nature_rounded;
      case 'Digestive':
        return Icons.lunch_dining_rounded;
      case 'Diabetes':
        return Icons.monitor_heart_rounded;
      case 'Allergy':
        return Icons.air_rounded;
      case 'Supplements':
        return Icons.fitness_center_rounded;
      default:
        return Icons.medication_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Pain Relief':
        return Colors.orange;
      case 'Antibiotics':
        return Colors.green;
      case 'Vitamins':
        return Colors.yellow.shade700;
      case 'Digestive':
        return Colors.teal;
      case 'Diabetes':
        return Colors.blue;
      case 'Allergy':
        return Colors.purple;
      case 'Supplements':
        return Colors.indigo;
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_pharmacy_rounded,
                        color: Colors.green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pharmacy',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor)),
                      Text('${_filtered.length} medicines available',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Category filter
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => _filter(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.green
                            : (isDark
                                ? const Color(0xFF2A2A3E)
                                : AppColors.lightGray),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : (isDark
                                  ? Colors.white70
                                  : AppColors.textPrimary),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Medicine grid
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? Center(
                          child: Text('No medicines found',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : AppColors.textMuted)))
                      : GridView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _MedicineCard(
                            medicine: _filtered[i],
                            isDark: isDark,
                            icon: _categoryIcon(_filtered[i].category),
                            iconColor: _categoryColor(_filtered[i].category),
                            onOrder: () => _order(_filtered[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Medicine Card ─────────────────────────────────────────────────────────────

class _MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onOrder;

  const _MedicineCard({
    required this.medicine,
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF252538) : AppColors.surface;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const Spacer(),
                if (medicine.requiresPrescription)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text('Rx',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.red)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(medicine.name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(medicine.category,
                style: TextStyle(
                    fontSize: 11,
                    color: iconColor,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(medicine.description,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(
              children: [
                Text('EGP ${medicine.price.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                const Spacer(),
                GestureDetector(
                  onTap: medicine.inStock ? onOrder : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: medicine.inStock
                          ? Colors.green
                          : AppColors.lightGray,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      medicine.inStock ? 'Order' : 'Out',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: medicine.inStock
                            ? Colors.white
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Order Dialog ──────────────────────────────────────────────────────────────

class _OrderDialog extends StatefulWidget {
  final Medicine medicine;
  const _OrderDialog({required this.medicine});

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  final _addressCtrl = TextEditingController();
  int _quantity = 1;
  String _payment = 'Cash';

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.medicine.price * _quantity;

    return AlertDialog(
      title: Text('Order ${widget.medicine.name}',
          style:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quantity
          Row(
            children: [
              const Text('Quantity:',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              _QtyButton(
                icon: Icons.remove,
                onTap: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$_quantity',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              _QtyButton(
                icon: Icons.add,
                onTap: () => setState(() => _quantity++),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Delivery address
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Delivery Address',
              hintText: 'Enter your delivery address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            minLines: 1,
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Payment method
          const Text('Payment Method:',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              _PaymentChip(
                label: 'Cash',
                icon: Icons.money_rounded,
                selected: _payment == 'Cash',
                onTap: () => setState(() => _payment = 'Cash'),
              ),
              const SizedBox(width: 10),
              _PaymentChip(
                label: 'Card',
                icon: Icons.credit_card_rounded,
                selected: _payment == 'Card',
                onTap: () => setState(() => _payment = 'Card'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('Total:',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('EGP ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: Size.zero),
          onPressed: _addressCtrl.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, {
                    'quantity': _quantity,
                    'address': _addressCtrl.text.trim(),
                    'payment': _payment,
                  }),
          child: const Text('Place Order'),
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.secondary.withValues(alpha: 0.1)
              : AppColors.lightGray,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap != null ? AppColors.secondary : AppColors.textMuted),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : AppColors.lightGray,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
