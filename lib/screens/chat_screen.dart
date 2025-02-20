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

  // Lista de mensajes; cada mensaje es un Map con campos: _id, senderId, type, message, imageUrl, timestamp, seenAt y opcional isLoading
  List<Map<String, dynamic>> messages = [];
  bool _showEmojiPicker = false;

  User? matchedUser;
  bool isLoadingUser = true;
  // Variable para simular el estado en línea del matchedUser (a actualizar mediante socket)
  bool matchedUserOnline = false;

  @override
  void initState() {
    super.initState();
    _connectToSocket();
    _fetchConversation();
    _fetchMatchedUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _connectToSocket() {
    socket = IO.io(
      'https://gymder-api-production.up.railway.app',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    socket.connect();

    socket.onConnect((_) {
      print('Conectado al socket.io server');
      socket.emit('joinRoom', {
        'userId': widget.currentUserId,
        'matchedUserId': widget.matchedUserId,
      });
      socket.emit('markAsRead', {
        'userId': widget.currentUserId,
        'matchedUserId': widget.matchedUserId,
      });
    });

    socket.on('receiveMessage', (data) {
      if (data['type'] == 'image' && data['senderId'] == widget.currentUserId) {
        // Buscar mensaje temporal
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
      print('Mensajes marcados como leídos: $data');
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

    socket.onDisconnect((_) => print('Desconectado del servidor'));
    socket.on('errorMessage', (data) => print('Error del servidor: $data'));
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
          print('Usuario no encontrado en la respuesta.');
        }
      } else {
        print('Error al obtener datos del usuario: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener datos del usuario: $e');
    }
  }

  Future<void> _fetchConversation() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        print('No hay token, no puedo obtener la conversación.');
        return;
      }
      final url = Uri.parse(
          'https://gymder-api-production.up.railway.app/api/messages/conversation'
          '?user1=${widget.currentUserId}&user2=${widget.matchedUserId}');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> msgs = data['messages'];
          setState(() {
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
          });
          _scrollToBottom();
        } else {
          print('Error: ${data['message']}');
        }
      } else {
        print('Error status code: ${response.statusCode}');
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('Error al obtener conversación: $e');
    }
  }

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

  void _sendMessage() {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;
    socket.emit('sendMessage', {
      'senderId': widget.currentUserId,
      'receiverId': widget.matchedUserId,
      'type': 'text',
      'message': msg,
    });
    _messageController.clear();
    _scrollToBottom();
  }

  /// Envía imagen con mensaje temporal de carga.
  Future<void> _sendImageMessage(File imageFile) async {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        print('No hay token, no puedo subir la imagen.');
        return;
      }
      final url = Uri.parse(
          'https://gymder-api-production.up.railway.app/api/messages/upload');
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      final mimeType =
          lookupMimeType(imageFile.path) ?? 'application/octet-stream';
      final mimeTypeData = mimeType.split('/');
      if (mimeTypeData.length != 2) {
        throw Exception('Tipo de archivo desconocido para la imagen');
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'chatImage',
          imageFile.path,
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
          print('Error al subir imagen chat: ${data['message']}');
        }
      } else {
        print('Error al subir imagen chat: ${response.statusCode}');
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('Error al enviar imagen: $e');
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
        print('Error al ocultar mensaje: ${response.statusCode}');
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('Error al ocultar mensaje: $e');
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
      }
      else {
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
                title: const Text('Eliminar mensaje'),
                content:
                    const Text('¿Deseas eliminar este mensaje solo para ti?'),
                actions: [
                  TextButton(
                    child: const Text('Cancelar'),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  TextButton(
                    child: const Text('Eliminar'),
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: isLoadingUser
            ? const Text('', style: TextStyle(color: Colors.white))
            : GestureDetector(
                onTap: () {
                  if (matchedUser != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UserProfileScreen(userId: matchedUser!.id),
                      ),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: matchedUser?.profilePicture != null
                              ? NetworkImage(matchedUser!.profilePicture!.url)
                              : null,
                          child: matchedUser?.profilePicture == null
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          matchedUser?.username ?? 'Chat',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    if (matchedUserOnline)
                      const Padding(
                        padding: EdgeInsets.only(top: 2.0),
                        child: Text(
                          "En línea",
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      backgroundColor: Colors.grey[900],
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _buildMessageItem(messages[index]);
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
                      hintText: 'Escribe un mensaje...',
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
