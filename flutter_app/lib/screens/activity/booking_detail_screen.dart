import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/booking.dart';
import '../../core/services/activity_service.dart';

class BookingDetailScreen extends StatefulWidget {
  final Booking booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Booking _booking;
  bool _loading = false;

  // Available time slots for reschedule
  static const _timeSlots = [
    '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM',
    '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM',
    '4:00 PM', '5:00 PM', '6:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  bool get _canCancel =>
      _booking.status == 'pending' || _booking.status == 'confirmed';

  bool get _canReschedule =>
      _booking.status == 'pending' || _booking.status == 'confirmed';

  Future<void> _cancel() async {
    final confirm = await _confirmDialog(
      title: 'Cancel Booking',
      message:
          'Are you sure you want to cancel this appointment with ${_booking.doctorName}?',
      confirmLabel: 'Cancel Booking',
      confirmColor: AppColors.error,
    );
    if (!confirm || !mounted) return;
    setState(() => _loading = true);
    await ActivityService.updateBookingStatus(_booking.id, 'cancelled');
    setState(() {
      _booking.status = 'cancelled';
      _loading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Booking cancelled'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _reschedule() async {
    // Pick new date (next 7 days)
    final today = DateTime.now();
    final dates = List.generate(
        7, (i) => today.add(Duration(days: i + 1)));
    final dateFmt = DateFormat('EEE, MMM dd');

    String? selectedDate;
    String? selectedTime;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Reschedule Appointment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Date',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: dates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final d = dates[i];
                      final label = dateFmt.format(d);
                      final sel = selectedDate == label;
                      return GestureDetector(
                        onTap: () =>
                            setInner(() => selectedDate = label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.secondary
                                : AppColors.lightGray,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: sel
                                      ? Colors.white
                                      : AppColors.textPrimary)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Select Time',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _timeSlots.map((t) {
                    final sel = selectedTime == t;
                    return GestureDetector(
                      onTap: () => setInner(() => selectedTime = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color:
                              sel ? AppColors.secondary : AppColors.lightGray,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: sel
                                    ? Colors.white
                                    : AppColors.textPrimary)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (selectedDate != null && selectedTime != null)
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(minimumSize: Size.zero),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    ).then((confirmed) async {
      if (confirmed == true && selectedDate != null && selectedTime != null) {
        setState(() => _loading = true);
        await ActivityService.rescheduleBooking(
            _booking.id, selectedDate!, selectedTime!);
        if (mounted) {
          setState(() {
            _loading = false;
            _booking = Booking(
              id: _booking.id,
              doctorId: _booking.doctorId,
              doctorName: _booking.doctorName,
              specialty: _booking.specialty,
              hospital: _booking.hospital,
              date: selectedDate!,
              time: selectedTime!,
              fee: _booking.fee,
              status: 'rescheduled',
              notes: _booking.notes,
              createdAt: _booking.createdAt,
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Appointment rescheduled'),
                backgroundColor: Color(0xFF7C3AED)),
          );
        }
      }
    });
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  minimumSize: Size.zero,
                ),
                child: Text(confirmLabel,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _booking.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              _booking.statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: _booking.statusColor, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${_booking.statusLabel}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _booking.statusColor)),
                            Text(
                              'Booking ID: ${_booking.id.substring(0, 12).toUpperCase()}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Doctor info card
                  _DetailCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.secondary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.medical_services_rounded,
                                  color: AppColors.secondary, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _booking.doctorName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_booking.specialty,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.secondary)),
                                  if (_booking.hospital.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(_booking.hospital,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date/Time/Fee
                  _DetailCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date',
                          value: _booking.date,
                        ),
                        const Divider(height: 20),
                        _DetailRow(
                          icon: Icons.access_time_rounded,
                          label: 'Time',
                          value: _booking.time,
                        ),
                        const Divider(height: 20),
                        _DetailRow(
                          icon: Icons.payments_rounded,
                          label: 'Consultation Fee',
                          value: 'EGP ${_booking.fee.toInt()}',
                          valueStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                              fontSize: 15),
                        ),
                        if (_booking.notes != null) ...[
                          const Divider(height: 20),
                          _DetailRow(
                            icon: Icons.notes_rounded,
                            label: 'Notes',
                            value: _booking.notes!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _DetailCard(
                    isDark: isDark,
                    child: _DetailRow(
                      icon: Icons.access_time_filled_rounded,
                      label: 'Booked on',
                      value: DateFormat('MMM dd, yyyy • hh:mm a')
                          .format(_booking.createdAt),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Action buttons
                  if (_canReschedule)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _reschedule,
                        icon: const Icon(Icons.schedule_rounded,
                            size: 18, color: Colors.white),
                        label: const Text('Reschedule',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (_canReschedule) const SizedBox(height: 10),
                  if (_canCancel)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cancel,
                        icon: const Icon(Icons.cancel_outlined,
                            size: 18, color: AppColors.error),
                        label: const Text('Cancel Booking',
                            style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _DetailCard({required this.child, required this.isDark});

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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(value,
                style: valueStyle ??
                    const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
