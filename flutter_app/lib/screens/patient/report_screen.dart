import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/patient.dart';
import '../../core/models/investigation.dart';
import '../../core/models/management.dart';
import '../home_screen.dart';

class ReportScreen extends StatefulWidget {
  final String patientId;
  const ReportScreen({super.key, required this.patientId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late Future<_ReportData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReportData> _load() async {
    final results = await Future.wait([
      ApiService.getPatient(widget.patientId),
      ApiService.getInvestigations(widget.patientId),
      ApiService.getManagement(widget.patientId),
    ]);
    return _ReportData(
      patient: results[0] as Patient,
      investigations: results[1] as List<Investigation>,
      management: results[2] as List<Management>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Patient Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<_ReportData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.white)));
          }
          final data = snap.data!;
          return Column(
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
                        // Patient info
                        _ReportSection(
                          icon: Icons.person_rounded,
                          title: 'Patient',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow('Name', data.patient.name),
                              _InfoRow('Age', data.patient.age),
                              _InfoRow('Sex', data.patient.sex),
                              if (data.patient.allergies.isNotEmpty)
                                _InfoRow('Allergies', data.patient.allergies),
                              if (data.patient.preExistingConditions.isNotEmpty)
                                _InfoRow('Pre-existing',
                                    data.patient.preExistingConditions),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ReportSection(
                          icon: Icons.sick_outlined,
                          title: 'Symptoms',
                          child: Text(data.patient.symptoms,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textPrimary)),
                        ),
                        const SizedBox(height: 16),
                        _ReportSection(
                          icon: Icons.biotech_rounded,
                          title: 'Investigations',
                          child: Column(
                            children: data.investigations.map((inv) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.circle,
                                        size: 6,
                                        color: AppColors.secondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(inv.text,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w500)),
                                          if (inv.result != null &&
                                              inv.result!.isNotEmpty)
                                            Text('Result: ${inv.result}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.secondary)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ReportSection(
                          icon: Icons.medication_rounded,
                          title: 'Management Plan',
                          child: Column(
                            children: data.management
                                .asMap()
                                .entries
                                .map((e) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 10,
                                            backgroundColor: AppColors.secondary
                                                .withValues(alpha: 0.12),
                                            child: Text(
                                                '${e.key + 1}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.secondary,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(e.value.text,
                                                style: const TextStyle(
                                                    fontSize: 13)),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (_) => false,
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Done'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportData {
  final Patient patient;
  final List<Investigation> investigations;
  final List<Management> management;
  _ReportData(
      {required this.patient,
      required this.investigations,
      required this.management});
}

class _ReportSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _ReportSection(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ]),
      const SizedBox(height: 8),
      child,
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: Text('$label:',
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary))),
      ]),
    );
  }
}
