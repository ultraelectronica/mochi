import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_models.dart';

enum ModelDownloadPhase { idle, downloading, verifying, done, failed, canceled }

class ModelDownloadState {
  const ModelDownloadState({
    required this.phase,
    this.model,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.message,
  });

  final ModelDownloadPhase phase;
  final LocalModel? model;
  final int receivedBytes;
  final int totalBytes;
  final String? message;

  double get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  bool get isActive =>
      phase == ModelDownloadPhase.downloading ||
      phase == ModelDownloadPhase.verifying;
}

/// Downloads, stores, and selects the on-device GGUF model.
///
/// Files live in `<app support>/models/`. Downloads are resumable: a
/// partial file is kept as `<name>.part` and resumed with a `Range`
/// header on retry.
class ModelManager extends ChangeNotifier {
  ModelManager._();

  static final ModelManager instance = ModelManager._();

  static const String _selectedModelKey = 'mochi.model.id';

  LocalModel _selected = LocalModels.defaultModel;
  ModelDownloadState _state = const ModelDownloadState(
    phase: ModelDownloadPhase.idle,
  );
  bool _cancelled = false;

  /// Fired when a download finishes and the model becomes usable.
  Future<void> Function()? onInstalled;

  LocalModel get selected => _selected;
  ModelDownloadState get state => _state;

  Future<Directory> _modelsDir() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory dir = Directory(p.join(support.path, 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> fileFor(LocalModel model) async {
    final Directory dir = await _modelsDir();
    return File(p.join(dir.path, model.fileName));
  }

  Future<File> partFileFor(LocalModel model) async {
    final Directory dir = await _modelsDir();
    return File(p.join(dir.path, '${model.fileName}.part'));
  }

  Future<bool> isInstalled(LocalModel model) async {
    final File file = await fileFor(model);
    if (!await file.exists()) {
      return false;
    }
    return (await file.length()) == model.downloadBytes;
  }

  Future<LocalModel> installedModel() async {
    for (final LocalModel model in LocalModels.all) {
      if (await isInstalled(model)) {
        return model;
      }
    }
    return LocalModels.defaultModel;
  }

  Future<bool> selectedInstalled() async {
    await _ensureSelection();
    return isInstalled(_selected);
  }

  Future<void> selectModel(LocalModel model) async {
    _selected = model;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, model.id);
    notifyListeners();
  }

  Future<void> _ensureSelection() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? id = prefs.getString(_selectedModelKey);
    _selected = LocalModels.byId(id);
  }

  Future<void> downloadModel(
    LocalModel model, {
    int chunkCallbackEveryMs = 120,
  }) async {
    if (_state.isActive) {
      return;
    }
    _cancelled = false;

    final File target = await fileFor(model);
    final File part = await partFileFor(model);

    if (await target.exists() && (await target.length()) == model.downloadBytes) {
      _setState(
        ModelDownloadState(
          phase: ModelDownloadPhase.done,
          model: model,
          receivedBytes: model.downloadBytes,
          totalBytes: model.downloadBytes,
          message: 'Already downloaded.',
        ),
      );
      await selectModel(model);
      onInstalled?.call();
      return;
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      _setState(
        ModelDownloadState(
          phase: ModelDownloadPhase.downloading,
          model: model,
          receivedBytes: await part.exists() ? await part.length() : 0,
          totalBytes: model.downloadBytes,
          message: attempt > 0 ? 'Reconnecting (attempt ${attempt + 1}/3)…' : null,
        ),
      );

      try {
        await _attemptDownload(model, target, part, chunkCallbackEveryMs);
        return;
      } on http.ClientException catch (error) {
        if (_cancelled) {
          _setCanceled(model);
          return;
        }
        if (attempt == 2) {
          _setFailed(model, error.toString());
        }
      } on HttpException catch (error) {
        if (_cancelled) {
          _setCanceled(model);
          return;
        }
        if (attempt == 2) {
          _setFailed(model, error.message);
        }
      } on TimeoutException catch (error) {
        if (_cancelled) {
          _setCanceled(model);
          return;
        }
        if (attempt == 2) {
          _setFailed(model, error.toString());
        }
      } on FileSystemException catch (error) {
        if (_cancelled) {
          _setCanceled(model);
          return;
        }
        if (attempt == 2) {
          _setFailed(model, error.message);
        }
      } catch (error) {
        _setFailed(model, error.toString());
        return;
      }
    }
  }

