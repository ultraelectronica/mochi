import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService() {
    _engine = FlutterTts();
    _init();
  }

  late final FlutterTts _engine;
  bool _ready = false;

  Future<void> _init() async {
    await _engine.setLanguage('en-US');
    await _engine.setSpeechRate(0.45);
    await _engine.setPitch(1.1);
    await _engine.awaitSpeakCompletion(true);
    _ready = true;
  }

  Future<void> speak(String text) async {
    if (!_ready) {
      await _init();
    }
    await _engine.stop();
    await _engine.speak(text);
  }

  Future<void> stop() async {
    await _engine.stop();
  }

  Future<void> dispose() async {
    await _engine.stop();
  }
}