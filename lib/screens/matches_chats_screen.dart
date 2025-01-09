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
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
          ? Center(
        child: Text(
          errorMessage,
          style: const TextStyle(fontSize: 18, color: Colors.redAccent),
        ),
      )
          : myMatches.isEmpty
          ? const Center(
        child: Text(
          'No tienes matches todavía.',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      )
          : ListView.builder(
        itemCount: myMatches.length,
        itemBuilder: (context, index) {
          final matchedUser = myMatches[index];
          return GestureDetector(
            onLongPress: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar conversación'),
                  content: Text(
                      '¿Deseas eliminar el chat con ${matchedUser.username}?'),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Card(
                color: Colors.grey[850],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundImage: matchedUser.profilePicture != null
                        ? NetworkImage(
                        matchedUser.profilePicture!.url)
                        : null,
                    child: matchedUser.profilePicture == null
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                  title: Text(
                    matchedUser.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Toca para chatear',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false);
                    final currentUserId =
                        authProvider.user!.id;

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
              ),
            ),
          );
        },
      ),
    );
  }
}
