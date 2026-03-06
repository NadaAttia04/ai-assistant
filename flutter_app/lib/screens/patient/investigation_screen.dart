import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/investigation.dart';
import 'management_screen.dart';

class InvestigationScreen extends StatefulWidget {
  final String patientId;
  const InvestigationScreen({super.key, required this.patientId});

  @override
  State<InvestigationScreen> createState() => _InvestigationScreenState();
}

class _InvestigationScreenState extends State<InvestigationScreen> {
  late Future<List<Investigation>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getInvestigations(widget.patientId);
  }

  Future<void> _enterResult(Investigation inv) async {
    final ctrl = TextEditingController(text: inv.result ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(inv.text, style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter investigation result...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true || ctrl.text.trim().isEmpty) return;

    try {
      await ApiService.updateInvestigationResult(
          inv.id, ctrl.text.trim(), widget.patientId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Result saved. Management plan updated by AI.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      setState(() {
        _future = ApiService.getInvestigations(widget.patientId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Investigations'),
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
                      const Icon(Icons.biotech_rounded,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      const Text('Recommended Tests',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap an item to enter the result. AI will update the management plan automatically.',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<List<Investigation>>(
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
                          return const Text('No investigations found.',
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
                            final inv = items[i];
                            final hasResult = inv.result != null &&
                                inv.result!.isNotEmpty;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: hasResult
                                    ? AppColors.secondary.withValues(alpha: 0.15)
                                    : AppColors.lightGray,
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: hasResult
                                            ? AppColors.secondary
                                            : AppColors.textMuted,
                                        fontWeight: FontWeight.bold)),
                              ),
                              title: Text(inv.text,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              subtitle: hasResult
                                  ? Text('Result: ${inv.result}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.secondary))
                                  : const Text('Tap to enter result',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted)),
                              trailing: Icon(
                                hasResult
                                    ? Icons.check_circle_rounded
                                    : Icons.edit_outlined,
                                color: hasResult
                                    ? AppColors.secondary
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                              onTap: () => _enterResult(inv),
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
                builder: (_) =>
                    ManagementScreen(patientId: widget.patientId),
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
        ElevatedButton(onPressed: onNext, child: const Text('Next: Management')),
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
