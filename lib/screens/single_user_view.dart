// lib/widgets/perfil/single_user_view.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/user.dart';
import 'dart:math';
import 'user_profile_screen.dart'; // Para navegar al perfil del usuario
import 'tiktok_like_screen.dart'; // Para acceder a TikTokLikeScreenState

class SingleUserView extends StatefulWidget {
  final User user;
  final VoidCallback onDoubleTapLike;

  const SingleUserView({
    Key? key,
    required this.user,
    required this.onDoubleTapLike,
  }) : super(key: key);
  
  // Método para acceder al estado desde fuera
  void showLikeAnimation(BuildContext context) {
    final state = context.findAncestorStateOfType<SingleUserViewState>();
    if (state != null) {
      state.showLikeAnimationInCenter();
    }
  }

  @override
  State<SingleUserView> createState() => SingleUserViewState();
}

class SingleUserViewState extends State<SingleUserView>
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
      duration: const Duration(milliseconds: 800),
    );

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
      // Establecemos la posición en donde se hizo el doble tap
      // Aquí ya debería estar asignado _heartPosition desde onDoubleTapDown
    });
    await Future.delayed(const Duration(milliseconds: 300));
    _heartAnimationController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showHeart = false;
          });
        }
      });
    });
    widget.onDoubleTapLike();
  }
  
  // Método para mostrar la animación del corazón desde el centro de la pantalla
  void showLikeAnimationInCenter() async {
    // Calculamos el centro de la pantalla
    final size = MediaQuery.of(context).size;
    setState(() {
      _heartPosition = Offset(size.width / 2, size.height / 2);
      _showHeart = true;
    });
    
    await Future.delayed(const Duration(milliseconds: 300));
    _heartAnimationController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showHeart = false;
          });
        }
      });
    });
    // No llamamos a widget.onDoubleTapLike() ya que eso se maneja desde quien llama a este método
  }

  @override
  void didUpdateWidget(covariant SingleUserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _horizontalPageController.jumpToPage(0);
      setState(() {
        _currentPhotoIndex = 0;
      });
    }
  }

  /// Mapea el valor interno de 'goal' a su texto traducido
  String _displayGoal(String? internal) {
    if (internal == null || internal.isEmpty) return '';
    final map = {
      'General': tr('general_option'),
      'Definición': tr('definition_option'),
      'Volumen': tr('volume_option'),
      'Mantenimiento': tr('maintenance_option'),
    };
    return map[internal] ?? internal;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final photos = user.photos ?? [];

    final displayGoal = _displayGoal(user.goal);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (TapDownDetails details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        setState(() {
          _heartPosition = box.globalToLocal(details.globalPosition);
        });
      },
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        children: [
          // ─── Fotos horizontales ─────────────────────────
          PageView.builder(
            controller: _horizontalPageController,
            scrollDirection: Axis.horizontal,
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
                  child: Center(
                    child: Text(
                      tr("no_additional_photos"),
                      style: const TextStyle(color: Colors.white, fontSize: 20),
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

          // ─── Paginación ─────────────────────────────────
          if (photos.isNotEmpty)
            Positioned(
              bottom: 120,
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

          // ─── Panel con información del usuario ──────────────────
          Positioned(
            left: 20,
            right: 20,
            bottom: 160,
            child: GestureDetector(
              onTap: () async {
                // Navegar al perfil del usuario y esperar por el resultado
                final didPerformAction = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: user.id),
                  ),
                );
                
                // Si el usuario dio like o quick like, notificamos a la pantalla principal para refrescar
                if (didPerformAction == true) {
                  // Buscamos el ancestro TikTokLikeScreenState para refrescar los datos
                  final tikTokScreenState = context.findAncestorStateOfType<TikTokLikeScreenState>();
                  if (tikTokScreenState != null) {
                    tikTokScreenState.reloadProfiles();
                  }
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(bottom: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 35,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black)
                            ],
                          ),
                        ),
                        if (user.verificationStatus == 'true')
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: Container(
                              width: 23,
                              height: 23,
                              child: Image.asset(
                                'assets/images/verificado.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Objetivo de fitness
                  if (user.goal != null && user.goal!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fitness_center,
                            color: Colors.white70,
                            size: 16,
                            shadows: const [Shadow(blurRadius: 5, color: Colors.black)],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            displayGoal,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Biografía
                  if (user.biography != null && user.biography!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        user.biography!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 10, color: Colors.black)
                          ],
                        ),
                      ),
                    ),

                  if ((user.city != null && user.city!.isNotEmpty) ||
                      (user.country != null && user.country!.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 16,
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black)
                            ],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${user.city ?? ''}${user.country != null && user.country!.isNotEmpty ? ', ${user.country}' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              shadows: [
                                Shadow(blurRadius: 10, color: Colors.black)
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ─── Animación del corazón ────────────────────
          if (_showHeart && _heartPosition != null)
            AnimatedBuilder(
              animation: _heartAnimationController,
              builder: (context, child) {
                return Positioned(
                  left: _heartPosition!.dx - 40,
                  top: _heartPosition!.dy -
                      40 +
                      (_heartMoveAnimation?.value ?? 0.0),
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
