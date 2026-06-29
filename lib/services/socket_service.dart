import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  static const String defaultUrl = 'ws://localhost:8080/ws/notifications';

  final String url;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<Map<String, dynamic>> _notificationsController =
      StreamController<Map<String, dynamic>>.broadcast();

  SocketService({this.url = defaultUrl});

  Stream<Map<String, dynamic>> get notifications =>
      _notificationsController.stream;

  void connect({required int userId}) {
    dispose();
    final uri = Uri.parse(url).replace(
      queryParameters: {'user_id': '$userId'},
    );
    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen(
      _handleMessage,
      onError: (_) {},
      onDone: () {},
      cancelOnError: true,
    );
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      if (data['type'] != 'notification') return;
      final notification = data['notification'];
      if (notification is Map<String, dynamic>) {
        _notificationsController.add(notification);
      } else if (notification is Map) {
        _notificationsController.add(Map<String, dynamic>.from(notification));
      }
    } catch (_) {
      // Ignore malformed socket payloads.
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void close() {
    dispose();
    _notificationsController.close();
  }
}
