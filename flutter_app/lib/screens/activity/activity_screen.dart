import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/booking.dart';
import '../../core/models/order.dart';
import '../../core/services/activity_service.dart';
import 'booking_detail_screen.dart';
import 'order_detail_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Booking> _bookings = [];
  List<PharmacyOrder> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final b = await ActivityService.getBookings();
    final o = await ActivityService.getOrders();
    if (mounted) setState(() { _bookings = b; _orders = o; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Activity'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Bookings (${_bookings.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_pharmacy_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Orders (${_orders.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _BookingsList(
                  bookings: _bookings,
                  isDark: isDark,
                  onRefresh: _load,
                ),
                _OrdersList(
                  orders: _orders,
                  isDark: isDark,
                  onRefresh: _load,
                ),
              ],
            ),
    );
  }
}

// ── Bookings Tab ──────────────────────────────────────────────────────────────

class _BookingsList extends StatelessWidget {
  final List<Booking> bookings;
  final bool isDark;
  final VoidCallback onRefresh;

  const _BookingsList(
      {required this.bookings, required this.isDark, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return _EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No bookings yet',
        subtitle: 'Your doctor appointments will appear here',
        isDark: isDark,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (ctx, i) => _BookingCard(
          booking: bookings[i],
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              ctx,
              MaterialPageRoute(
                  builder: (_) =>
                      BookingDetailScreen(booking: bookings[i])),
            );
            onRefresh();
          },
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final bool isDark;
  final VoidCallback onTap;

  const _BookingCard(
      {required this.booking, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
              left: BorderSide(color: booking.statusColor, width: 3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.doctorName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                _StatusBadge(
                    label: booking.statusLabel, color: booking.statusColor),
              ],
            ),
            const SizedBox(height: 4),
            Text(booking.specialty,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.secondary)),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(
                    icon: Icons.calendar_today_rounded, label: booking.date),
                const SizedBox(width: 12),
                _InfoChip(
                    icon: Icons.access_time_rounded, label: booking.time),
                const Spacer(),
                Text(
                  'EGP ${booking.fee.toInt()}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Orders Tab ────────────────────────────────────────────────────────────────

class _OrdersList extends StatelessWidget {
  final List<PharmacyOrder> orders;
  final bool isDark;
  final VoidCallback onRefresh;

  const _OrdersList(
      {required this.orders, required this.isDark, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _EmptyState(
        icon: Icons.local_pharmacy_outlined,
        title: 'No orders yet',
        subtitle: 'Your pharmacy orders will appear here',
        isDark: isDark,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (ctx, i) => _OrderCard(
          order: orders[i],
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              ctx,
              MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(order: orders[i])),
            );
            onRefresh();
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final PharmacyOrder order;
  final bool isDark;
  final VoidCallback onTap;

  const _OrderCard(
      {required this.order, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM dd, yyyy • hh:mm a');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border(left: BorderSide(color: order.statusColor, width: 3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${order.id.substring(0, 8).toUpperCase()}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                _StatusBadge(
                    label: order.statusLabel, color: order.statusColor),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${order.totalItems} item${order.totalItems > 1 ? 's' : ''} · ${order.items.map((i) => i.name).join(', ')}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(
                    icon: Icons.location_on_rounded,
                    label: order.deliveryAddress.length > 25
                        ? '${order.deliveryAddress.substring(0, 25)}...'
                        : order.deliveryAddress),
                const Spacer(),
                Text(
                  'EGP ${order.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              fmt.format(order.createdAt),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.secondary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 64,
                color: isDark ? Colors.white24 : AppColors.lightGray),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
