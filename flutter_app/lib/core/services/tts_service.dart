import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;

  static Future<void> _init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.50);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  /// Speak [text], stripping markdown symbols first.
  static Future<void> speak(String text) async {
    await _init();
    await _tts.stop();
    final clean = text
        .replaceAll(RegExp(r'[*_`#>~]'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
    if (clean.isNotEmpty) await _tts.speak(clean);
  }

  static Future<void> stop() async => _tts.stop();
}
