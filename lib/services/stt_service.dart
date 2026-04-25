import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  SttService() {
    _engine = SpeechToText();
  }

  late final SpeechToText _engine;
  bool _initialized = false;
  String _lastResult = '';

  Future<bool> initialize() async {
    if (_initialized) {
      return _engine.isAvailable;
    }
    _initialized = await _engine.initialize();
    return _engine.isAvailable;
  }

  bool get isAvailable => _initialized && _engine.isAvailable;

  bool get isListening => _engine.isListening;

  String get lastResult => _lastResult;

  Future<void> startListening({
    String localeId = 'en_US',
    void Function(String result)? onResult,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_engine.isAvailable || _engine.isListening) {
      return;
    }
    _lastResult = '';
    await _engine.listen(
      localeId: localeId,
      onResult: (result) {
        _lastResult = result.recognizedWords;
        onResult?.call(_lastResult);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<String> stopListening() async {
    if (_engine.isListening) {
      await _engine.stop();
    }
    return _lastResult;
  }

  Future<void> cancel() async {
    if (_engine.isListening) {
      await _engine.cancel();
    }
  }
}