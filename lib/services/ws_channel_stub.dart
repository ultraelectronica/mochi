import 'package:web_socket_channel/web_socket_channel.dart';

/// Web and other platforms without `dart:io`: custom WebSocket headers are not applied.
WebSocketChannel connectMochiWebSocket(Uri uri, Map<String, String> headers) {
  return WebSocketChannel.connect(uri);
}
