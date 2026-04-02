import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/api_service.dart';
import '../chat/chat_screen.dart';
import '../medication/medication_screen.dart';
import '../pharmacy/pharmacy_screen.dart';
import '../services/doctor_booking_sheet.dart';
import '../services/support_sheet.dart';
import '../activity/activity_screen.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../consultation/consultation_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  String _userName = 'Patient';
  String _userId = 'guest';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Patient';
        _userId = prefs.getString('user_id') ?? 'guest';
      });
    }
  }

  Future<void> _openChat() async {
    try {
      final sessions = await ApiService.getChatSessions(_userId);
      final String chatId = sessions.isNotEmpty
          ? sessions.first.id
          : await ApiService.createChatSession(_userId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, role: 'patient'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ChatScreen(chatId: 'offline', role: 'patient'),
        ),
      );
    }
  }

  void _openDoctorBooking() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DoctorBookingSheet(
        onBooked: (msg) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Appointment request sent: $msg'),
              backgroundColor: AppColors.secondary,
            ),
          );
        },
      ),
    );
  }

  void _openPharmacy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PharmacyScreen()),
    );
  }

  void _openActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ActivityScreen()),
    );
  }

  void _openMedicationReminders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MedicationScreen()),
    );
  }

  void _openSupport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SupportSheet(),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openConsultations() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConsultationListScreen()),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor:
                isDark ? const Color(0xFF1A1A2E) : AppColors.primary,
            actions: [
              IconButton(
                icon: Icon(
                  themeProvider.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: Colors.white,
                ),
                onPressed: () => themeProvider.toggle(),
              ),
              IconButton(
                icon: const Icon(Icons.person_rounded, color: Colors.white),
                tooltip: 'Profile',
                onPressed: _openProfile,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1A1A2E), const Color(0xFF0D2244)]
                        : [AppColors.secondary, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              child: Text(
                                _userName.isNotEmpty
                                    ? _userName[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Good day, $_userName!',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700),
                                ),
                                const Text(
                                  'How can we help you today?',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our Services',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Everything you need for your health',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Large primary card — AI Chatbot
                  _LargeServiceCard(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D6BE4), Color(0xFF1A3A6B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: Icons.smart_toy_rounded,
                    title: 'AI Health Chatbot',
                    subtitle:
                        'Ask any health question and get instant AI-powered guidance',
                    badge: 'POWERED BY GEMINI',
                    onTap: _openChat,
                  ),
                  const SizedBox(height: 16),

                  // 2-column grid for other services
                  Row(
                    children: [
                      Expanded(
                        child: _ServiceCard(
                          icon: Icons.medical_services_rounded,
                          title: 'Book a Doctor',
                          subtitle: '8 specialists available',
                          color: const Color(0xFF0891B2),
                          onTap: _openDoctorBooking,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ServiceCard(
                          icon: Icons.local_pharmacy_rounded,
                          title: 'Pharmacy',
                          subtitle: 'Order medicines online',
                          color: const Color(0xFF16A34A),
                          onTap: _openPharmacy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ServiceCard(
                          icon: Icons.alarm_rounded,
                          title: 'Med Reminders',
                          subtitle: 'Schedule your alarms',
                          color: const Color(0xFFD97706),
                          onTap: _openMedicationReminders,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ServiceCard(
                          icon: Icons.headset_mic_rounded,
                          title: 'Support',
                          subtitle: 'Call or WhatsApp us',
                          color: const Color(0xFF7C3AED),
                          onTap: _openSupport,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ServiceCard(
                          icon: Icons.history_rounded,
                          title: 'My Activity',
                          subtitle: 'Bookings, orders & history',
                          color: const Color(0xFF0F766E),
                          onTap: _openActivity,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ServiceCard(
                          icon: Icons.forum_rounded,
                          title: 'Consultations',
                          subtitle: 'Chat with your doctor',
                          color: const Color(0xFFB45309),
                          onTap: _openConsultations,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Health tip card
                  _HealthTipCard(isDark: isDark),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Large Service Card ─────────────────────────────────────────────────────────

class _LargeServiceCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _LargeServiceCard({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D6BE4).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Start Chat →',
                      style: TextStyle(
                          color: Color(0xFF2D6BE4),
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: Colors.white, size: 42),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small Service Card ─────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: fullWidth
            ? Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppColors.textMuted),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Health Tip Card ────────────────────────────────────────────────────────────

class _HealthTipCard extends StatelessWidget {
  final bool isDark;

  const _HealthTipCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF16A34A).withValues(alpha: 0.12)
            : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF16A34A).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tips_and_updates_rounded,
                color: Color(0xFF16A34A), size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Health Tip',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A)),
                ),
                SizedBox(height: 3),
                Text(
                  'Drink at least 8 glasses of water daily to stay hydrated and support your body\'s functions.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
