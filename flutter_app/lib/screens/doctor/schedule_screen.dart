import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _allSlots = [
    '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM',
    '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM',
    '4:00 PM', '5:00 PM', '6:00 PM',
  ];

  Set<String> _activeDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  Set<String> _activeSlots = {'9:00 AM', '11:00 AM', '2:00 PM', '5:00 PM'};
  final _feeCtrl = TextEditingController(text: '200');
  String _status = 'available'; // available | away | busy
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('doctor_schedule');
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _activeDays = Set<String>.from(data['days'] as List? ?? []);
          _activeSlots = Set<String>.from(data['slots'] as List? ?? []);
          _feeCtrl.text = data['fee']?.toString() ?? '200';
          _status = data['status'] as String? ?? 'available';
        });
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'doctor_schedule',
      jsonEncode({
        'days': _activeDays.toList(),
        'slots': _activeSlots.toList(),
        'fee': double.tryParse(_feeCtrl.text.trim()) ?? 200.0,
        'status': _status,
      }),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Schedule saved'),
        backgroundColor: Color(0xFF16A34A),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            _SectionTitle('Availability Status', isDark: isDark),
            const SizedBox(height: 12),
            _Card(
              isDark: isDark,
              child: Row(
                children: [
                  _StatusChip(
                    label: 'Available',
                    color: const Color(0xFF16A34A),
                    icon: Icons.check_circle_rounded,
                    selected: _status == 'available',
                    onTap: () => setState(() => _status = 'available'),
                  ),
                  const SizedBox(width: 10),
                  _StatusChip(
                    label: 'Away',
                    color: const Color(0xFFD97706),
                    icon: Icons.access_time_rounded,
                    selected: _status == 'away',
                    onTap: () => setState(() => _status = 'away'),
                  ),
                  const SizedBox(width: 10),
                  _StatusChip(
                    label: 'Busy',
                    color: const Color(0xFFDC2626),
                    icon: Icons.do_not_disturb_rounded,
                    selected: _status == 'busy',
                    onTap: () => setState(() => _status = 'busy'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Consultation fee
            _SectionTitle('Consultation Fee (EGP)', isDark: isDark),
            const SizedBox(height: 12),
            _Card(
              isDark: isDark,
              child: TextField(
                controller: _feeCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.payments_rounded),
                  hintText: 'e.g. 200',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Working days
            _SectionTitle('Working Days', isDark: isDark),
            const SizedBox(height: 12),
            _Card(
              isDark: isDark,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _days.map((day) {
                  final active = _activeDays.contains(day);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (active) {
                        _activeDays.remove(day);
                      } else {
                        _activeDays.add(day);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.secondary
                            : (isDark
                                ? const Color(0xFF2A2A3E)
                                : AppColors.lightGray),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            day,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white54
                                      : AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 22),

            // Time slots
            _SectionTitle('Available Time Slots', isDark: isDark),
            const SizedBox(height: 12),
            _Card(
              isDark: isDark,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allSlots.map((slot) {
                  final active = _activeSlots.contains(slot);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (active) {
                        _activeSlots.remove(slot);
                      } else {
                        _activeSlots.add(slot);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.secondary
                            : (isDark
                                ? const Color(0xFF2A2A3E)
                                : AppColors.lightGray),
                        borderRadius: BorderRadius.circular(10),
                        border: active
                            ? null
                            : Border.all(
                                color: isDark
                                    ? const Color(0xFF3A3A5E)
                                    : AppColors.lightGray),
                      ),
                      child: Text(
                        slot,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: active
                              ? Colors.white
                              : (isDark
                                  ? Colors.white60
                                  : AppColors.textPrimary),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),

            // Summary
            _Card(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                      icon: Icons.calendar_today_rounded,
                      label:
                          '${_activeDays.length} working days per week'),
                  _SummaryRow(
                      icon: Icons.access_time_rounded,
                      label:
                          '${_activeSlots.length} available time slots'),
                  _SummaryRow(
                      icon: Icons.payments_rounded,
                      label:
                          'EGP ${_feeCtrl.text.isEmpty ? '0' : _feeCtrl.text} per consultation'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save Schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionTitle(this.title, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary));
  }
}

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
            color:
                Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.color,
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
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SummaryRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.secondary),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
