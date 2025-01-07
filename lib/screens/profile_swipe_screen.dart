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
  int currentUserIndex = 0;
  bool isProcessing = false;

  // Controlador para el PageView de fotos
  late PageController _photosPageController;
  // Índice de la foto actual
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _photosPageController = PageController();
  }

  @override
  void dispose() {
    _photosPageController.dispose();
    super.dispose();
  }

  /// Dar "like" a un usuario
  Future<void> _likeUser(User user) async {
    setState(() => isProcessing = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token no encontrado. Por favor, inicia sesión nuevamente.')),
      );
      setState(() => isProcessing = false);
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
        // Aquí podrías navegar a un chat o mostrar un modal
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error al dar like')),
      );
    }

    setState(() {
      isProcessing = false;
      currentUserIndex++;
      _currentPhotoIndex = 0; // Resetear el index de fotos para el próximo usuario
    });
  }

  /// Dar "dislike" (o pasar) a un usuario
  Future<void> _dislikeUser(User user) async {
    setState(() => isProcessing = true);

    // Aquí podrías llamar a un endpoint de "dislike" si tu backend lo implementa.
    // Por ahora, solo pasamos al siguiente usuario.
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      isProcessing = false;
      currentUserIndex++;
      _currentPhotoIndex = 0;
    });
  }

  /// Cuando el usuario termina de arrastrar verticalmente:
  ///  - hacia arriba: like
  ///  - hacia abajo: dislike
  void _handleVerticalSwipe(DragEndDetails details, User user) {
    if (details.primaryVelocity == null) return;

    if (details.primaryVelocity! < 0) {
      // Hacia arriba
      _likeUser(user);
    } else if (details.primaryVelocity! > 0) {
      // Hacia abajo
      _dislikeUser(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si ya no hay usuarios que mostrar
    if (currentUserIndex >= widget.users.length) {
      return const Center(child: Text('No hay más perfiles para mostrar.'));
    }

    final user = widget.users[currentUserIndex];
    // Lista de fotos adicionales
    final photos = user.photos ?? [];

    // Si no tiene fotos adicionales, podrías manejarlo (mostrar placeholder o algo similar)
    if (photos.isEmpty) {
      return GestureDetector(
        onVerticalDragEnd: (details) => _handleVerticalSwipe(details, user),
        child: Stack(
          children: [
            // Placeholder de no hay fotos
            Container(
              color: Colors.grey[900],
              alignment: Alignment.center,
              child: const Text(
                'Este usuario no tiene fotos adicionales',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            _buildUserInfoOverlay(user),
            if (isProcessing)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    return GestureDetector(
      onVerticalDragEnd: (details) => _handleVerticalSwipe(details, user),
      child: Stack(
        children: [
          // PageView de las fotos adicionales
          PageView.builder(
            controller: _photosPageController,
            itemCount: photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentPhotoIndex = index;
              });
            },
            // Aquí puedes agregar efectos de transición en cada página
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final photoUrl = photos[index].url;
              return CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Center(child: Icon(Icons.error)),
              );
            },
          ),
          // Información del usuario y el indicador de fotos
          _buildUserInfoOverlay(user),
          _buildPhotoIndicator(photos.length),
          // Loading si estamos procesando like/dislike
          if (isProcessing)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  /// Overlay con datos del usuario (nombre, goal, etc.)
  Widget _buildUserInfoOverlay(User user) {
    return Positioned(
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
    );
  }

  /// Pequeño indicador de página para mostrar cuántas fotos hay
  Widget _buildPhotoIndicator(int totalPhotos) {
    // Posición centrada abajo
    return Positioned(
      bottom: 10,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalPhotos, (index) {
          // Cada puntito del indicador
          final isActive = index == _currentPhotoIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 12 : 8,
            height: isActive ? 12 : 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white54,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
