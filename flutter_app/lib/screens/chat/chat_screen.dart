import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/stt_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/report_service.dart';
import '../../core/models/message.dart';
import '../../core/models/chat_session.dart';
import '../auth/login_screen.dart';
import '../patient/symptoms_screen.dart';
import '../medication/medication_screen.dart';
import '../pharmacy/pharmacy_screen.dart';
import '../services/doctor_booking_sheet.dart';
import '../services/support_sheet.dart';
import 'widgets/chat_drawer.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String role;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.role = 'patient',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late String _currentChatId;
  List<ChatSessionMeta> _sessions = [];

  bool _loading = false;
  bool _loadingHistory = true;
  String _userId = 'guest';
  String _userName = 'Guest';
  late String _role;

  // Attachment state
  File? _pickedImage;
  ({String path, String name})? _pickedFile;

  // Voice / TTS
  bool _isListening = false;
  bool _ttsEnabled = false;
  String? _sttLocaleId; // null = device default, 'ar-SA' etc for specific language
  bool _sttShowLangPicker = false;

  // Reply
  ChatMessage? _replyTo;

  // Search
  bool _searchMode = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // Disclaimer shown
  bool _disclaimerShown = false;

  @override
  void initState() {
    super.initState();
    _currentChatId = widget.chatId;
    _role = widget.role;
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? 'guest';
    _userName = prefs.getString('user_name') ?? 'Guest';
    _disclaimerShown = prefs.getBool('disclaimer_shown') ?? false;
    await _loadSessions();
    await _loadHistory(_currentChatId);
    if (!_disclaimerShown && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      _showDisclaimerDialog();
    }
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await ApiService.getChatSessions(_userId);
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {}
  }

  Future<void> _loadHistory(String chatId) async {
    setState(() {
      _loadingHistory = true;
      _messages.clear();
    });
    try {
      final msgs = await ApiService.getSessionMessages(chatId);
      if (!mounted) return;
      if (msgs.isEmpty) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: _role == 'doctor'
                ? "Hello, Doctor! I'm your AI medical assistant.\n\nYou can type a clinical question, send an image, upload a PDF lab report, or use voice input.\n\nI provide professional, evidence-based medical information."
                : "Hello! I'm your AI health assistant.\n\nFeel free to ask me about your symptoms, medications, or any health concerns. You can also send images or voice messages.\n\nI'm here to help! 😊",
          ));
        });
      } else {
        setState(() {
          _messages.addAll(msgs.map((m) => ChatMessage(
                role: m['role'] as String,
                content: m['content'] as String,
                severity: m['severity'] as String?,
              )));
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(const ChatMessage(
            role: 'assistant',
            content:
                "You're offline. Showing cached messages. New messages will be available when you reconnect.",
          ));
        });
      }
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
      _scrollToBottom();
    }
  }

  // ── Send ────────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    final image = _pickedImage;
    final fileAttach = _pickedFile;
    final replyTo = _replyTo;
    if (text.isEmpty && image == null && fileAttach == null) return;
    if (_loading) return;

    // Intent detection — redirect to proper screen instead of AI
    if (image == null && fileAttach == null && _detectAndHandleIntent(text)) {
      return;
    }

    setState(() {
      _messages.add(ChatMessage(
        role: 'user',
        content: text,
        imageFile: image,
        fileName: fileAttach?.name,
        replyTo: replyTo?.content,
      ));
      _loading = true;
      _pickedImage = null;
      _pickedFile = null;
      _replyTo = null;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    try {
      final Map<String, String?> result;
      if (image != null) {
        result = await ApiService.sendMessageWithImage(
            text, image.path, _userId, _currentChatId,
            role: _role);
      } else if (fileAttach != null) {
        result = await ApiService.sendMessageWithFile(
            text, fileAttach.path, fileAttach.name, _userId, _currentChatId,
            role: _role);
      } else {
        result = await ApiService.sendChatMessage(
            text, _userId, _currentChatId,
            role: _role);
      }
      if (!mounted) return;
      final reply = result['response'] ?? '';
      final severity = result['severity'];
      setState(() => _messages.add(ChatMessage(
            role: 'assistant',
            content: reply,
            severity: severity,
          )));
      if (_ttsEnabled) TtsService.speak(reply);
      // Refresh session list for title update
      _loadSessions();
    } catch (e) {
      if (!mounted) return;
      final errMsg = e.toString().replaceAll('Exception: ', '');
      final isNetworkError = errMsg.toLowerCase().contains('connection') ||
          errMsg.toLowerCase().contains('socket') ||
          errMsg.toLowerCase().contains('network');
      setState(() => _messages.add(ChatMessage(
            role: 'assistant',
            content: isNetworkError
                ? '⚠️ **Connection Error**\n\nCould not reach the server. Please check your internet connection and try again.'
                : '⚠️ **Service Unavailable**\n\n$errMsg\n\nPlease wait a moment and try again.',
          )));
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  // ── Session management ──────────────────────────────────────────────────────

  Future<void> _startNewChat() async {
    try {
      final newId = await ApiService.createChatSession(_userId);
      if (!mounted) return;
      setState(() => _currentChatId = newId);
      await _loadHistory(newId);
      await _loadSessions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create new chat: $e')));
    }
  }

  Future<void> _switchSession(String chatId) async {
    if (chatId == _currentChatId) return;
    setState(() => _currentChatId = chatId);
    await _loadHistory(chatId);
  }

  Future<void> _deleteSession(String chatId) async {
    await ApiService.deleteChatSession(chatId);
    setState(() => _sessions.removeWhere((s) => s.id == chatId));
    if (chatId == _currentChatId && _sessions.isNotEmpty) {
      await _switchSession(_sessions.first.id);
    }
  }

  // ── Attachments ─────────────────────────────────────────────────────────────

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Attach',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F0FE),
                  child: Icon(Icons.camera_alt_rounded,
                      color: AppColors.secondary),
                ),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F0FE),
                  child: Icon(Icons.photo_library_rounded,
                      color: AppColors.secondary),
                ),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEEEE),
                  child: Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.redAccent),
                ),
                title: const Text('Upload PDF'),
                subtitle:
                    const Text('Medical reports, lab results, etc.'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 1024);
    if (picked != null && mounted) {
      setState(() {
        _pickedImage = File(picked.path);
        _pickedFile = null;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      final file = result.files.first;
      if (file.path == null) return;
      if (file.size > 15 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'File too large. Please upload a PDF under 15 MB.')));
        return;
      }
      setState(() {
        _pickedFile = (path: file.path!, name: file.name);
        _pickedImage = null;
      });
    }
  }

  // ── Voice ───────────────────────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    if (_isListening) {
      await SttService.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    _inputCtrl.clear();
    final started = await SttService.startListening(
      localeId: _sttLocaleId,
      onResult: (words) {
        if (mounted) {
          setState(() {
            _inputCtrl.text = words;
            _inputCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: words.length),
            );
          });
        }
      },
      onDone: () {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() => _isListening = started);
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start voice recognition. Check microphone permissions.'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showLanguagePicker() async {
    final locales = await SttService.getLocales();
    if (!mounted) return;
    final arabicLocale = await SttService.getArabicLocale();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Voice Language',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: const Text('Device Default'),
                subtitle: const Text('Uses your phone\'s language setting'),
                trailing: _sttLocaleId == null
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.secondary)
                    : null,
                onTap: () {
                  setState(() => _sttLocaleId = null);
                  Navigator.pop(context);
                },
              ),
              if (arabicLocale != null)
                ListTile(
                  leading: const Text('\u{1F1F8}\u{1F1E6}', style: TextStyle(fontSize: 24)),
                  title: const Text('\u0627\u0644\u0639\u0631\u0628\u064A\u0629 (Arabic)'),
                  subtitle: Text(arabicLocale),
                  trailing: _sttLocaleId == arabicLocale
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.secondary)
                      : null,
                  onTap: () {
                    setState(() => _sttLocaleId = arabicLocale);
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: const Text('\u{1F1FA}\u{1F1F8}', style: TextStyle(fontSize: 24)),
                title: const Text('English (US)'),
                trailing: _sttLocaleId == 'en-US'
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.secondary)
                    : null,
                onTap: () {
                  setState(() => _sttLocaleId = 'en-US');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Export PDF ──────────────────────────────────────────────────────────────

  Future<void> _exportReport() async {
    try {
      await ReportService.generateAndShare(_messages, _role);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')));
    }
  }

  // ── Disclaimer ──────────────────────────────────────────────────────────────

  Future<void> _showDisclaimerDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.health_and_safety_outlined,
              color: AppColors.secondary, size: 22),
          SizedBox(width: 8),
          Text('Medical Disclaimer'),
        ]),
        content: const Text(
          'This AI assistant provides general health information only. '
          'It is NOT a substitute for professional medical advice, diagnosis, or treatment.\n\n'
          'Always consult a qualified healthcare provider for medical concerns. '
          'In case of emergency, call your local emergency services immediately.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('disclaimer_shown', true);
              if (mounted) {
                setState(() => _disclaimerShown = true);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: Size.zero),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  // ── Intent Detection ────────────────────────────────────────────────────────

  /// Returns true if intent was detected and handled (skip AI call).
  bool _detectAndHandleIntent(String text) {
    final t = text.toLowerCase();

    // Doctor booking intent
    if ((t.contains('book') || t.contains('appointment') ||
            t.contains('حجز') || t.contains('doctor') ||
            t.contains('دكتور')) &&
        !t.contains('no doctor') &&
        !t.contains('without')) {
      _inputCtrl.clear();
      _showDoctorBooking();
      return true;
    }

    // Pharmacy / medicine order intent
    if ((t.contains('pharmacy') || t.contains('medicine') ||
            t.contains('drug') || t.contains('صيدلية') ||
            t.contains('order') && t.contains('med')) &&
        !t.contains('?') &&
        !t.contains('what is')) {
      _inputCtrl.clear();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PharmacyScreen()),
      );
      return true;
    }

    // Support intent
    if (t.contains('support') || t.contains('help me contact') ||
        t.contains('whatsapp') || t.contains('call you') ||
        t.contains('talk to human')) {
      _inputCtrl.clear();
      _showSupport();
      return true;
    }

    return false;
  }

  // ── Service helpers ──────────────────────────────────────────────────────────

  Future<void> _sendServiceMessage(String text) async {
    _inputCtrl.text = text;
    await _send();
  }

  void _showDoctorBooking() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DoctorBookingSheet(
        onBooked: (msg) => _sendServiceMessage(msg),
      ),
    );
  }

  void _showSupport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SupportSheet(),
    );
  }

  // ── Logout ──────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_role');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

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

  List<ChatMessage> get _filteredMessages {
    if (!_searchMode || _searchQuery.isEmpty) return _messages;
    return _messages
        .where((m) =>
            m.content.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    TtsService.stop();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF13131E) : AppColors.background,
      drawer: ChatDrawer(
        userId: _userId,
        userName: _userName,
        role: _role,
        currentChatId: _currentChatId,
        sessions: _sessions,
        onNewChat: () {
          Navigator.pop(context);
          _startNewChat();
        },
        onSelectChat: _switchSession,
        onDeleteChat: _deleteSession,
        onMedications: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MedicationScreen()),
        ),
        onNewPatient: _role == 'doctor'
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SymptomsScreen()),
                )
            : null,
        onLogout: _logout,
        onShowDisclaimer: _showDisclaimerDialog,
      ),
      appBar: _searchMode ? _buildSearchBar(isDark) : _buildAppBar(isDark),
      body: _loadingHistory
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _filteredMessages.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_loading && i == _filteredMessages.length) {
                        return const _TypingIndicator();
                      }
                      final msg = _filteredMessages[i];
                      return _ChatBubble(
                        message: msg,
                        onReply: () =>
                            setState(() => _replyTo = msg),
                        onReplay: () => TtsService.speak(msg.content),
                        isDark: isDark,
                      );
                    },
                  ),
                ),
                _InputBar(
                  controller: _inputCtrl,
                  loading: _loading,
                  isListening: _isListening,
                  pickedImage: _pickedImage,
                  pickedFileName: _pickedFile?.name,
                  replyTo: _replyTo,
                  isDark: isDark,
                  sttLocaleId: _sttLocaleId,
                  onSend: _send,
                  onAttach: _showAttachMenu,
                  onToggleMic: _toggleMic,
                  onLongPressMic: _showLanguagePicker,
                  onClearAttachment: () => setState(() {
                    _pickedImage = null;
                    _pickedFile = null;
                  }),
                  onCancelReply: () => setState(() => _replyTo = null),
                ),
              ],
            ),
    );
  }

  AppBar _buildAppBar(bool isDark) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.white),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset('assets/bot_icon.jpg', fit: BoxFit.contain),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Assistant',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(
              _role == 'doctor' ? 'Clinical Mode' : 'Medical AI',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ]),
      actions: [
        // Search
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.white70),
          tooltip: 'Search',
          onPressed: () => setState(() => _searchMode = true),
        ),
        // TTS toggle
        IconButton(
          icon: Icon(
            _ttsEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            color: _ttsEnabled ? Colors.white : Colors.white54,
          ),
          tooltip: _ttsEnabled ? 'Mute' : 'Read responses aloud',
          onPressed: () {
            setState(() => _ttsEnabled = !_ttsEnabled);
            if (!_ttsEnabled) TtsService.stop();
          },
        ),
        // More menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
          onSelected: (v) {
            if (v == 'export') _exportReport();
            if (v == 'disclaimer') _showDisclaimerDialog();
            if (v == 'dark') context.read<ThemeProvider>().toggle();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.picture_as_pdf_rounded),
                  title: Text('Export Report'),
                )),
            const PopupMenuItem(
                value: 'disclaimer',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('Disclaimer'),
                )),
            PopupMenuItem(
                value: 'dark',
                child: ListTile(
                  dense: true,
                  leading: Icon(context.read<ThemeProvider>().isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined),
                  title: Text(context.read<ThemeProvider>().isDark
                      ? 'Light Mode'
                      : 'Dark Mode'),
                )),
          ],
        ),
      ],
    );
  }

  AppBar _buildSearchBar(bool isDark) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () {
          setState(() {
            _searchMode = false;
            _searchQuery = '';
            _searchCtrl.clear();
          });
        },
      ),
      title: TextField(
        controller: _searchCtrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search messages...',
          hintStyle: TextStyle(color: Colors.white54),
          border: InputBorder.none,
          fillColor: Colors.transparent,
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
      actions: [
        if (_searchQuery.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear_rounded, color: Colors.white70),
            onPressed: () => setState(() {
              _searchQuery = '';
              _searchCtrl.clear();
            }),
          ),
      ],
    );
  }
}

