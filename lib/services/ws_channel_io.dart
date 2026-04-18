import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// VM / mobile / desktop: send `Authorization` on the WebSocket upgrade when provided.
WebSocketChannel connectMochiWebSocket(Uri uri, Map<String, String> headers) {
  if (headers.isEmpty) {
    return WebSocketChannel.connect(uri);
  }
  return IOWebSocketChannel.connect(uri, headers: headers);
}
