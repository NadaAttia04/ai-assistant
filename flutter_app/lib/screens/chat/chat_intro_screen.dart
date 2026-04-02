import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import 'chat_screen.dart';

class ChatIntroScreen extends StatelessWidget {
  const ChatIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Chat AI'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Image.asset('assets/bot_icon.jpg', width: 56, height: 56, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome to AI Assistant',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your intelligent medical companion. Ask about diagnoses, treatments, medications, clinical guidelines, and more.',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _FeatureItem(
                      icon: Icons.psychology_rounded,
                      text: 'Evidence-based medical guidance',
                    ),
                    const SizedBox(height: 12),
                    _FeatureItem(
                      icon: Icons.history_rounded,
                      text: 'Remembers your conversation context',
                    ),
                    const SizedBox(height: 12),
                    _FeatureItem(
                      icon: Icons.medication_outlined,
                      text: 'Drug interactions & prescriptions',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final userId = prefs.getString('user_id') ?? 'guest';
                final chatId = await ApiService.createChatSession(userId);
                if (!context.mounted) return;
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, role: 'patient')));
              },
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Start Conversation'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.secondary, size: 20),
      const SizedBox(width: 12),
      Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary))),
    ]);
  }
}
