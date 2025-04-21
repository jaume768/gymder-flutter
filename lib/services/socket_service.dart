import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class SocketService {
  static final Map<String, SocketService> _instances = {};
  IO.Socket? socket;
  final String _currentUserId;
  final String _matchedUserId;
  final String _serverUrl;
  final String _token;

  // Callbacks
  Function? _onConnectCallback;
  Function? _onDisconnectCallback;
  Function(dynamic)? _onErrorCallback;
  Function(dynamic)? _onReceiveMessageCallback;
  Function(dynamic)? _onMessagesMarkedAsReadCallback;
  Function(dynamic)? _onUserTypingCallback;
  Function(dynamic)? _onUserStoppedTypingCallback;
  Function(dynamic)? _onUserOnlineCallback;
  Function(dynamic)? _onUserOfflineCallback;

  factory SocketService(
    String serverUrl,
    String token,
    String currentUserId,
    String matchedUserId,
  ) {
    final key = '$currentUserId-$matchedUserId';
    if (!_instances.containsKey(key)) {
      _instances[key] = SocketService._internal(
        serverUrl,
        token,
        currentUserId,
        matchedUserId,
      );
    }
    return _instances[key]!;
  }

  SocketService._internal(
    this._serverUrl,
    this._token,
    this._currentUserId,
    this._matchedUserId,
  );

  void connect() {
    // Disconnect existing socket if any
    disconnect();

    // Initialize socket
    socket = IO.io(_serverUrl,
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setExtraHeaders({'Authorization': 'Bearer $_token'})
        .build()
    );

    socket!.connect();
    
    socket!.onConnect((_) {
      joinRoom();
      if (_onConnectCallback != null) {
        _onConnectCallback!();
      }
    });

    socket!.onDisconnect((_) {
      if (_onDisconnectCallback != null) {
        _onDisconnectCallback!();
      }
    });

    socket!.onError((error) {
      if (_onErrorCallback != null) {
        _onErrorCallback!(error);
      }
    });

    socket!.on('receiveMessage', (data) {
      if (_onReceiveMessageCallback != null) {
        _onReceiveMessageCallback!(data);
      }
    });

    socket!.on('messagesMarkedAsRead', (data) {
      if (_onMessagesMarkedAsReadCallback != null) {
        _onMessagesMarkedAsReadCallback!(data);
      }
    });

    socket!.on('userTyping', (data) {
      if (_onUserTypingCallback != null) {
        _onUserTypingCallback!(data);
      }
    });

    socket!.on('userStoppedTyping', (data) {
      if (_onUserStoppedTypingCallback != null) {
        _onUserStoppedTypingCallback!(data);
      }
    });

    // Eventos de presencia
    socket!.on('userOnline', (data) {
      if (_onUserOnlineCallback != null) {
        _onUserOnlineCallback!(data);
      }
    });
    socket!.on('userOffline', (data) {
      if (_onUserOfflineCallback != null) {
        _onUserOfflineCallback!(data);
      }
    });
  }

  void joinRoom() {
    if (socket != null && socket!.connected) {
      socket!.emit('joinRoom', {
        'userId': _currentUserId,
        'matchedUserId': _matchedUserId
      });
    }
  }

  void sendMessage(
    String message, {
    String type = 'text',
    String? imageUrl,
    String? audioUrl,
    double? audioDuration,
    String? videoUrl,
    double? videoDuration,
  }) {
    if (socket != null && socket!.connected) {
      socket!.emit('sendMessage', {
        'senderId': _currentUserId,
        'receiverId': _matchedUserId,
        'message': message,
        'type': type,
        'imageUrl': imageUrl ?? '',
        'audioUrl': audioUrl ?? '',
        'audioDuration': audioDuration ?? 0,
        'videoUrl': videoUrl ?? '',
        'videoDuration': videoDuration ?? 0,
      });
    }
  }

  void markAsRead() {
    if (socket != null && socket!.connected) {
      socket!.emit('markAsRead', {
        'userId': _currentUserId,
        'matchedUserId': _matchedUserId
      });
    }
  }

  void userTyping() {
    if (socket != null && socket!.connected) {
      socket!.emit('userTyping', {
        'userId': _currentUserId,
        'matchedUserId': _matchedUserId
      });
    }
  }

  void userStoppedTyping() {
    if (socket != null && socket!.connected) {
      socket!.emit('userStoppedTyping', {
        'userId': _currentUserId,
        'matchedUserId': _matchedUserId
      });
    }
  }

  // Callback setters
  void onConnect(Function callback) {
    _onConnectCallback = callback;
  }

  void onDisconnect(Function callback) {
    _onDisconnectCallback = callback;
  }

  void onError(Function(dynamic) callback) {
    _onErrorCallback = callback;
  }

  void onReceiveMessage(Function(dynamic) callback) {
    _onReceiveMessageCallback = callback;
  }

  void onMessagesMarkedAsRead(Function(dynamic) callback) {
    _onMessagesMarkedAsReadCallback = callback;
  }

  void onUserTyping(Function(dynamic) callback) {
    _onUserTypingCallback = callback;
  }

  void onUserStoppedTyping(Function(dynamic) callback) {
    _onUserStoppedTypingCallback = callback;
  }

  /// Registra callback cuando un usuario se conecta
  void onUserOnline(Function(dynamic) callback) {
    _onUserOnlineCallback = callback;
  }

  /// Registra callback cuando un usuario se desconecta
  void onUserOffline(Function(dynamic) callback) {
    _onUserOfflineCallback = callback;
  }

  void disconnect() {
    socket?.disconnect();
    socket = null;
  }

  void dispose() {
    disconnect();
    final key = '$_currentUserId-$_matchedUserId';
    _instances.remove(key);
  }

  bool get isConnected => socket?.connected ?? false;
  bool get isDisconnected => !isConnected;
}
