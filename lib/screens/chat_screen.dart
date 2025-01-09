import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import '../providers/auth_provider.dart';
import '../models/user.dart'; // Asegúrate de importar el modelo User
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

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
  final ImagePicker _imagePicker = ImagePicker();

  List<Map<String, dynamic>> messages = [];
  bool _showEmojiPicker = false;

  User? matchedUser;
  bool isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _connectToSocket();
    _fetchConversation();
    _fetchMatchedUser();
  }

  void _connectToSocket() {
    socket = IO.io(
      'http://10.0.2.2:5000',
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
    });

    socket.on('receiveMessage', (data) {
      setState(() {
        messages.add({
          'senderId': data['senderId'],
          'type': data['type'] ?? 'text',
          'message': data['message'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'timestamp': data['timestamp']
        });
      });
    });

    socket.onDisconnect((_) => print('Desconectado del servidor'));
    socket.on('errorMessage', (data) => print('Error del servidor: $data'));
  }

  Future<void> _fetchMatchedUser() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;

      final url = Uri.parse('http://10.0.2.2:5000/api/users/profile/${widget.matchedUserId}');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Verificar directamente si 'user' existe en la respuesta
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
          'http://10.0.2.2:5000/api/messages/conversation'
              '?user1=${widget.currentUserId}&user2=${widget.matchedUserId}'
      );

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
                'timestamp': m['createdAt']
              };
            }).toList();
          });
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
  }

  Future<void> _sendImageMessage(File imageFile) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        print('No hay token, no puedo subir la imagen.');
        return;
      }

      final url = Uri.parse('http://10.0.2.2:5000/api/messages/upload');
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      final mimeType = lookupMimeType(imageFile.path) ?? 'application/octet-stream';
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
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
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

      final url = Uri.parse('http://10.0.2.2:5000/api/messages/$messageId/hide');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        await _fetchConversation();
      } else {
        print('Error al ocultar mensaje: ${response.statusCode}');
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('Error al ocultar mensaje: $e');
    }
  }

  @override
  void dispose() {
    socket.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: isLoadingUser
            ? const Text('Chat', style: TextStyle(color: Colors.white))
            : Row(
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
      ),
      backgroundColor: Colors.grey[900],
      body: Column(
        children: [
          // Mensajes
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['senderId'] == widget.currentUserId;
                final type = msg['type'] as String? ?? 'text';

                return GestureDetector(
                  onLongPress: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) {
                        return AlertDialog(
                          title: const Text('Eliminar mensaje'),
                          content: const Text(
                              '¿Deseas eliminar este mensaje solo para ti?'),
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
                    if (confirm == true && msg['_id'] != null) {
                      _hideMessage(msg['_id']);
                    }
                  },
                  child: Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue : Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: type == 'image'
                          ? (msg['imageUrl'] != null
                          ? Image.network(
                        msg['imageUrl'],
                        height: 200,
                        width: 200,
                        fit: BoxFit.cover,
                      )
                          : const Text('Imagen no disponible'))
                          : Text(
                        msg['message'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 19),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Emoji Picker
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

          // Caja de texto para enviar mensaje con iconos de foto y emoji a la izquierda
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo, color: Colors.white),
                  onPressed: _pickImageFromGallery,
                ),
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white),
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
                        horizontal: 10,
                        vertical: 12,
                      ),
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
