import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import 'ws_channel_stub.dart' if (dart.library.io) 'ws_channel_io.dart';

class WebSocketService {
  WebSocketService();

  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> connect() async {
    await disconnect();

    try {
      final Map<String, String> headers = <String, String>{};
      final String key = AppConfig.apiKey.trim();
      if (key.isNotEmpty) {
        headers['Authorization'] = 'Bearer $key';
      }
      final WebSocketChannel channel = connectMochiWebSocket(
        AppConfig.webSocketUri,
        headers,
      );
      _channel = channel;
      _subscription = channel.stream.listen(
        (dynamic event) {
          if (event is! String) {
            return;
          }

          final dynamic decoded = jsonDecode(event);
          if (decoded is Map<String, dynamic>) {
            _events.add(decoded);
          }
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }
}
