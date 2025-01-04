// lib/screens/profile_swipe_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileSwipeScreen extends StatefulWidget {
  final List<User> users;

  const ProfileSwipeScreen({super.key, required this.users});

  @override
  State<ProfileSwipeScreen> createState() => _ProfileSwipeScreenState();
}

class _ProfileSwipeScreenState extends State<ProfileSwipeScreen> {
  PageController pageController = PageController();
  int currentIndex = 0;
  bool isProcessing = false;

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  Future<void> _likeUser(User user) async {
    setState(() {
      isProcessing = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken(); // Uso del método público

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token no encontrado. Por favor, inicia sesión nuevamente.')),
      );
      setState(() {
        isProcessing = false;
      });
      return;
    }

    final userService = UserService(token: token);
    final result = await userService.likeUser(user.id);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Has dado like al usuario')),
      );
      if (result['matchedUser'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Es un match!')),
        );
        // Implementa la lógica para manejar el match, como navegar a una pantalla de chat
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error al dar like')),
      );
    }

    setState(() {
      isProcessing = false;
      currentIndex++;
    });
  }

  Future<void> _dislikeUser(User user) async {
    setState(() {
      isProcessing = true;
    });

    // Implementar la lógica para dislike si está disponible en el backend
    // Por ahora, simplemente pasaremos al siguiente perfil
    setState(() {
      isProcessing = false;
      currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentIndex >= widget.users.length) {
      return const Center(child: Text('No hay más perfiles para mostrar.'));
    }

    final user = widget.users[currentIndex];

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          // Deslizar hacia arriba: like
          _likeUser(user);
        } else if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          // Deslizar hacia abajo: dislike
          _dislikeUser(user);
        }
      },
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: user.profilePicture?.url ?? '',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Center(child: Icon(Icons.error)),
          ),
          Positioned(
            bottom: 50,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
                Text(
                  user.goal ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 24,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
              ],
            ),
          ),
          if (isProcessing)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
