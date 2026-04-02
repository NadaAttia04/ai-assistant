class ChatSessionMeta {
  final String id;
  final String title;
  final String createdAt;

  const ChatSessionMeta({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory ChatSessionMeta.fromJson(Map<String, dynamic> json) => ChatSessionMeta(
        id: json['_id'] as String,
        title: json['title'] as String? ?? 'New Chat',
        createdAt: json['created_at'] as String? ?? '',
      );

  String get formattedDate {
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return 'Today $h:$m';
      }
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
