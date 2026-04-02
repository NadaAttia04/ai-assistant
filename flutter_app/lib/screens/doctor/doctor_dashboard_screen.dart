import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/models/patient.dart';
import '../chat/chat_screen.dart';
import '../patient/symptoms_screen.dart';
import '../auth/login_screen.dart';
import 'appointments_screen.dart';
import 'patient_list_screen.dart';
import 'schedule_screen.dart';
import '../activity/activity_screen.dart';
import '../profile/profile_screen.dart';
import '../consultation/consultation_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  String _userName = 'Doctor';
  String _userId = 'guest';
  List<Patient> _recentPatients = [];
  bool _loadingPatients = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'guest';
    final name = prefs.getString('user_name') ?? 'Doctor';
    if (mounted) setState(() { _userName = name; _userId = userId; });

    try {
      final patients = await ApiService.getPatients(userId);
      if (mounted) {
        setState(() {
          _recentPatients = patients.take(3).toList();
          _loadingPatients = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPatients = false);
    }
  }

  Future<void> _openChat() async {
    try {
      final sessions = await ApiService.getChatSessions(_userId);
      final String chatId = sessions.isNotEmpty
          ? sessions.first.id
          : await ApiService.createChatSession(_userId);
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, role: 'doctor')));
    } catch (_) {
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ChatScreen(chatId: 'offline', role: 'doctor')));
    }
  }

  void _openProfile() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  void _openConsultations() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ConsultationListScreen()));
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
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor:
                isDark ? const Color(0xFF1A1A2E) : AppColors.primary,
            actions: [
              IconButton(
                icon: Icon(
                  themeProvider.isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
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
                        ? [const Color(0xFF0D2244), const Color(0xFF1A1A2E)]
                        : [AppColors.primary, const Color(0xFF0D2244)],
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
                              radius: 28,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              child: Text(
                                _userName.isNotEmpty
                                    ? _userName[0].toUpperCase()
                                    : 'D',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dr. $_userName',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800),
                                  ),
                                  const Text(
                                    'Medical Professional',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4ADE80),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Online',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Stats row
                        Row(
                          children: [
                            _StatBadge(
                                label: 'Patients',
                                value: _recentPatients.length.toString(),
                                icon: Icons.people_rounded),
                            const SizedBox(width: 10),
                            _StatBadge(
                                label: 'Today',
                                value: '5',
                                icon: Icons.calendar_today_rounded),
                            const SizedBox(width: 10),
                            _StatBadge(
                                label: 'Pending',
                                value: '2',
                                icon: Icons.pending_actions_rounded),
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
                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.3,
                    children: [
                      _ActionCard(
                        icon: Icons.person_add_rounded,
                        title: 'New Patient',
                        subtitle: 'Register & get AI plan',
                        color: AppColors.secondary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SymptomsScreen()),
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.smart_toy_rounded,
                        title: 'AI Chatbot',
                        subtitle: 'Clinical AI assistant',
                        color: const Color(0xFF7C3AED),
                        onTap: _openChat,
                      ),
                      _ActionCard(
                        icon: Icons.calendar_month_rounded,
                        title: 'Appointments',
                        subtitle: 'Manage your schedule',
                        color: const Color(0xFF0891B2),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AppointmentsScreen()),
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.group_rounded,
                        title: 'Patient Queue',
                        subtitle: 'View pending patients',
                        color: const Color(0xFFD97706),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PatientListScreen()),
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.edit_calendar_rounded,
                        title: 'My Schedule',
                        subtitle: 'Manage slots & fees',
                        color: const Color(0xFF0891B2),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ScheduleScreen()),
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.history_rounded,
                        title: 'Activity',
                        subtitle: 'Bookings & orders',
                        color: const Color(0xFF0F766E),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ActivityScreen()),
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.forum_rounded,
                        title: 'Consultations',
                        subtitle: 'Chat with patients',
                        color: const Color(0xFFB45309),
                        onTap: _openConsultations,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Recent patients section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Patients',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PatientListScreen()),
                        ),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_loadingPatients)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_recentPatients.isEmpty)
                    _EmptyPatientsCard(isDark: isDark)
                  else
                    ...(_recentPatients
                        .map((p) => _PatientListTile(patient: p, isDark: isDark))),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SymptomsScreen()),
        ),
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Patient',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Stat Badge ─────────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatBadge(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Action Card ────────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Patient List Tile ──────────────────────────────────────────────────────────

class _PatientListTile extends StatelessWidget {
  final Patient patient;
  final bool isDark;

  const _PatientListTile({required this.patient, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
            child: Text(
              patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${patient.age} yrs • ${patient.sex}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyPatientsCard extends StatelessWidget {
  final bool isDark;
  const _EmptyPatientsCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded,
              size: 48, color: isDark ? Colors.white24 : AppColors.lightGray),
          const SizedBox(height: 12),
          Text(
            'No patients yet',
            style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          const Text(
            'Register a new patient to get started',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
