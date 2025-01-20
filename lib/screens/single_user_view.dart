import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user.dart';

class SingleUserView extends StatefulWidget {
  final User user;
  final VoidCallback onDoubleTapLike;

  const SingleUserView({
    Key? key,
    required this.user,
    required this.onDoubleTapLike,
  }) : super(key: key);

  @override
  State<SingleUserView> createState() => _SingleUserViewState();
}

class _SingleUserViewState extends State<SingleUserView>
    with SingleTickerProviderStateMixin {
  late PageController _horizontalPageController;
  int _currentPhotoIndex = 0;

  late AnimationController _heartAnimationController;
  late Animation<double> _heartAnimation;
  Animation<double>? _heartOpacityAnimation;
  Animation<double>? _heartMoveAnimation;

  bool _showHeart = false;
  Offset? _heartPosition; // Almacena la posición del doble tap

  @override
  void initState() {
    super.initState();
    _horizontalPageController = PageController();

    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Duración extendida para el efecto
    );

    // Configuración de animaciones
    _heartAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _heartAnimationController, curve: Curves.easeOut),
    );

    _heartOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _heartAnimationController, curve: Curves.easeOut),
    );

    _heartMoveAnimation = Tween<double>(begin: 0.0, end: -100.0).animate(
      CurvedAnimation(parent: _heartAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _horizontalPageController.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() async {
    setState(() {
      _showHeart = true;
    });

    // Mostrar el corazón grande y estático por un breve periodo
    await Future.delayed(const Duration(milliseconds: 300));

    // Iniciar la animación de desvanecimiento y movimiento hacia arriba
    _heartAnimationController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showHeart = false;
          });
        }
      });
    });

    // Llamar la función de like
    widget.onDoubleTapLike();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final photos = user.photos ?? [];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (TapDownDetails details) {
        // Capturar la posición local del doble tap
        final RenderBox box = context.findRenderObject() as RenderBox;
        setState(() {
          _heartPosition = box.globalToLocal(details.globalPosition);
        });
      },
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.horizontal,
            controller: _horizontalPageController,
            itemCount: photos.isEmpty ? 1 : photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentPhotoIndex = index;
              });
            },
            itemBuilder: (context, index) {
              if (photos.isEmpty) {
                return Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Text(
                      'No hay fotos adicionales',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                );
              }

              final photoUrl = photos[index].url;
              return CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) =>
                const Center(child: Icon(Icons.error)),
              );
            },
          ),

          if (photos.isNotEmpty)
            Positioned(
              bottom: 92,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(photos.length, (i) {
                  final isActive = i == _currentPhotoIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 14 : 8,
                    height: isActive ? 14 : 8,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),

          // Datos del usuario
          Positioned(
            left: 20,
            bottom: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
                if (user.goal != null)
                  Text(
                    user.goal!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
              ],
            ),
          ),

          // Ícono de corazón animado en la posición del doble tap con efecto TikTok
          if (_showHeart && _heartPosition != null)
            AnimatedBuilder(
              animation: _heartAnimationController,
              builder: (context, child) {
                return Positioned(
                  left: _heartPosition!.dx - 40,
                  top: _heartPosition!.dy - 40 + (_heartMoveAnimation?.value ?? 0.0),
                  child: Opacity(
                    opacity: _heartOpacityAnimation?.value ?? 1.0,
                    child: ScaleTransition(
                      scale: _heartAnimation,
                      child: child,
                    ),
                  ),
                );
              },
              child: const Icon(
                Icons.favorite,
                color: Colors.red,
                size: 80,
              ),
            ),
        ],
      ),
    );
  }
}