  void _setCanceled(LocalModel model) {
    _cancelled = false;
    _setState(
      ModelDownloadState(
        phase: ModelDownloadPhase.canceled,
        model: model,
      ),
    );
  }

  void _setFailed(LocalModel model, String message) {
    _cancelled = false;
    _setState(
      ModelDownloadState(
        phase: ModelDownloadPhase.failed,
        model: model,
        message: message,
      ),
    );
  }

  /// One download run, resumable from the partial file. Throws on failure
  /// so [downloadModel] can retry.
  Future<void> _attemptDownload(
    LocalModel model,
    File target,
    File part,
    int chunkCallbackEveryMs,
  ) async {
    final http.Client client = http.Client();
    int existing = 0;
    if (await part.exists()) {
      existing = await part.length();
    }

    try {
      final http.Request request = http.Request('GET', Uri.parse(model.url));
      if (existing > 0 && existing < model.downloadBytes) {
        request.headers['Range'] = 'bytes=$existing-';
      }
      final http.StreamedResponse response = await client
          .send(request)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(
          'Download failed (HTTP ${response.statusCode})',
          uri: Uri.parse(model.url),
        );
      }

      final bool resumed = response.statusCode == 206;
      final int contentLength = response.contentLength ?? -1;
      final int total = resumed && contentLength >= 0
          ? existing + contentLength
          : contentLength > 0
              ? contentLength
              : model.downloadBytes;

      _setState(
        ModelDownloadState(
          phase: ModelDownloadPhase.downloading,
          model: model,
          receivedBytes: existing,
          totalBytes: total,
        ),
      );

      final IOSink sink = part.openWrite(mode: FileMode.append);
      int received = existing;
      DateTime lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

      try {
      final Stream<List<int>> stream = response.stream.timeout(
        const Duration(seconds: 45),
        onTimeout: (EventSink<List<int>> sink) {
          sink.addError(
            TimeoutException('Stream stalled — no data for 45s'),
          );
        },
      );
        await for (final List<int> chunk in stream) {
          if (_cancelled) {
            throw const FileSystemException('Download canceled');
          }
          sink.add(chunk);
          received += chunk.length;

          final DateTime now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds >= chunkCallbackEveryMs) {
            lastNotify = now;
            _setState(
              ModelDownloadState(
                phase: ModelDownloadPhase.downloading,
                model: model,
                receivedBytes: received,
                totalBytes: total,
              ),
            );
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      _setState(
        ModelDownloadState(
          phase: ModelDownloadPhase.verifying,
          model: model,
          receivedBytes: received,
          totalBytes: total,
        ),
      );

      if (received != model.downloadBytes) {
        throw FileSystemException(
          'Incomplete file: expected ${model.downloadBytes} bytes, got $received',
        );
      }

      if (await target.exists()) {
        await target.delete();
      }
      await part.rename(target.path);
      _setState(
        ModelDownloadState(
          phase: ModelDownloadPhase.done,
          model: model,
          receivedBytes: model.downloadBytes,
          totalBytes: model.downloadBytes,
        ),
      );
      await selectModel(model);
      onInstalled?.call();
    } finally {
      client.close();
    }
  }

  Future<void> cancelDownload() async {
    _cancelled = true;
  }

  Future<void> deleteModel(LocalModel model) async {
    final File file = await fileFor(model);
    final File part = await partFileFor(model);
    if (await file.exists()) {
      await file.delete();
    }
    if (await part.exists()) {
      await part.delete();
    }
    if (_selected.id == model.id) {
      await selectModel(LocalModels.defaultModel);
    }
    notifyListeners();
  }

  void resetState() {
    _setState(const ModelDownloadState(phase: ModelDownloadPhase.idle));
  }

  double? installedSizeMiB(LocalModel model) {
    return model.downloadBytes / (1024 * 1024);
  }

  void _setState(ModelDownloadState state) {
    _state = state;
    notifyListeners();
  }
}
