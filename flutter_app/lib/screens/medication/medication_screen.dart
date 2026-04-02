import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/notification_service.dart';

class Medication {
  final int id;
  final String name;
  final int hour;
  final int minute;

  const Medication(
      {required this.id,
      required this.name,
      required this.hour,
      required this.minute});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'hour': hour, 'minute': minute};

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] as int,
        name: j['name'] as String,
        hour: j['hour'] as int,
        minute: j['minute'] as int,
      );

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  List<Medication> _meds = [];
  static const _prefsKey = 'medications';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _meds = list.map((e) => Medication.fromJson(e)).toList();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(_meds.map((m) => m.toJson()).toList()));
  }

  Future<void> _addMedication() async {
    final nameCtrl = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('Add Medication Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Medication Name',
                  hintText: 'e.g. Metformin 500mg',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_rounded,
                    color: AppColors.secondary),
                title: Text(
                  'Reminder Time: ${selectedTime.format(ctx)}',
                  style: const TextStyle(fontSize: 14),
                ),
                onTap: () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: selectedTime,
                  );
                  if (t != null) setModal(() => selectedTime = t);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(minimumSize: Size.zero),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final name = nameCtrl.text.trim();
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    final med = Medication(
        id: id,
        name: name,
        hour: selectedTime.hour,
        minute: selectedTime.minute);

    await NotificationService.scheduleMedication(
      id: id,
      name: name,
      hour: selectedTime.hour,
      minute: selectedTime.minute,
    );

    setState(() => _meds.add(med));
    await _save();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder set for $name at ${med.timeLabel}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteMedication(Medication med) async {
    await NotificationService.cancelMedication(med.id);
    setState(() => _meds.remove(med));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Reminders'),
      ),
      body: _meds.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 72,
                      color: (isDark ? Colors.white : AppColors.primary)
                          .withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  const Text('No reminders set',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Tap + to add a daily medication reminder',
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white54
                              : AppColors.textMuted)),
                ],
              ),
            )
          : ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _meds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final med = _meds[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E2E)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                            Icons.medication_liquid_rounded,
                            color: AppColors.secondary,
                            size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(med.name,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 13,
                                    color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text('Daily at ${med.timeLabel}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.error, size: 20),
                        onPressed: () => _deleteMedication(med),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMedication,
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('Add Reminder', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
