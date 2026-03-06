import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/management.dart';
import 'report_screen.dart';

class ManagementScreen extends StatefulWidget {
  final String patientId;
  const ManagementScreen({super.key, required this.patientId});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  late Future<List<Management>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getManagement(widget.patientId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Management Plan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.medication_rounded,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      const Text('AI Management Plan',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                      'Ordered from highest to lowest priority. Updated automatically when investigation results are added.',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<List<Management>>(
                      future: _future,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Text('Error: ${snap.error}',
                              style:
                                  const TextStyle(color: AppColors.error));
                        }
                        final items = snap.data ?? [];
                        if (items.isEmpty) {
                          return const Text('No management plan found.',
                              style:
                                  TextStyle(color: AppColors.textMuted));
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final item = items[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    AppColors.secondary.withValues(alpha: 0.12),
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.bold)),
                              ),
                              title: Text(item.text,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          _BottomNav(
            onNext: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ReportScreen(patientId: widget.patientId),
              ),
            ),
            onBack: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const _BottomNav({required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ElevatedButton(
            onPressed: onNext, child: const Text('Next: Patient Report')),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onBack,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
          child: const Text('Back'),
        ),
      ]),
    );
  }
}
