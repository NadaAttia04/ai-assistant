import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/chat_session.dart';
import '../../../core/providers/theme_provider.dart';

class ChatDrawer extends StatelessWidget {
  final String userId;
  final String userName;
  final String role;
  final String currentChatId;
  final List<ChatSessionMeta> sessions;
  final VoidCallback onNewChat;
  final void Function(String chatId) onSelectChat;
  final void Function(String chatId) onDeleteChat;
  final VoidCallback onMedications;
  final VoidCallback? onNewPatient;
  final VoidCallback onLogout;
  final VoidCallback onShowDisclaimer;

  const ChatDrawer({
    super.key,
    required this.userId,
    required this.userName,
    required this.role,
    required this.currentChatId,
    required this.sessions,
    required this.onNewChat,
    required this.onSelectChat,
    required this.onDeleteChat,
    required this.onMedications,
    this.onNewPatient,
    required this.onLogout,
    required this.onShowDisclaimer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final bgColor = isDark ? const Color(0xFF13131E) : Colors.white;
    final headerBg = isDark ? const Color(0xFF1A1A2E) : AppColors.primary;

    return Drawer(
      backgroundColor: bgColor,
      child: Column(
        children: [
          // Header
          Container(
            color: headerBg,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          role[0].toUpperCase() + role.substring(1),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // New chat button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: InkWell(
              onTap: onNewChat,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded,
                        color: AppColors.secondary, size: 20),
                    SizedBox(width: 8),
                    Text('New Conversation',
                        style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),

          // Session list label
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('CONVERSATIONS',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
            ),
          ),

          // Sessions
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text('No conversations yet',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : AppColors.textMuted,
                          fontSize: 13,
                        )),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    itemCount: sessions.length,
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      final isActive = s.id == currentChatId;
                      return Dismissible(
                        key: Key(s.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Colors.white),
                        ),
                        onDismissed: (_) => onDeleteChat(s.id),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          tileColor: isActive
                              ? AppColors.secondary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          leading: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: isActive
                                ? AppColors.secondary
                                : (isDark
                                    ? Colors.white38
                                    : AppColors.textMuted),
                          ),
                          title: Text(
                            s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: s.formattedDate.isNotEmpty
                              ? Text(s.formattedDate,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : AppColors.textMuted))
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            onSelectChat(s.id);
                          },
                        ),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // Bottom actions
          ListTile(
            dense: true,
            leading: Icon(
              Icons.notifications_active_outlined,
              color: isDark ? Colors.white70 : AppColors.primary,
              size: 20,
            ),
            title: Text('Medication Reminders',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              onMedications();
            },
          ),

          if (role == 'doctor' && onNewPatient != null)
            ListTile(
              dense: true,
              leading: Icon(Icons.person_add_alt_1_rounded,
                  color: isDark ? Colors.white70 : AppColors.primary, size: 20),
              title: Text('New Patient',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                onNewPatient!();
              },
            ),

          ListTile(
            dense: true,
            leading: Icon(
              themeProvider.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: isDark ? Colors.white70 : AppColors.primary,
              size: 20,
            ),
            title: Text(themeProvider.isDark ? 'Light Mode' : 'Dark Mode',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppColors.textPrimary)),
            trailing: Switch(
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggle(),
              activeColor: AppColors.secondary,
            ),
            onTap: () => themeProvider.toggle(),
          ),

          ListTile(
            dense: true,
            leading: const Icon(Icons.info_outline_rounded,
                color: AppColors.textMuted, size: 20),
            title: const Text('Medical Disclaimer',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            onTap: () {
              Navigator.pop(context);
              onShowDisclaimer();
            },
          ),

          ListTile(
            dense: true,
            leading: const Icon(Icons.logout_rounded,
                color: AppColors.error, size: 20),
            title: const Text('Sign Out',
                style: TextStyle(fontSize: 13, color: AppColors.error)),
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
