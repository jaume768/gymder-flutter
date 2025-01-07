// lib/screens/tiktok_like_screen.dart
import 'package:flutter/material.dart';
import 'package:gymder/screens/single_user_view.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';

class TikTokLikeScreen extends StatefulWidget {
  final List<User> users;

  const TikTokLikeScreen({Key? key, required this.users}) : super(key: key);

  @override
  State<TikTokLikeScreen> createState() => _TikTokLikeScreenState();
}

class _TikTokLikeScreenState extends State<TikTokLikeScreen> {
  // Controlador para scroll vertical entre usuarios
  late PageController _verticalPageController;
  // Para evitar múltiples “likes” simultáneos
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _verticalPageController = PageController();
  }

  @override
  void dispose() {
    _verticalPageController.dispose();
    super.dispose();
  }

  /// Dar like y moverse al siguiente usuario
  Future<void> _handleLike(int userIndex) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final user = widget.users[userIndex];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token no encontrado. Inicia sesión.')),
      );
      _isProcessing = false;
      return;
    }

    final userService = UserService(token: token);
    final result = await userService.likeUser(user.id);

    if (result['success'] == true) {
      // Muestra snack de like
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Has dado like al usuario')),
      );
      if (result['matchedUser'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Es un match!')),
        );
        // Aquí podrías abrir un modal, pantalla de chat, etc.
      }
    } else {
      // Error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error al dar like')),
      );
    }

    // Ir al siguiente usuario
    final nextPage = userIndex + 1;
    if (nextPage < widget.users.length) {
      _verticalPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
      );
    } else {
      // No hay más usuarios
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay más usuarios')),
      );
    }

    _isProcessing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.users.isEmpty) {
      return const Center(
        child: Text('No hay usuarios para mostrar.'),
      );
    }

    return PageView.builder(
      controller: _verticalPageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.users.length,
      itemBuilder: (context, index) {
        final user = widget.users[index];
        return SingleUserView(
          user: user,
          onDoubleTapLike: () => _handleLike(index),
        );
      },
    );
  }
}
