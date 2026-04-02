import 'dart:io';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final File? imageFile;
  final String? fileName;
  final String? severity; // 'mild' | 'moderate' | 'severe'
  final String? replyTo;  // content of quoted message

  const ChatMessage({
    required this.role,
    required this.content,
    this.imageFile,
    this.fileName,
    this.severity,
    this.replyTo,
  });

  bool get isUser => role == 'user';
  bool get hasImage => imageFile != null;
  bool get hasFile => fileName != null;
}
