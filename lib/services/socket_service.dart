import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  final String url;
  IO.Socket? _socket;

  SocketService({this.url = 'https://example.com'});

  void connect() {
    _socket = IO.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket?.on('connect', (_) {
      // ignore: avoid_print
      print('Socket connected: [32m${_socket?.id}\u001b[0m');
    });

    _socket?.on('disconnect', (_) {
      // ignore: avoid_print
      print('Socket disconnected');
    });

    _socket?.connect();
  }

  void sendEvent(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void dispose() {
    _socket?.disconnect();
  }
}
