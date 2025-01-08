// lib/screens/matches_chats_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../models/user.dart';
import 'chat_screen.dart';

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
      // Aquí necesitas un método en tu user_service.dart que obtenga los matches
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
        return ListTile(
          leading: CircleAvatar(
            // Opcional: muestra la foto de perfil
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
          subtitle: Text(
            'Toca para chatear',
            style: const TextStyle(color: Colors.white70),
          ),
          onTap: () {
            // Navegar a la pantalla de Chat con este matchedUser
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
        );
      },
    );
  }
}
