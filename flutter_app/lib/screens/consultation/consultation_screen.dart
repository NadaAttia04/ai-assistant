import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';

/// Real-time (polled) direct chat between a patient and their doctor.
class ConsultationScreen extends StatefulWidget {
  final String roomId;
  final String senderRole; // 'patient' or 'doctor'
  final String senderName;
  final String recipientName; // for the AppBar title

  const ConsultationScreen({
    super.key,
    required this.roomId,
    required this.senderRole,
    required this.senderName,
    required this.recipientName,
  });

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    // Poll for new messages every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final msgs = await ApiService.getConsultationMessages(widget.roomId);
      if (!mounted) return;
      final hadNewMessages = msgs.length != _messages.length;
      setState(() => _messages = msgs);
      if (hadNewMessages) _scrollToBottom();
    } catch (_) {
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _inputCtrl.clear();
    setState(() => _sending = true);
    try {
      await ApiService.sendConsultationMessage(
        widget.roomId,
        widget.senderRole,
        widget.senderName,
        text,
      );
      await _fetchMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send: $e'),
              backgroundColor: AppColors.error),
        );
        _inputCtrl.text = text; // restore text on failure
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.recipientName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            Text(
              widget.senderRole == 'patient'
                  ? 'Direct consultation'
                  : 'Patient consultation',
              style:
                  const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => _fetchMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 56,
                                color: isDark
                                    ? Colors.white24
                                    : AppColors.lightGray),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet.\nSend the first message!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final isMe =
                              msg['sender_role'] == widget.senderRole;
                          return _MessageBubble(
                            message: msg,
                            isMe: isMe,
                            isDark: isDark,
                          );
                        },
                      ),
          ),

          // Input bar
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A1A2E)
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF252538)
                            : AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.secondary,
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 18),
                              onPressed: _send,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isDark;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
  });

  String _formatTime(String? isoTimestamp) {
    if (isoTimestamp == null) return '';
    try {
      final dt = DateTime.parse(isoTimestamp).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe
        ? AppColors.primary
        : (isDark ? const Color(0xFF1E1E2E) : AppColors.surface);
    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : AppColors.textPrimary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  AppColors.secondary.withValues(alpha: 0.15),
              child: Icon(
                message['sender_role'] == 'doctor'
                    ? Icons.medical_services_rounded
                    : Icons.person_rounded,
                size: 14,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 4),
                    child: Text(
                      message['sender_name'] ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message['content'] ?? '',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        height: 1.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    _formatTime(message['timestamp'] as String?),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.lightGray,
              child: Icon(Icons.person_rounded,
                  size: 14, color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Consultation Rooms List (for Doctor & Patient) ───────────────────────────

class ConsultationListScreen extends StatefulWidget {
  const ConsultationListScreen({super.key});

  @override
  State<ConsultationListScreen> createState() =>
      _ConsultationListScreenState();
}

class _ConsultationListScreenState
    extends State<ConsultationListScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;
  String _userId = '';
  String _userName = '';
  String _role = 'patient';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? '';
    _userName = prefs.getString('user_name') ?? '';
    _role = prefs.getString('user_role') ?? 'patient';
    if (_userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final rooms = _role == 'doctor'
          ? await ApiService.getDoctorConsultations(_userId)
          : await ApiService.getPatientConsultations(_userId);
      if (mounted) setState(() => _rooms = rooms);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('My Consultations')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_outlined,
                          size: 60,
                          color: isDark
                              ? Colors.white24
                              : AppColors.lightGray),
                      const SizedBox(height: 12),
                      const Text('No consultations yet',
                          style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rooms.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final room = _rooms[i];
                    final otherName = _role == 'doctor'
                        ? room['patient_name'] ?? 'Patient'
                        : room['doctor_name'] ?? 'Doctor';
                    return Material(
                      color: isDark
                          ? const Color(0xFF1E1E2E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConsultationScreen(
                              roomId: room['_id'] as String,
                              senderRole: _role,
                              senderName: _userName,
                              recipientName: otherName,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.secondary
                                    .withValues(alpha: 0.12),
                                child: Icon(
                                  _role == 'doctor'
                                      ? Icons.person_rounded
                                      : Icons.medical_services_rounded,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(otherName,
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.textPrimary)),
                                    const SizedBox(height: 3),
                                    const Text('Tap to open chat',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: isDark
                                      ? Colors.white38
                                      : AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
