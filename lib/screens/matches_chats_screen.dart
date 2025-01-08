// lib/screens/matches_chats_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../models/user.dart';
import 'chat_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MatchesChatsScreen extends StatefulWidget {
  const MatchesChatsScreen({Key? key}) : super(key: key);

  @override
  State<MatchesChatsScreen> createState() => _MatchesChatsScreenState();
}

class _MatchesChatsScreenState extends State<MatchesChatsScreen> {
  bool isLoading = true;
  String errorMessage = '';
  List<User> myMatches = [];

  @override
  void initState() {
    super.initState();
    _fetchMyMatches();
  }

  Future<void> _fetchMyMatches() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Token no disponible, inicia sesión.';
        });
        return;
      }

      final userService = UserService(token: token);
      final result = await userService.getMatches();
      if (result['success']) {
        setState(() {
          myMatches = List<User>.from(
            result['matches'].map((x) => User.fromJson(x)),
          );
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = result['message'] ?? 'Error al obtener matches';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error inesperado: $e';
        isLoading = false;
      });
    }
  }

  // Ocultar/Eliminar la conversación completa
  Future<void> _hideConversation(String otherUserId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;

      final url = Uri.parse('http://10.0.2.2:5000/api/messages/conversation/hide');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'otherUserId': otherUserId
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('Conversación ocultada');
          // Podrías eliminar al usuario de la lista local
          setState(() {
            myMatches.removeWhere((u) => u.id == otherUserId);
          });
        } else {
          print('No se pudo ocultar la conversación: ${data['message']}');
        }
      } else {
        print('Error ocultando conversación: ${response.statusCode}');
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('Error en _hideConversation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          errorMessage,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }
    if (myMatches.isEmpty) {
      return const Center(
        child: Text(
          'No tienes matches todavía.',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      itemCount: myMatches.length,
      itemBuilder: (context, index) {
        final matchedUser = myMatches[index];
        return GestureDetector(
          onLongPress: () {
            // Preguntar si se quiere eliminar la conversación
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Eliminar conversación'),
                content: Text('¿Deseas eliminar el chat con ${matchedUser.username}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _hideConversation(matchedUser.id);
                    },
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            );
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: matchedUser.profilePicture != null
                  ? NetworkImage(matchedUser.profilePicture!.url)
                  : null,
              child: matchedUser.profilePicture == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              matchedUser.username,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Toca para chatear',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final currentUserId = authProvider.user!.id;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    currentUserId: currentUserId,
                    matchedUserId: matchedUser.id,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