// ── Chat Bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onReply;
  final VoidCallback onReplay;
  final bool isDark;

  const _ChatBubble({
    required this.message,
    required this.onReply,
    required this.onReplay,
    required this.isDark,
  });

  Color _severityColor(String severity) {
    switch (severity) {
      case 'severe':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _severityEmoji(String severity) {
    switch (severity) {
      case 'severe':
        return '🔴';
      case 'moderate':
        return '🟡';
      default:
        return '🟢';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? AppColors.primary
        : (isDark ? const Color(0xFF1E1E2E) : AppColors.surface);
    final textColor = isUser
        ? Colors.white
        : (isDark ? Colors.white : AppColors.textPrimary);

    return GestureDetector(
      onLongPress: onReply,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Image.asset('assets/bot_icon.jpg',
                    width: 20, height: 20, fit: BoxFit.contain),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Reply quote
                  if (message.replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: const Border(
                            left: BorderSide(
                                color: AppColors.secondary, width: 3)),
                      ),
                      child: Text(
                        message.replyTo!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),

                  // Bubble
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.hasImage) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              message.imageFile!,
                              width: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 200,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image_outlined,
                                        color: Colors.white70, size: 32),
                                    SizedBox(height: 6),
                                    Text('Image unavailable',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (message.content.isNotEmpty)
                            const SizedBox(height: 8),
                        ],
                        if (message.hasFile) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded,
                                    size: 18, color: Colors.redAccent),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    message.fileName!,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (message.content.isNotEmpty)
                            const SizedBox(height: 8),
                        ],
                        if (message.content.isNotEmpty)
                          isUser
                              ? Text(message.content,
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 14,
                                      height: 1.4))
                              : MarkdownBody(
                                  data: message.content,
                                  styleSheet: MarkdownStyleSheet(
                                    p: TextStyle(
                                        color: textColor,
                                        fontSize: 14,
                                        height: 1.4),
                                    strong: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF4D8EFF)
                                            : AppColors.primary,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                      ],
                    ),
                  ),

                  // Severity badge
                  if (message.severity != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _severityColor(message.severity!)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _severityColor(message.severity!)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '${_severityEmoji(message.severity!)} ${message.severity![0].toUpperCase()}${message.severity!.substring(1)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: _severityColor(message.severity!),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // Actions row (assistant only)
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: onReplay,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.volume_up_rounded,
                                    size: 14,
                                    color: AppColors.textMuted),
                                SizedBox(width: 3),
                                Text('Replay',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: onReply,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.reply_rounded,
                                    size: 14,
                                    color: AppColors.textMuted),
                                SizedBox(width: 3),
                                Text('Reply',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.lightGray,
                child: Icon(Icons.person_rounded,
                    size: 18, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary,
          child: Image.asset('assets/bot_icon.jpg',
              width: 20, height: 20, fit: BoxFit.contain),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Thinking',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 6),
              const _Dot(delay: 0),
              const SizedBox(width: 4),
              const _Dot(delay: 150),
              const SizedBox(width: 4),
              const _Dot(delay: 300),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const CircleAvatar(
          radius: 4, backgroundColor: AppColors.textMuted),
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final bool isListening;
  final File? pickedImage;
  final String? pickedFileName;
  final ChatMessage? replyTo;
  final bool isDark;
  final String? sttLocaleId;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onToggleMic;
  final VoidCallback onLongPressMic;
  final VoidCallback onClearAttachment;
  final VoidCallback onCancelReply;

  const _InputBar({
    required this.controller,
    required this.loading,
    required this.isListening,
    required this.onSend,
    required this.onAttach,
    required this.onToggleMic,
    required this.onLongPressMic,
    required this.onClearAttachment,
    required this.onCancelReply,
    required this.isDark,
    this.pickedImage,
    this.pickedFileName,
    this.replyTo,
    this.sttLocaleId,
  });

  bool get _hasAttachment => pickedImage != null || pickedFileName != null;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? const Color(0xFF1A1A2E) : AppColors.surface;
    final inputFill = isDark ? const Color(0xFF13131E) : AppColors.background;

    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview
          if (replyTo != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                    left: BorderSide(color: AppColors.secondary, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      replyTo!.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

          // Attachment preview
          if (_hasAttachment)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  if (pickedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(pickedImage!,
                          height: 90,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: inputFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.lightGray),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              color: Colors.redAccent, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pickedFileName!,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  GestureDetector(
                    onTap: onClearAttachment,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // Input row
          Row(
            children: [
              _IconBtn(
                icon: Icons.attach_file_rounded,
                onTap: loading ? null : onAttach,
                active: _hasAttachment,
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: isListening
                        ? 'Listening... speak now'
                        : 'Ask a medical question...',
                    hintStyle: TextStyle(
                      color: isListening
                          ? Colors.red
                          : (isDark ? Colors.white38 : AppColors.textMuted),
                    ),
                    border: const OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(24)),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: loading ? null : onToggleMic,
                    onLongPress: loading ? null : onLongPressMic,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isListening
                            ? Colors.redAccent.withValues(alpha: 0.12)
                            : (isDark ? const Color(0xFF13131E) : AppColors.background),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isListening
                            ? Icons.mic_rounded
                            : Icons.mic_none_outlined,
                        size: 22,
                        color: isListening
                            ? Colors.redAccent
                            : (loading
                                ? AppColors.textMuted
                                : (isDark ? Colors.white70 : AppColors.textPrimary)),
                      ),
                    ),
                  ),
                  if (sttLocaleId != null)
                    Text(
                      sttLocaleId!.startsWith('ar') ? 'AR' : sttLocaleId!.substring(0, 2).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isListening ? Colors.redAccent : AppColors.secondary,
                        height: 1.0,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: loading ? null : onSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: loading
                        ? AppColors.lightGray
                        : AppColors.secondary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textMuted),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final Color activeColor;
  final bool isDark;

  const _IconBtn({
    required this.icon,
    required this.isDark,
    this.onTap,
    this.active = false,
    this.activeColor = AppColors.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF13131E) : AppColors.background),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 22,
          color: active
              ? activeColor
              : (onTap == null
                  ? AppColors.textMuted
                  : (isDark ? Colors.white70 : AppColors.textPrimary)),
        ),
      ),
    );
  }
}
