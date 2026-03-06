import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import 'investigation_screen.dart';

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _symptomsCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  String _sex = 'Male';
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _allergiesCtrl.dispose();
    _symptomsCtrl.dispose();
    _conditionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorId = prefs.getString('user_id') ?? 'guest';

      final patientId = await ApiService.createPatient(
        doctorId: doctorId,
        name: _nameCtrl.text.trim(),
        sex: _sex,
        age: _ageCtrl.text.trim(),
        symptoms: _symptomsCtrl.text.trim(),
        allergies: _allergiesCtrl.text.trim(),
        preExistingConditions: _conditionsCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvestigationScreen(patientId: patientId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('New Patient'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                    icon: Icons.person_outline, label: 'Patient Info'),
                const SizedBox(height: 16),
                _field('Full Name', _nameCtrl, required: true),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field('Age', _ageCtrl,
                      required: true, keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sex,
                      decoration: const InputDecoration(labelText: 'Sex'),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                      ],
                      onChanged: (v) => setState(() => _sex = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                const _SectionHeader(
                    icon: Icons.medical_information_outlined,
                    label: 'Medical History'),
                const SizedBox(height: 16),
                _field('Allergies', _allergiesCtrl,
                    hint: 'e.g. penicillin, nuts'),
                const SizedBox(height: 12),
                _field('Pre-existing Conditions', _conditionsCtrl,
                    hint: 'e.g. diabetes, hypertension'),
                const SizedBox(height: 20),
                const _SectionHeader(
                    icon: Icons.sick_outlined, label: 'Symptoms'),
                const SizedBox(height: 16),
                _field('Describe Symptoms', _symptomsCtrl,
                    required: true,
                    maxLines: 5,
                    hint: 'Describe what the patient is experiencing...'),
                const SizedBox(height: 28),
                _loading
                    ? const Center(
                        child: Column(children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('AI is analysing patient data...',
                              style: TextStyle(color: AppColors.textMuted)),
                        ]),
                      )
                    : ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Get AI Recommendations'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.primary, size: 20),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 15)),
    ]);
  }
}
