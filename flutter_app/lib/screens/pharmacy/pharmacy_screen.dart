import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/medicine.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/services/api_service.dart';
import 'cart_screen.dart';

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  static const _categories = [
    'All', 'Pain Relief', 'Antibiotics', 'Vitamins',
    'Digestive', 'Diabetes', 'Allergy', 'Supplements',
  ];

  List<Medicine> _all = [];
  List<Medicine> _filtered = [];
  bool _loading = true;
  String _selected = 'All';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
      _selected = category;
      _applyFilters();
    });
  }

  void _applyFilters() {
    var result = _all;
    if (_selected != 'All') {
      result = result
          .where((m) => m.category.toLowerCase() == _selected.toLowerCase())
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((m) =>
              m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              m.description.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    _filtered = result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_rounded,
                    color: Colors.white),
                onPressed: cart.itemCount > 0
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CartScreen()),
                        )
                    : null,
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  setState(() { _searchQuery = v; _applyFilters(); }),
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _searchQuery = '';
                          _applyFilters();
                        }),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),

          // Category filter
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final sel = cat == _selected;
                return GestureDetector(
                  onTap: () => _filter(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.secondary
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
                        color: sel
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.medication_outlined,
                                size: 56,
                                color: isDark
                                    ? Colors.white24
                                    : AppColors.lightGray),
                            const SizedBox(height: 12),
                            Text('No medicines found',
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : AppColors.textMuted)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _MedicineCard(
                          medicine: _filtered[i],
                          isDark: isDark,
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: cart.itemCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
              backgroundColor: AppColors.secondary,
              icon: const Icon(Icons.shopping_cart_rounded,
                  color: Colors.white),
              label: Text(
                '${cart.itemCount} items · EGP ${cart.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}

// ── Medicine Card ─────────────────────────────────────────────────────────────

class _MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final bool isDark;

  const _MedicineCard({required this.medicine, required this.isDark});

  Color get _categoryColor {
    switch (medicine.category.toLowerCase()) {
      case 'pain relief':
        return const Color(0xFFDC2626);
      case 'antibiotics':
        return const Color(0xFF7C3AED);
      case 'vitamins':
        return const Color(0xFFD97706);
      case 'digestive':
        return const Color(0xFF0891B2);
      case 'diabetes':
        return const Color(0xFF16A34A);
      case 'allergy':
        return const Color(0xFFDB2777);
      case 'supplements':
        return const Color(0xFF059669);
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantityOf(medicine.id);
    final inCart = qty > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medicine image / category color bar
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: medicine.imageUrl != null
                      ? Image.network(
                          medicine.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _FallbackIcon(
                              color: _categoryColor),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return _FallbackIcon(color: _categoryColor);
                          },
                        )
                      : _FallbackIcon(color: _categoryColor),
                ),
                if (medicine.requiresPrescription)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Rx',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                if (!medicine.inStock)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.black54,
                      child: const Text('Out of Stock',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      medicine.category,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _categoryColor),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EGP ${medicine.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Add / qty controls
                  if (!medicine.inStock)
                    Container(
                      width: double.infinity,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.lightGray,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Unavailable',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    )
                  else if (!inCart)
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.read<CartProvider>().add(medicine),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: AppColors.secondary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Add to Cart',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    )
                  else
                    Row(
                      children: [
                        _QtyBtn(
                          icon: Icons.remove_rounded,
                          onTap: () => context
                              .read<CartProvider>()
                              .decrement(medicine.id),
                        ),
                        Expanded(
                          child: Text('$qty',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                        _QtyBtn(
                          icon: Icons.add_rounded,
                          onTap: () =>
                              context.read<CartProvider>().add(medicine),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final Color color;
  const _FallbackIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      color: color.withValues(alpha: 0.1),
      child: Center(
        child: Icon(Icons.medication_rounded,
            color: color.withValues(alpha: 0.5), size: 48),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 16, color: AppColors.secondary),
      ),
    );
  }
}
