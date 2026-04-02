import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/activity_service.dart';
import '../../core/models/doctor.dart';
import '../../core/models/booking.dart';

class DoctorBookingSheet extends StatefulWidget {
  final void Function(String message) onBooked;

  const DoctorBookingSheet({super.key, required this.onBooked});

  @override
  State<DoctorBookingSheet> createState() => _DoctorBookingSheetState();
}

class _DoctorBookingSheetState extends State<DoctorBookingSheet> {
  List<Doctor> _all = [];
  List<Doctor> _filtered = [];
  bool _loading = true;
  String _selectedSpecialty = 'All';

  static const _specialties = [
    'All', 'General', 'Cardiology', 'Dermatology',
    'Pediatrics', 'Neurology', 'Orthopedics', 'Psychiatry', 'Gynecology',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docs = await ApiService.getDoctors();
      if (mounted) {
        setState(() {
          _all = docs;
          _filtered = docs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter(String specialty) {
    setState(() {
      _selectedSpecialty = specialty;
      if (specialty == 'All') {
        _filtered = _all;
      } else {
        _filtered = _all.where((d) {
          final s = d.specialty.toLowerCase();
          return s.contains(specialty.toLowerCase()) ||
              _specialtyKey(d.specialty) == specialty;
        }).toList();
      }
    });
  }

  String _specialtyKey(String s) {
    if (s.contains('Cardio')) return 'Cardiology';
    if (s.contains('Derm')) return 'Dermatology';
    if (s.contains('General')) return 'General';
    if (s.contains('Pediatr')) return 'Pediatrics';
    if (s.contains('Neuro')) return 'Neurology';
    if (s.contains('Ortho')) return 'Orthopedics';
    if (s.contains('Psych')) return 'Psychiatry';
    if (s.contains('Gyn')) return 'Gynecology';
    return s;
  }

  Future<void> _book(Doctor doctor) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _AppointmentDialog(doctor: doctor),
    );
    if (result == null || !mounted) return;
    final date = result['date']!;
    final time = result['time']!;

    // Save to activity
    await ActivityService.addBooking(Booking(
      id: const Uuid().v4(),
      doctorId: doctor.id,
      doctorName: doctor.name,
      specialty: doctor.specialty,
      hospital: doctor.hospital,
      date: date,
      time: time,
      fee: doctor.price,
      status: 'pending',
      createdAt: DateTime.now(),
    ));

    Navigator.pop(context);
    widget.onBooked(
      'I want to book an appointment with ${doctor.name} (${doctor.specialty}) '
      'on $date at $time. Consultation fee: EGP ${doctor.price.toInt()}.',
    );
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
            // Drag handle
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
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medical_services_rounded,
                        color: AppColors.secondary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Find a Doctor',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor)),
                      Text('${_filtered.length} doctors available',
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

            // Specialty filter
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _specialties.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = _specialties[i];
                  final selected = s == _selectedSpecialty;
                  return GestureDetector(
                    onTap: () => _filter(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.secondary
                            : (isDark
                                ? const Color(0xFF2A2A3E)
                                : AppColors.lightGray),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s,
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

            // Doctor list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? Center(
                          child: Text('No doctors found',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : AppColors.textMuted)))
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _DoctorCard(
                            doctor: _filtered[i],
                            isDark: isDark,
                            onBook: () => _book(_filtered[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Doctor Card ───────────────────────────────────────────────────────────────

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final bool isDark;
  final VoidCallback onBook;

  const _DoctorCard(
      {required this.doctor, required this.isDark, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final cardBg =
        isDark ? const Color(0xFF252538) : AppColors.surface;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                doctor.imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 70,
                  height: 70,
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.secondary, size: 36),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(doctor.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            )),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'EGP ${doctor.price.toInt()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(doctor.specialty,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.secondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 14),
                      const SizedBox(width: 2),
                      Text('${doctor.rating}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(width: 8),
                      const Icon(Icons.work_outline_rounded,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text('${doctor.experienceYears} yrs',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.local_hospital_outlined,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(doctor.hospital,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Available times preview
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: doctor.availableTimes.take(3).map((t) =>
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Text(t,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.w500)),
                      )).toList(),
                  ),
                  if (doctor.availableTimes.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${doctor.availableTimes.length - 3} more slots',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onBook,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Book Appointment',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Appointment Time Dialog ───────────────────────────────────────────────────

class _AppointmentDialog extends StatefulWidget {
  final Doctor doctor;
  const _AppointmentDialog({required this.doctor});

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  String? _selectedTime;
  String? _selectedDate;

  List<String> get _dates {
    final fmt = DateFormat('EEE, MMM dd');
    return List.generate(
        7, (i) => fmt.format(DateTime.now().add(Duration(days: i + 1))));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book with ${widget.doctor.name}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(widget.doctor.specialty,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.secondary)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select date:',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _dates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final d = _dates[i];
                  final sel = _selectedDate == d;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.secondary : AppColors.lightGray,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(d,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: sel ? Colors.white : AppColors.textPrimary)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            const Text('Select time:',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.doctor.availableTimes.map((t) {
                final isSelected = _selectedTime == t;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTime = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.secondary
                          : AppColors.lightGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_selectedTime == null || _selectedDate == null)
              ? null
              : () => Navigator.pop(context,
                  {'date': _selectedDate!, 'time': _selectedTime!}),
          style: ElevatedButton.styleFrom(minimumSize: Size.zero),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
