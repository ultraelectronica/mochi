import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';

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
      final WebSocketChannel channel = WebSocketChannel.connect(
        AppConfig.webSocketUri,
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
