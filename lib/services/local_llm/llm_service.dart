import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../../config/game_config.dart';
import 'local_models.dart';
import 'model_manager.dart';
import 'prompt_builder.dart';
import 'reply_sanitizer.dart';

enum LlmEngineState { idle, loading, ready, error }

/// Owns the on-device llama.cpp worker isolate.
///
/// Loads the selected GGUF, services streaming chat replies for the AI
/// companion, and unloads to free RAM.
class LlmService extends ChangeNotifier {
  LlmService._();

  static final LlmService instance = LlmService._();

  LlamaEngine? _engine;
  LlmEngineState _state = LlmEngineState.idle;
  String? _error;
  LocalModel? _loadedModel;

  LlmEngineState get state => _state;
  String? get error => _error;
  LocalModel? get loadedModel => _loadedModel;
  bool get isReady => _state == LlmEngineState.ready;
  String? get accelerator {
    final LlamaEngine? engine = _engine;
    return engine == null || !engine.hasAccelerator
        ? null
        : engine.primaryAcceleratorName;
  }

  /// Loads the model selected in [ModelManager]. No-op when the same model
  /// is already loaded.
  Future<void> ensureLoaded(LocalModel model) async {
    if (_engine != null && _loadedModel?.id == model.id && isReady) {
      return;
    }
    await load(model);
  }

  Future<void> load(LocalModel model) async {
    await unload();
    _state = LlmEngineState.loading;
    _loadedModel = model;
    _error = null;
    notifyListeners();

    final String path = (await ModelManager.instance.fileFor(model)).path;

    try {
      _engine = await LlamaEngine.spawn(
        modelParams: ModelParams(path: path),
        contextParams: ContextParams(nCtx: GameConfig.defaultContextSize),
      );
      _state = LlmEngineState.ready;
    } catch (error) {
      _state = LlmEngineState.error;
      _error = error.toString();
      debugPrint('[LlmService] load failed: $error');
    }
    notifyListeners();
  }

  /// Generates a Mochi reply for [messages].
  ///
  /// Returns the cleaned reply text, or `null` when the model produced
  /// nothing usable. [onToken] receives each streamed token for live UI.
  Future<String?> reply({
    required List<LlmChatMessage> messages,
    String? userText,
    bool think = false,
    void Function(String token)? onToken,
  }) async {
    final LlamaEngine? engine = _engine;
    if (engine == null || !isReady) {
      return null;
    }

    final SamplerParams sampler = SamplerParams(
      temperature: GameConfig.temperature,
      topP: 0.9,
    );

    // LFM2.5 GGUFs embed a ChatML-style Jinja template. Some builds use a
    // Jinja blob the matcher can't parse, so fall back to the known ChatML
    // substring and retry on a fresh chat handle.
    for (final String? templateOverride in <String?>[
      null,
      KnownChatTemplates.chatml,
    ]) {
      final EngineChat chat = await engine.createChat();
      try {
        for (final LlmChatMessage message in messages) {
          if (message.role == 'system') {
            chat.addSystem(message.content);
          } else if (message.role == 'assistant') {
            chat.addAssistant(message.content);
          } else {
            chat.addUser(message.content);
          }
        }

        final StringBuffer buffer = StringBuffer();
        try {
          await for (final GenerationEvent event in chat.generate(
            sampler: sampler,
            maxTokens: think
                ? GameConfig.thinkMaxReplyTokens
                : GameConfig.maxReplyTokens,
            templateOverride: templateOverride,
          )) {
            if (event is TokenEvent) {
              buffer.write(event.text);
              onToken?.call(event.text);
            }
          }
        } on ChatTemplateException {
          if (templateOverride != null) {
            rethrow;
          }
          continue;
        }

        final String cleaned =
            ReplySanitizer.clean(buffer.toString(), userText: userText);
        if (cleaned.isEmpty) {
          return null;
        }
        return cleaned;
      } finally {
        await chat.dispose();
      }
    }
    return null;
  }

  Future<void> unload() async {
    final LlamaEngine? engine = _engine;
    _engine = null;
    if (engine != null) {
      try {
        await engine.dispose();
      } catch (error) {
        debugPrint('[LlmService] unload error: $error');
      }
    }
    _state = LlmEngineState.idle;
    _loadedModel = null;
    _error = null;
    notifyListeners();
  }
}
