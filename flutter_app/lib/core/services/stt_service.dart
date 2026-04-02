import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  static final SpeechToText _stt = SpeechToText();
  static bool _initialized = false;
  static List<LocaleName> _locales = [];

  static Future<bool> _init() async {
    if (_initialized) return true;
    _initialized = await _stt.initialize(
      onError: (e) => debugPrint('[STT] error: $e'),
    );
    if (_initialized) {
      _locales = await _stt.locales();
    }
    return _initialized;
  }

  /// Returns the best Arabic locale ID available on the device.
  /// Returns null if no Arabic locale is installed.
  static Future<String?> getArabicLocale() async {
    await _init();
    // Try common Arabic locales in order of preference
    const preferred = ['ar-SA', 'ar-EG', 'ar-AE', 'ar-MA', 'ar-DZ', 'ar'];
    for (final id in preferred) {
      if (_locales.any((l) => l.localeId.startsWith(id) || l.localeId == id)) {
        final match = _locales.firstWhere(
          (l) => l.localeId.startsWith(id) || l.localeId == id,
        );
        return match.localeId;
      }
    }
    // Also search by name
    final arabicByName = _locales.where(
      (l) => l.name.toLowerCase().contains('arabic') || l.name.contains('عربي'),
    );
    if (arabicByName.isNotEmpty) return arabicByName.first.localeId;
    return null;
  }

  /// Start listening.
  /// [localeId]: pass a locale like 'ar-SA', 'ar-EG', 'en-US', or null for device default.
  static Future<bool> startListening({
    required void Function(String words) onResult,
    required void Function() onDone,
    String? localeId,
  }) async {
    if (!await _init()) return false;

    await _stt.listen(
      onResult: (r) {
        if (r.recognizedWords.isNotEmpty) {
          onResult(r.recognizedWords);
        }
        if (r.finalResult) onDone();
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
      ),
    );
    return true;
  }

  static Future<void> stopListening() => _stt.stop();

  static bool get isListening => _stt.isListening;

  static Future<List<LocaleName>> getLocales() async {
    await _init();
    return _locales;
  }
}
