// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../providers/auth_provider.dart';

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
  List<Map<String, dynamic>> messages =
      []; // Aquí guardamos {senderId, message, timestamp}

  @override
  void initState() {
    super.initState();
    _connectToSocket();
    _fetchConversation(); // cargar historial previo
  }

  void _connectToSocket() {
    // Conéctate a tu servidor Node (verifica la dirección/puerto)
    socket = IO.io(
        'http://10.0.2.2:5000', // o la IP donde corre tu backend
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build());

    socket.connect();

    // Cuando se conecta
    socket.onConnect((_) {
      print('Conectado al socket.io server');
      // Unirse a la "sala" con joinRoom
      socket.emit('joinRoom', {
        'userId': widget.currentUserId,
        'matchedUserId': widget.matchedUserId,
      });
    });

    // Escuchar mensajes entrantes
    socket.on('receiveMessage', (data) {
      setState(() {
        messages.add({
          'senderId': data['senderId'],
          'message': data['message'],
          'timestamp': data['timestamp'],
        });
      });
    });

    // Manejar errores
    socket.on('errorMessage', (data) {
      print('Error del servidor: $data');
    });

    // Cuando se desconecta
    socket.onDisconnect((_) {
      print('Desconectado del servidor');
    });
  }

  // Carga inicial del historial de chat usando tu endpoint /api/messages/conversation
  Future<void> _fetchConversation() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        print('No hay token, no puedo obtener la conversación.');
        return;
      }

      final url = Uri.parse('http://10.0.2.2:5000/api/messages/conversation'
          '?user1=${widget.currentUserId}&user2=${widget.matchedUserId}');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> msgs = data['messages'];
          setState(() {
            messages = msgs.map((m) {
              return {
                'senderId': m['sender'],
                'message': m['message'],
                'timestamp': m['createdAt']
              };
            }).toList();
          });
        } else {
          print('Error: ${data['message']}');
        }
      } else {
        print('Error status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error al obtener conversación: $e');
    }
  }

  void _sendMessage() {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    // Emitimos al servidor
    socket.emit('sendMessage', {
      'senderId': widget.currentUserId,
      'receiverId': widget.matchedUserId,
      'message': msg,
    });

    // Limpiamos el TextField
    _messageController.clear();
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[900],
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['senderId'] == widget.currentUserId;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      msg['message'],
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          // Caja de texto para enviar mensaje
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.grey[800],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              )
            ],
          )
        ],
      ),
    );
  }
}
