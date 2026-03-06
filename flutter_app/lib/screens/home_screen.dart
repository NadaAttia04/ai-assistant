import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'patient/symptoms_screen.dart';
import 'chat/chat_intro_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medical_services_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AI Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Text(
                'Trust your medical\ninformation and wisdom\nin your decisions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI-powered medical guidance for doctors',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // Cards
              _HomeCard(
                icon: Icons.person_add_rounded,
                title: 'New Patient',
                subtitle: 'Register patient & get AI recommendations',
                color: AppColors.secondary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SymptomsScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _HomeCard(
                icon: Icons.chat_rounded,
                title: 'Chat AI',
                subtitle: 'Ask any medical question',
                color: Colors.white.withValues(alpha: 0.15),
                textColor: Colors.white,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatIntroScreen()),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.75), fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: textColor.withValues(alpha: 0.6), size: 18),
          ],
        ),
      ),
    );
  }
}
