// lib/screens/tiktok_like_screen.dart
import 'package:flutter/material.dart';
import 'package:gymder/screens/single_user_view.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'chat_screen.dart';

class TikTokLikeScreen extends StatefulWidget {
  final List<User> users;

  const TikTokLikeScreen({Key? key, required this.users}) : super(key: key);

  @override
  State<TikTokLikeScreen> createState() => _TikTokLikeScreenState();
}

class _TikTokLikeScreenState extends State<TikTokLikeScreen> {
  late PageController _verticalPageController;
  bool _isProcessing = false;
  late List<User> _users; // Lista local de usuarios

  @override
  void initState() {
    super.initState();
    _verticalPageController = PageController();
    _users = List.from(widget.users); // Inicializa la lista local con los usuarios recibidos
  }

  @override
  void dispose() {
    _verticalPageController.dispose();
    super.dispose();
  }

  Future<void> _handleLike(int userIndex) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final user = _users[userIndex];
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Has dado like al usuario')),
      );
      if (result['matchedUser'] != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              currentUserId: user.id,
              matchedUserId: result['matchedUser'].id,
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error al dar like')),
      );
    }

    // Remover el usuario "likeado" de la lista local
    setState(() {
      _users.removeAt(userIndex);
    });

    // Desplazarse al siguiente usuario si existe
    if (_users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay más usuarios')),
      );
    } else if (userIndex < _users.length) {
      // Desplazar a la página del siguiente usuario
      _verticalPageController.animateToPage(
        userIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
      );
    }

    _isProcessing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_users.isEmpty) {
      return const Center(
        child: Text('No hay usuarios para mostrar.'),
      );
    }

    return PageView.builder(
      controller: _verticalPageController,
      scrollDirection: Axis.vertical,
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return SingleUserView(
          user: user,
          onDoubleTapLike: () => _handleLike(index),
        );
      },
    );
  }
}
