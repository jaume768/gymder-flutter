import 'dart:convert';
import 'dart:io';

import 'package:app/screens/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

import '../providers/auth_provider.dart';
import '../models/user.dart';

/// Pantalla para ver imagen en pantalla completa
class FullScreenImageScreen extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageScreen({Key? key, required this.imageUrl})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String matchedUserId;

  const ChatScreen({
    Key? key,
    required this.currentUserId,
    required this.matchedUserId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late IO.Socket socket;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final DateFormat timeFormatter = DateFormat('hh:mm a');

  // Lista de mensajes; cada mensaje es un Map con campos: _id, senderId, type, message, imageUrl, timestamp, seenAt y opcional isLoading o pending
  List<Map<String, dynamic>> messages = [];

  // Variables para paginación
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;

  // Variables para emojis y estado de conexión
  bool _showEmojiPicker = false;
  bool _isConnected = true;
  List<Map<String, dynamic>> _pendingMessages = [];

  User? matchedUser;
  bool isLoadingUser = true;
  // Estado en línea del matchedUser
  bool matchedUserOnline = false;

  @override
  void initState() {
    super.initState();
    _connectToSocket();
    _fetchConversation();
    _fetchMatchedUser();

    // Listener para detectar cuando el usuario llega al inicio de la lista y cargar más mensajes
    _scrollController.addListener(() {
      if (_scrollController.position.pixels <=
              _scrollController.position.minScrollExtent + 200 &&
          !_isLoadingMoreMessages &&
          _hasMoreMessages) {
        _loadMoreMessages();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  // Función para comprimir imágenes antes de enviarlas
  Future<File> _compressImage(File imageFile) async {
    // Obtener la extensión del archivo
    final fileName = path.basename(imageFile.path);
    final extension = path.extension(fileName);

    // Obtener directorio temporal para guardar la imagen comprimida
    final dir = await getTemporaryDirectory();
    final targetPath = path.join(dir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}$extension');

    // Determinar el formato de compresión
    CompressFormat format;
    if (extension.toLowerCase() == '.png') {
      format = CompressFormat.png;
    } else if (extension.toLowerCase() == '.heic') {
      format = CompressFormat.heic;
    } else {
      format = CompressFormat.jpeg;
    }

    var result = await FlutterImageCompress.compressAndGetFile(
      imageFile.path,
      targetPath,
      quality: 70, // Calidad de compresión (0-100)
      minWidth: 1000, // Ancho mínimo
      minHeight: 1000, // Alto mínimo
      format: format, // Formato de compresión
    );

    if (result == null) {
      print(tr("error_compressing_image"));
      return imageFile; // Devolver la imagen original si hay error
    }

    return File(result.path);
  }

  Future<void> _fetchMatchedUser() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;
      final url = Uri.parse(
          'https://gymder-api-production.up.railway.app/api/users/profile/${widget.matchedUserId}');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['user'] != null) {
          setState(() {
            matchedUser = User.fromJson(data['user']);
            isLoadingUser = false;
          });
        } else {
          print(tr("user_not_found"));
        }
      } else {
        print(tr("error_fetching_user_data") + ": ${response.statusCode}");
      }
    } catch (e) {
      print(tr("error_fetching_user_data") + ": $e");
    }
  }

  // Modificada para comprimir la imagen antes de enviarla y eliminar el mensaje de carga en caso de error
  Future<void> _sendImageMessage(File imageFile) async {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    // Mostrar mensaje con estado "cargando"
    setState(() {
      messages.add({
        '_id': tempId,
        'senderId': widget.currentUserId,
        'type': 'image',
        'message': '',
        'imageUrl': '',
        'timestamp': DateTime.now().toIso8601String(),
        'seenAt': null,
        'isLoading': true,
      });
    });
    _scrollToBottom();

    try {
      // Comprimir la imagen antes de enviarla
      final compressedImage = await _compressImage(imageFile);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        print(tr("token_not_found_login"));
        return;
      }
      final url = Uri.parse(
          'https://gymder-api-production.up.railway.app/api/messages/upload');
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      final mimeType =
          lookupMimeType(compressedImage.path) ?? 'application/octet-stream';
      final mimeTypeData = mimeType.split('/');
      if (mimeTypeData.length != 2) {
        throw Exception(tr("unknown_file_type"));
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'chatImage',
          compressedImage.path,
          contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final imageUrl = data['url'];
          socket.emit('sendMessage', {
            'senderId': widget.currentUserId,
            'receiverId': widget.matchedUserId,
            'type': 'image',
            'imageUrl': imageUrl,
          });
          _scrollToBottom();
        } else {
          print(tr("error_sending_image") + ": ${data['message']}");
          // Eliminar el mensaje de carga si hay error
          setState(() {
            messages.removeWhere((msg) => msg['_id'] == tempId);
          });
        }
      } else {
        print(tr("error_sending_image") +
            ": ${response.statusCode}\n" +
            tr("response_body") +
            ": ${response.body}");
        // Eliminar el mensaje de carga si hay error
        setState(() {
          messages.removeWhere((msg) => msg['_id'] == tempId);
        });
      }
    } catch (e) {
      print(tr("error_sending_image") + ": $e");
      // Eliminar el mensaje de carga si hay error
      setState(() {
        messages.removeWhere((msg) => msg['_id'] == tempId);
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      await _sendImageMessage(file);
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  Future<void> _hideMessage(String messageId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;
      final url = Uri.parse(
          'https://gymder-api-production.up.railway.app/api/messages/$messageId/hide');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          for (var msg in messages) {
            if (msg['senderId'] == widget.matchedUserId &&
                msg['seenAt'] == null) {
              msg['seenAt'] = DateTime.now().toIso8601String();
            }
          }
        });
      } else {
        print(tr("error_hiding_message") +
            ": ${response.statusCode}\n" +
            tr("response_body") +
            ": ${response.body}");
      }
    } catch (e) {
      print(tr("error_hiding_message") + ": $e");
    }
  }

  Widget _buildMessageItem(Map<String, dynamic> msg) {
    final bool isMe = msg['senderId'] == widget.currentUserId;
    final String type = msg['type'] ?? 'text';

    if (type == 'image') {
      if (msg['isLoading'] == true) {
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: isMe ? Colors.white : Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        );
      } else {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FullScreenImageScreen(imageUrl: msg['imageUrl']),
              ),
            );
          },
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: isMe ? Colors.white : Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.network(
                msg['imageUrl'],
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }
    } else {
      final timestamp = msg['timestamp'];
      DateTime dateTime;
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        dateTime = DateTime.now();
      }
      final formattedTime = timeFormatter.format(dateTime);

      return GestureDetector(
        onLongPress: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) {
              return AlertDialog(
                title: Text(tr("delete_message")),
                content: Text(tr("delete_message_confirm")),
                actions: [
                  TextButton(
                    child: Text(tr("cancel")),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  TextButton(
                    child: Text(tr("delete")),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              );
            },
          );
          if (confirm == true && msg['_id'] != null && msg['_id'] != '') {
            _hideMessage(msg['_id']);
          }
        },
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              minWidth: 80,
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            decoration: BoxDecoration(
              color: isMe ? Colors.white : Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 24,
                    top: 10,
                    bottom: 15,
                  ),
                  child: Text(
                    msg['message'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.black : Colors.white,
                      fontSize: 19,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.black : Colors.white70,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 16,
                          color:
                              msg['seenAt'] != null ? Colors.blue : Colors.grey,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // Nueva función para cargar más mensajes (paginación)
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMoreMessages || !_hasMoreMessages) return;

    setState(() {
      _currentPage++;
    });

    await _fetchConversation();
  }

  // Función modificada para obtener la conversación con paginación
  Future<void> _fetchConversation() async {
    try {
      setState(() {
        _isLoadingMoreMessages = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        print(tr("token_not_found_login"));
        setState(() {
          _isLoadingMoreMessages = false;
        });
        return;
      }

      // Calculamos el límite y offset para la paginación
      final limit = _pageSize;
      final skip = (_currentPage - 1) * _pageSize;

      final url = Uri.parse(
          'https://gymder-api-production.up.railway.app/api/messages/conversation'
          '?user1=${widget.currentUserId}&user2=${widget.matchedUserId}'
          '&limit=$limit&skip=$skip');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> msgs = data['messages'];

          // Verificar si hay más mensajes para cargar
          setState(() {
            _hasMoreMessages = msgs.length >= _pageSize;

            // Si es la primera página, reemplazamos los mensajes;
            // si no, los agregamos al principio de la lista.
            if (_currentPage == 1) {
              messages = msgs.map((m) {
                return {
                  '_id': m['_id'],
                  'senderId': m['sender'],
                  'type': m['type'],
                  'message': m['message'],
                  'imageUrl': m['imageUrl'],
                  'timestamp': m['createdAt'],
                  'seenAt': m['seenAt'],
                };
              }).toList();
            } else {
              final newMessages = msgs.map((m) {
                return {
                  '_id': m['_id'],
                  'senderId': m['sender'],
                  'type': m['type'],
                  'message': m['message'],
                  'imageUrl': m['imageUrl'],
                  'timestamp': m['createdAt'],
                  'seenAt': m['seenAt'],
                };
              }).toList();

              messages.insertAll(0, newMessages);
            }

            _isLoadingMoreMessages = false;
          });

          // Solo hacer scroll al fondo en la primera carga
          if (_currentPage == 1) {
            _scrollToBottom();
          }
        } else {
          print(tr("error_fetching_messages") + ": ${data['message']}");
          setState(() {
            _isLoadingMoreMessages = false;
          });
        }
      } else {
        print(tr("error_fetching_messages") +
            ": ${response.statusCode}\n" +
            tr("response_body") +
            ": ${response.body}");
        setState(() {
          _isLoadingMoreMessages = false;
        });
      }
    } catch (e) {
      print(tr("error_fetching_messages") + ": $e");
      setState(() {
        _isLoadingMoreMessages = false;
      });
    }
  }

  // Función para reenviar mensajes pendientes luego de reconectar
  Future<void> _resendPendingMessages() async {
    if (_pendingMessages.isEmpty) return;

    List<Map<String, dynamic>> messagesToSend = List.from(_pendingMessages);
    _pendingMessages.clear();

    for (var msg in messagesToSend) {
      if (msg['type'] == 'text') {
        socket.emit('sendMessage', {
          'senderId': widget.currentUserId,
          'receiverId': widget.matchedUserId,
          'type': 'text',
          'message': msg['message'],
        });
      } else if (msg['type'] == 'image' && msg['imageUrl'] != null) {
        socket.emit('sendMessage', {
          'senderId': widget.currentUserId,
          'receiverId': widget.matchedUserId,
          'type': 'image',
          'imageUrl': msg['imageUrl'],
        });
      }
      // Pausa breve entre mensajes para evitar sobrecarga
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  // Función para conectar al socket con reconexión y manejo de estado
  void _connectToSocket() {
    socket = IO.io(
      'https://gymder-api-production.up.railway.app',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection() // Habilitar reconexión automática
          .setReconnectionAttempts(10) // Intentos de reconexión
          .setReconnectionDelay(1000) // Tiempo entre intentos (ms)
          .setReconnectionDelayMax(5000) // Tiempo máximo entre intentos (ms)
          .setRandomizationFactor(0.5) // Factor de aleatorización
          .build(),
    );
    socket.connect();

    socket.onConnect((_) {
      print('Connected to socket.io server');
      setState(() {
        _isConnected = true;
      });

      // Al reconectar, unirse nuevamente a la sala y reenviar los mensajes pendientes
      socket.emit('joinRoom', {
        'userId': widget.currentUserId,
        'matchedUserId': widget.matchedUserId,
      });

      socket.emit('markAsRead', {
        'userId': widget.currentUserId,
        'matchedUserId': widget.matchedUserId,
      });

      // Reenviar mensajes pendientes
      _resendPendingMessages();
    });

    socket.onConnectError((error) {
      print('Connection error: $error');
      setState(() {
        _isConnected = false;
      });
    });

    socket.onDisconnect((_) {
      print('Disconnected from server');
      setState(() {
        _isConnected = false;
      });
    });

    // Resto de los listeners (receiveMessage, messagesMarkedAsRead, userStatus, errorMessage)
    socket.on('receiveMessage', (data) {
      if (data['type'] == 'image' && data['senderId'] == widget.currentUserId) {
        final index = messages.indexWhere((m) =>
            m['isLoading'] == true && m['senderId'] == widget.currentUserId);
        if (index != -1) {
          setState(() {
            messages[index] = {
              '_id': data['_id'] ?? '',
              'senderId': data['senderId'],
              'type': data['type'] ?? 'text',
              'message': data['message'] ?? '',
              'imageUrl': data['imageUrl'] ?? '',
              'timestamp': data['timestamp'],
              'seenAt': data['seenAt'],
            };
          });
          _scrollToBottom();
          return;
        }
      }
      setState(() {
        messages.add({
          '_id': data['_id'] ?? '',
          'senderId': data['senderId'],
          'type': data['type'] ?? 'text',
          'message': data['message'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'timestamp': data['timestamp'],
          'seenAt': data['seenAt'],
        });
      });
      _scrollToBottom();
    });

    socket.on('messagesMarkedAsRead', (data) {
      print('Messages marked as read: $data');
      setState(() {
        for (var msg in messages) {
          if (msg['senderId'] == widget.matchedUserId &&
              msg['seenAt'] == null) {
            msg['seenAt'] = DateTime.now().toIso8601String();
          }
        }
      });
    });

    socket.on('userStatus', (data) {
      if (data['userId'] == widget.matchedUserId) {
        setState(() {
          matchedUserOnline = data['online'];
        });
      }
    });

    socket.on('errorMessage', (data) => print('Server error: $data'));
  }

  // Modificada para manejar mensajes pendientes y conexión
  void _sendMessage() {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    // Crear el objeto de mensaje
    final messageObj = {
      'senderId': widget.currentUserId,
      'receiverId': widget.matchedUserId,
      'type': 'text',
      'message': msg,
    };

    // Añadir mensaje a la lista local inmediatamente
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      messages.add({
        '_id': tempId,
        'senderId': widget.currentUserId,
        'type': 'text',
        'message': msg,
        'imageUrl': '',
        'timestamp': DateTime.now().toIso8601String(),
        'seenAt': null,
        'pending': !_isConnected, // Marcar como pendiente si no hay conexión
      });
    });

    // Limpiar el campo de texto
    _messageController.clear();

    // Enviar el mensaje si hay conexión, o guardarlo para enviar después
    if (_isConnected) {
      socket.emit('sendMessage', messageObj);
    } else {
      // Guardar en la lista de mensajes pendientes
      _pendingMessages.add({
        ...messageObj,
        '_id': tempId,
      });

      // Mostrar notificación al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr("message_queued_offline")),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }

    _scrollToBottom();
  }

  // Función para hacer scroll hasta el fondo de la lista de mensajes
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Indicador de carga para la paginación (cuando se cargan más mensajes)
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(
        strokeWidth: 2,
      ),
    );
  }

  @override
  void dispose() {
    socket.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar con indicador de conexión y perfil del usuario
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            isLoadingUser
                ? CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[300],
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            userId: widget.matchedUserId,
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'profile-${widget.matchedUserId}',
                      child: CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(
                          matchedUser?.profilePicture?.url ??
                              'https://res.cloudinary.com/dkghwqgbi/image/upload/v1701175862/gymder/default_profile_uqjykt.jpg',
                        ),
                      ),
                    ),
                  ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    matchedUser?.username ?? tr("loading"),
                    style: const TextStyle(fontSize: 16),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isConnected
                              ? (matchedUserOnline ? Colors.green : Colors.grey)
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isConnected
                            ? (matchedUserOnline ? tr("online") : tr("offline"))
                            : tr("reconnecting"),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Tus acciones existentes...
        ],
      ),
      backgroundColor: Colors.grey[900],
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: false,
              itemCount: messages.length +
                  (_isLoadingMoreMessages && _currentPage > 1 ? 1 : 0),
              itemBuilder: (context, index) {
                // Mostrar indicador de carga al principio de la lista cuando se cargan más mensajes
                if (_isLoadingMoreMessages && _currentPage > 1 && index == 0) {
                  return _buildLoadingIndicator();
                }

                // Ajustar el índice si se está mostrando el indicador de carga
                final messageIndex = _isLoadingMoreMessages && _currentPage > 1
                    ? index - 1
                    : index;

                if (messageIndex < 0 || messageIndex >= messages.length) {
                  return const SizedBox.shrink();
                }

                return _buildMessageItem(messages[messageIndex]);
              },
            ),
          ),
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  setState(() {
                    _messageController.text += emoji.emoji;
                  });
                },
              ),
            ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo, color: Colors.white),
                  onPressed: _pickImageFromGallery,
                ),
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined,
                      color: Colors.white),
                  onPressed: _toggleEmojiPicker,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: tr("type_a_message"),
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey[800],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                    ),
                    onTap: () {
                      if (_showEmojiPicker) {
                        setState(() => _showEmojiPicker = false);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
