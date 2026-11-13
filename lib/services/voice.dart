import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech in (dictation) and out (read answers aloud), in Colombian Spanish.
class Voice {
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  bool _sttReady = false;
  bool _ttsReady = false;

  bool get listening => _stt.isListening;

  Future<bool> _initStt() async {
    if (_sttReady) return true;
    _sttReady = await _stt.initialize();
    return _sttReady;
  }

  /// Listens until the person stops talking. [onPartial] shows live text; [onDone] gets the final text.
  Future<bool> listen({required void Function(String) onPartial, required void Function(String) onDone}) async {
    if (!await _initStt()) return false;
    final locales = await _stt.locales();
    final locale = locales.where((l) => l.localeId.toLowerCase().replaceAll('-', '_') == 'es_co').firstOrNull ??
        locales.where((l) => l.localeId.toLowerCase().startsWith('es')).firstOrNull;
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: locale?.localeId,
        partialResults: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 2),
        contextualPhrases: const ['pico y placa', 'gasolinera', 'check engine', 'Mazda'],
      ),
      onResult: (r) {
        if (r.finalResult) {
          onDone(r.recognizedWords);
        } else {
          onPartial(r.recognizedWords);
        }
      },
    );
    return true;
  }

  Future<void> stop() => _stt.stop();

  Future<void> say(String text) async {
    if (!_ttsReady) {
      await _tts.setLanguage('es-CO');
      await _tts.setSpeechRate(0.5);
      _ttsReady = true;
    }
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> quiet() => _tts.stop();
}
