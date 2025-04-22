import 'package:app/screens/single_user_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app/screens/premium_purchase_page.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/match_service.dart';
import '../services/user_service.dart';
import '../screens/chat_screen.dart';

// ScrollPhysics personalizado para bloquear el scroll cuando se alcanza el límite
class LimitedScrollPhysics extends ScrollPhysics {
  final bool isLimitReached;

  const LimitedScrollPhysics({
    ScrollPhysics? parent,
    required this.isLimitReached,
  }) : super(parent: parent);

  @override
  LimitedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LimitedScrollPhysics(
      parent: buildParent(ancestor),
      isLimitReached: isLimitReached,
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // Si el límite está alcanzado, no permitir scroll hacia abajo
    if (isLimitReached) {
      return false;
    }
    return true;
  }
}

class TikTokLikeScreen extends StatefulWidget {
  final List<User> users;
  const TikTokLikeScreen({Key? key, required this.users}) : super(key: key);

  @override
  State<TikTokLikeScreen> createState() => _TikTokLikeScreenState();
}

class _TikTokLikeScreenState extends State<TikTokLikeScreen>
    with AutomaticKeepAliveClientMixin {
  late PageController _verticalPageController;
  bool _isProcessing = false;
  bool showRandom = true;
  List<User> _randomUsers = [];
  bool _isFetchingMore = false;
  final int _limit = 20;
  List<User> _likedUsers = [];
  int _lastFetchThreshold = 0;

  int _currentPageIndex = 0;
  int previousPageIndex = 0;
  
  // Variable para guardar la posición en la lista de aleatoria
  int _savedRandomPosition = 0;

  // Variables para manejar los IDs de perfiles ya cargados
  Set<String> _loadedProfileIds = {};
  // Set para controlar los perfiles que ya se han visto para enviar al backend
  Set<String> _seenProfileIds = {};

  // Variables para el límite de scroll (ahora manejadas por el backend)
  bool _isScrollLimitReached = false;
  DateTime? _limitExpirationTime;
  int _remainingHours = 0;
  
  // Variables para guardar los valores de filtro actuales
  RangeValues _currentAgeRange = const RangeValues(18, 50);
  RangeValues _currentWeightRange = const RangeValues(50, 100);
  RangeValues _currentHeightRange = const RangeValues(150, 200);
  String _currentGymStage = 'Todos';
  String _currentRelationshipType = 'Todos';
  bool _currentUseLocation = false;
  RangeValues _currentDistanceRange = const RangeValues(5, 50);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _verticalPageController = PageController(keepPage: true);

    // Inicializar lista de usuarios y registrar sus IDs
    _randomUsers = List.from(widget.users);
    for (var user in _randomUsers) {
      _loadedProfileIds.add(user.id);
    }
    
    // Establecer el umbral de carga inicial
    _lastFetchThreshold = (_randomUsers.length / 2).floor();
    
    // No barajar la lista inicialmente, lo haremos después de verificar el límite
    previousPageIndex = 0;

    // Inicializar completamente la pantalla
    _initializeScreen();
  }

  // Método para la inicialización completa de la pantalla
  Future<void> _initializeScreen() async {
    // Primero verificar si hay un límite de scroll activo
    await _checkScrollLimitStatus();

    // Cargar usuarios que le dieron like
    await _fetchLikedUsers();

    // Si no hay límite de scroll, barajar la lista
    if (!_isScrollLimitReached) {
      setState(() {
        _randomUsers.shuffle();
      });
    }
  }

  // Verificar el estado del límite de scroll desde el backend
  Future<void> _checkScrollLimitStatus() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;

      final matchService = MatchService(token: token);
      final result = await matchService.getScrollLimitStatus();

      if (result['success'] == true) {
        setState(() {
          _isScrollLimitReached = result['limitActive'] ?? false;

          // Si hay un límite activo, guardar la información relevante
          if (_isScrollLimitReached && result['limitInfo'] != null) {
            final limitInfo = result['limitInfo'];
            _limitExpirationTime = DateTime.parse(limitInfo['limitExpiration']);
            _remainingHours = limitInfo['remainingHours'] ?? 0;
          }
        });

        print(
            "Estado de límite de scroll: activo=$_isScrollLimitReached, horas restantes=$_remainingHours");
      }
    } catch (e) {
      print('Error al verificar estado de límite de scroll: $e');
    }
  }

  Future<void> _fetchLikedUsers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) return;

    final userService = UserService(token: token);
    final result = await userService.getUserLikes();

    if (result['success'] == true) {
      setState(() {
        _likedUsers = List<User>.from(
            result['usersWhoLiked'].map((x) => User.fromJson(x)));
      });
      print(tr("liked_users_count", args: [_likedUsers.length.toString()]));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? tr("error_getting_likes"))),
      );
    }
  }

  // Método para actualizar el contador de scroll en el backend
  Future<void> _updateScrollCount() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;

      // Obtener el ID del perfil actual
      String? currentProfileId;
      if (_currentPageIndex < _randomUsers.length) {
        currentProfileId = _randomUsers[_currentPageIndex].id;
      }

      final matchService = MatchService(token: token);
      final result = await matchService.updateScrollCount(currentProfileId);

      if (result['success'] == true) {
        // Verificar si se ha alcanzado el límite
        final limitReached = result['limitReached'] ?? false;

        if (limitReached && !_isScrollLimitReached) {
          setState(() {
            _isScrollLimitReached = true;

            // Guardar información del límite
            if (result['limitInfo'] != null) {
              final limitInfo = result['limitInfo'];
              _limitExpirationTime =
                  DateTime.parse(limitInfo['limitExpiration']);
              _remainingHours = limitInfo['remainingHours'] ?? 0;
            }
          });

          // Mostrar diálogo de límite alcanzado
          _showScrollLimitDialog();

          // Bloquear el scroll inmediatamente
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _verticalPageController.jumpToPage(_currentPageIndex);
          });
        }
      }
    } catch (e) {
      print('Error al actualizar contador de scroll: $e');
    }
  }

  // Método para enviar al backend el perfil visto
  Future<void> _updateSeenProfile(String userId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;

      final matchService = MatchService(token: token);
      await matchService.updateSeenProfiles([userId]);
    } catch (e) {
      print('Error al actualizar perfil visto: $e');
    }
  }

  // Mostrar diálogo cuando se alcanza el límite de scroll
  void _showScrollLimitDialog() {
    if (_remainingHours <= 0) return;

    final hours = _remainingHours;
    final minutes = 0; // No tenemos minutos detallados en esta implementación

    _showPremiumDialog(
      tr("premium_function"),
      tr("scroll_limit_message", args: [hours.toString()]),
    );
  }

  Future<void> _fetchMoreUsers() async {
    if (_isFetchingMore) {
      print("Ya se está ejecutando una carga de usuarios, ignorando solicitud");
      return;
    }

    print("Iniciando carga de más usuarios. Tenemos ${_randomUsers.length} usuarios actualmente");
    setState(() {
      _isFetchingMore = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        setState(() {
          _isFetchingMore = false;
        });
        return;
      }

      final matchService = MatchService(token: token);
      
      // Crear una lista de los IDs que ya tenemos cargados
      final loadedIds = List<String>.from(_loadedProfileIds);
      
      // Primero, registrar los perfiles vistos para que no se repitan
      await matchService.updateSeenProfiles(loadedIds);
      
      // Preparar los filtros para la solicitud
      final Map<String, String> filters = {
        'limit': _limit.toString(),
        'skip': '0', // Siempre pedir desde el inicio, el backend filtrará los ya vistos
      };
      
      print("Solicitando usuarios con filtros: $filters");
      final result = await matchService.getSuggestedMatchesWithFilters(filters);

      if (result['success'] == true) {
        List<dynamic> matchesData = result['matches'];
        print("Recibidos ${matchesData.length} usuarios del backend");
        
        List<User> newUsers = matchesData.map((data) => User.fromJson(data)).toList();

        if (mounted) {
          setState(() {
            // Filtrar usuarios ya cargados para evitar duplicados
            List<User> uniqueNewUsers = newUsers.where((user) {
              return !_loadedProfileIds.contains(user.id);
            }).toList();

            // Añadir solo usuarios únicos
            if (uniqueNewUsers.isNotEmpty) {
              _randomUsers.addAll(uniqueNewUsers);
              
              // Registrar los nuevos IDs
              for (var user in uniqueNewUsers) {
                _loadedProfileIds.add(user.id);
              }
              
              print("Añadidos ${uniqueNewUsers.length} nuevos usuarios únicos. Total: ${_randomUsers.length}");
            } else {
              print("No se encontraron nuevos usuarios para añadir (todos los recibidos ya estaban cargados)");
            }
            
            _isFetchingMore = false;
          });
        }
      } else {
        print("Error al cargar más usuarios: ${result['message']}");
        if (mounted) {
          setState(() {
            _isFetchingMore = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching more users: $e');
      if (mounted) {
        setState(() {
          _isFetchingMore = false;
        });
      }
    }
  }

  void _handleLike(int userIndex) async {
    if (_isProcessing) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userIsPremium = authProvider.user?.isPremium ?? false;
    int localMaxLike = (authProvider.user?.gender == 'Masculino') ? 20 : 40;

    // Verificar el límite de likes antes de proceder
    if (!userIsPremium) {
      // No hay implementación de límite de likes en este código
    }

    _isProcessing = true;
    final user = _randomUsers[userIndex];

    final token = await authProvider.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("token_not_found_login"))),
      );
      _isProcessing = false;
      return;
    }

    final userService = UserService(token: token);
    final result = await userService.likeUser(user.id);

    if (result['success'] == true) {
      final currentUser = authProvider.user;
      if (result['matchedUser'] != null && currentUser != null) {
        _mostrarModalMatch(context, currentUser, user);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? tr("error_liking_user"))),
      );
    }

    setState(() {
      _randomUsers.removeAt(userIndex);
    });

    if (_randomUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("no_more_users"))),
      );
    } else if (userIndex < _randomUsers.length) {
      _verticalPageController.animateToPage(
        userIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
      );
    }

    _isProcessing = false;
  }

  void _handleLikeFromLeGustas(int userIndex) async {
    if (_isProcessing) return;
    _isProcessing = true;
    final user = _likedUsers[userIndex];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("token_not_found_login"))),
      );
      _isProcessing = false;
      return;
    }
    final userService = UserService(token: token);
    final result = await userService.likeUser(user.id);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("like_success"))),
      );
      if (result['matchedUser'] != null) {
        final currentUser =
            Provider.of<AuthProvider>(context, listen: false).user;
        if (result['matchedUser'] != null && currentUser != null) {
          _mostrarModalMatch(context, currentUser, user);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? tr("error_liking_user"))),
      );
    }

    setState(() {
      _likedUsers.removeAt(userIndex);
    });

    _isProcessing = false;
  }

  void _showPremiumDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          content,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr("cancel"),
                style: const TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PremiumPurchasePage(),
                ),
              );
            },
            child: Text(tr("buy_premium"),
                style: const TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchAvatar(String? imageUrl, {double radius = 50}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[800],
      backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
          ? NetworkImage(imageUrl)
          : null,
      child: (imageUrl == null || imageUrl.isEmpty)
          ? Icon(Icons.person, color: Colors.white, size: radius)
          : null,
    );
  }

  void _mostrarModalMatch(
      BuildContext context, User usuarioActual, User matchedUser) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.black.withOpacity(0.6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr("match_title"),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                tr("match_message", namedArgs: {"username": matchedUser.username ?? ""}),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMatchAvatar(usuarioActual.profilePicture?.url,
                      radius: 50),
                  const SizedBox(width: 20),
                  _buildMatchAvatar(matchedUser.profilePicture?.url,
                      radius: 50),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        currentUserId: usuarioActual.id,
                        matchedUserId: matchedUser.id,
                      ),
                    ),
                  );
                },
                child: Text(tr("send_message"),
                    style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(tr("continue_browsing"),
                    style: const TextStyle(color: Colors.grey)),
              )
            ],
          ),
        );
      },
    );
  }

  Future<List<User>?> _fetchAllUsersWithoutFilter() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) return null;

    final matchService = MatchService(token: token);
    final result = await matchService.getSuggestedMatchesWithFilters({});
    
    if (result['success'] == true) {
      List<dynamic> matchesJson = result['matches'];
      List<User> matches =
          matchesJson.map((json) => User.fromJson(json)).toList();
      return matches;
    }
    return null;
  }

  // Método para cargar un perfil específico por ID
  Future<void> _loadProfileById(String profileId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) return;
    try {
      print("Intentando cargar perfil con ID: $profileId");
      final userService = UserService(token: token);
      final result = await userService.getUserProfile(profileId);

      if (result['success'] == true && result['user'] != null) {
        final loadedUser = User.fromJson(result['user']);
        print("Perfil cargado: ${loadedUser.username}");

        // Asegurarse de que el usuario no esté ya en la lista
        if (!_loadedProfileIds.contains(loadedUser.id)) {
          setState(() {
            // Insertar al principio para asegurarnos de que sea visible
            _randomUsers.insert(0, loadedUser);
            _loadedProfileIds.add(loadedUser.id);

            // Saltar al primer elemento (perfil cargado)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _verticalPageController.jumpToPage(0);
              previousPageIndex = 0;
              _currentPageIndex = 0;
            });
          });
        } else {
          // Si ya está en la lista, saltar a él
          int indexToJump =
              _randomUsers.indexWhere((user) => user.id == profileId);
          if (indexToJump != -1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _verticalPageController.jumpToPage(indexToJump);
              previousPageIndex = indexToJump;
              _currentPageIndex = indexToJump;
            });
          }
        }
      } else {
        print("Error al cargar perfil: ${result['message']}");
        // Si falla la carga, barajar la lista
        setState(() {
          _randomUsers.shuffle();
        });
      }
    } catch (e) {
      print('Error al cargar el perfil: $e');
      // Si hay excepción, barajar la lista
      setState(() {
        _randomUsers.shuffle();
      });
    }
  }

  void _showReportModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Reportar usuario',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Divider(color: Colors.white54),
              ListTile(
                leading: Icon(Icons.photo, color: Colors.blueAccent),
                title: Text('Fotos inapropiadas', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(Icons.report, color: Colors.blueAccent),
                title: Text('Acoso', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(Icons.person_off, color: Colors.blueAccent),
                title: Text('Perfil falso', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(Icons.text_snippet, color: Colors.blueAccent),
                title: Text('Contenido ofensivo', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(Icons.more_horiz, color: Colors.blueAccent),
                title: Text('Otro motivo', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
              SizedBox(height: 16),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(tr("cancel")),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _verticalPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthProvider>(context);
    final List<User> currentList = showRandom ? _randomUsers : _likedUsers;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: currentList.isEmpty
                ? Center(
                    child: Text(
                      tr("no_users_to_show"),
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // Usamos el controlador de página directamente en lugar de intentar
                      // acceder a la propiedad inexistente currentPage
                      if (notification is ScrollUpdateNotification &&
                          notification.metrics.axis == Axis.vertical) {
                        // Obtener la página actual desde el controlador
                        final currentPage =
                            _verticalPageController.page?.round() ?? 0;

                        // Si el límite de scroll está alcanzado y el usuario intenta hacer scroll hacia abajo
                        if (_isScrollLimitReached && currentPage > previousPageIndex) {
                          // Bloquear el scroll volviendo a la página anterior
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _verticalPageController.jumpToPage(previousPageIndex);
                          });

                          // Mostrar el diálogo de límite alcanzado
                          _showScrollLimitDialog();
                          return false;
                        }

                        if (currentPage > previousPageIndex) {
                          _updateScrollCount();

                          // Registrar el perfil como visto y enviarlo al backend
                          if (currentPage < _randomUsers.length) {
                            final viewedUser = _randomUsers[currentPage];
                            if (!_seenProfileIds.contains(viewedUser.id)) {
                              _seenProfileIds.add(viewedUser.id);
                              _updateSeenProfile(viewedUser.id);
                            }
                          }

                          previousPageIndex = currentPage;
                        }
                      }
                      return false;
                    },
                    child: PageView.builder(
                      // Eliminamos la key para que no reconstruya el widget al cambiar de pestaña
                      controller: _verticalPageController,
                      physics: LimitedScrollPhysics(
                        isLimitReached: _isScrollLimitReached,
                      ),
                      scrollDirection: Axis.vertical,
                      itemCount: currentList.length,
                      onPageChanged: (pageIndex) {
                        setState(() {
                          _currentPageIndex = pageIndex;
                          // Guardamos la posición actual cuando estamos en la pestaña de aleatorios
                          if (showRandom) {
                            _savedRandomPosition = pageIndex;
                          }
                        });

                        // Ya estamos manejando la actualización del contador en el NotificationListener,
                        // así que aquí solo verificamos si necesitamos cargar más usuarios
                        if (pageIndex >= _randomUsers.length - 5) {
                          print("Alcanzado umbral de carga: $pageIndex >= ${_randomUsers.length - 5}");
                          _fetchMoreUsers();
                        }
                      },
                      itemBuilder: (context, index) {
                        final user = currentList[index];
                        return SingleUserView(
                          user: user,
                          onDoubleTapLike: showRandom
                              ? () => _handleLike(index)
                              : () => _handleLikeFromLeGustas(index),
                        );
                      },
                    ),
                  ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Row(
              children: [
                IconButton(
                  onPressed: _showReportModal,
                  icon: Icon(Icons.warning, color: Colors.white),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              showRandom ? Colors.white : Colors.black45,
                          foregroundColor:
                              showRandom ? Colors.black : Colors.white,
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (!showRandom) {
                            setState(() {
                              showRandom = true;
                            });
                            
                            // Restaurar la posición guardada de la lista aleatoria
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_savedRandomPosition < _randomUsers.length) {
                                _verticalPageController.jumpToPage(_savedRandomPosition);
                                _currentPageIndex = _savedRandomPosition;
                                previousPageIndex = _savedRandomPosition;
                              }
                            });
                          }
                        },
                        child: Text(tr("random")),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "|",
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              !showRandom ? Colors.white : Colors.black45,
                          foregroundColor:
                              !showRandom ? Colors.black : Colors.white,
                          elevation: 0,
                        ),
                        onPressed: () {
                          final auth =
                              Provider.of<AuthProvider>(context, listen: false);
                          if (!(auth.user?.isPremium ?? false)) {
                            _showPremiumDialog(
                              tr("premium_function"),
                              tr("premium_le_gustas_message"),
                            );
                          } else {
                            // Guardar la posición actual de la lista aleatoria antes de cambiar
                            if (showRandom) {
                              _savedRandomPosition = _currentPageIndex;
                            }
                            
                            setState(() {
                              showRandom = false;
                            });
                            
                            // Restaurar al inicio de la lista "Le gustas"
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _verticalPageController.jumpToPage(0);
                              _currentPageIndex = 0;
                              previousPageIndex = 0;
                            });
                            
                            if (_likedUsers.isEmpty) {
                              _fetchLikedUsers();
                            }
                          }
                        },
                        child: Text(tr("le_gustas_button", namedArgs: {
                          "count": _likedUsers.length.toString()
                        })),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final hasLocation = (auth.user?.location != null) &&
                        (auth.user?.location?.coordinates.length == 2) &&
                        !(auth.user?.location?.coordinates[0] == 0 &&
                            auth.user?.location?.coordinates[1] == 0);
                    final result = await showModalBottomSheet<dynamic>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (context) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF0D0D0D),
                                Color(0xFF1C1C1C),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          child: FilterModalContent(
                            hasLocation: hasLocation,
                            initialAgeRange: _currentAgeRange,
                            initialWeightRange: _currentWeightRange,
                            initialHeightRange: _currentHeightRange,
                            initialGymStage: _currentGymStage,
                            initialRelationshipType: _currentRelationshipType,
                            initialUseLocation: _currentUseLocation,
                            initialDistanceRange: _currentDistanceRange,
                          ),
                        );
                      },
                    );

                    if (result != null && result is Map) {
                      if (result['remove'] == true) {
                        print('Quitando filtros');
                        // Reiniciar los valores de filtro a los predeterminados
                        setState(() {
                          _currentAgeRange = const RangeValues(18, 50);
                          _currentWeightRange = const RangeValues(50, 100);
                          _currentHeightRange = const RangeValues(150, 200);
                          _currentGymStage = 'Todos';
                          _currentRelationshipType = 'Todos';
                          _currentUseLocation = false;
                          _currentDistanceRange = const RangeValues(5, 50);
                        });
                        
                        var allUsers = await _fetchAllUsersWithoutFilter();
                        if (allUsers != null) {
                          setState(() {
                            _randomUsers = allUsers;
                            if (_randomUsers.isNotEmpty) {
                              _randomUsers.shuffle();
                            }
                            showRandom = true;
                          });
                        }
                      } else if (result['matches'] != null) {
                        List<User> matches = List<User>.from(result['matches']);
                        setState(() {
                          // Guardar los valores del filtro actual
                          print('Filtros aplicados:');
                          print('Etapa de Gimnasio: ${result['gymStage']}');
                          print('Tipo de Relación: ${result['relationshipType']}');
                          print('Usuarios recibidos: ${matches.length}');
                          
                          _currentAgeRange = result['ageRange'];
                          _currentWeightRange = result['weightRange'];
                          _currentHeightRange = result['heightRange'];
                          _currentGymStage = result['gymStage'];
                          _currentRelationshipType = result['relationshipType'];
                          _currentUseLocation = result['useLocation'];
                          _currentDistanceRange = result['distanceRange'];
                          
                          _randomUsers = matches;
                          if (_randomUsers.isNotEmpty) {
                            _randomUsers.shuffle();
                          }
                          showRandom = true;
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.settings, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FilterModalContent extends StatefulWidget {
  final bool hasLocation;
  final RangeValues initialAgeRange;
  final RangeValues initialWeightRange;
  final RangeValues initialHeightRange;
  final String initialGymStage;
  final String initialRelationshipType;
  final bool initialUseLocation;
  final RangeValues initialDistanceRange;

  const FilterModalContent({
    Key? key,
    required this.hasLocation,
    required this.initialAgeRange,
    required this.initialWeightRange,
    required this.initialHeightRange,
    required this.initialGymStage,
    required this.initialRelationshipType,
    this.initialUseLocation = false,
    this.initialDistanceRange = const RangeValues(5, 50),
  }) : super(key: key);

  @override
  _FilterModalContentState createState() => _FilterModalContentState();
}

class _FilterModalContentState extends State<FilterModalContent> {
  late RangeValues ageRange;
  late RangeValues weightRange;
  late RangeValues heightRange;
  late String selectedGymStage;
  late String selectedRelationshipType;

  bool useLocation = false;
  RangeValues distanceRange = const RangeValues(5, 50);

  @override
  void initState() {
    super.initState();
    ageRange = widget.initialAgeRange;
    weightRange = widget.initialWeightRange;
    heightRange = widget.initialHeightRange;
    selectedGymStage = widget.initialGymStage;
    selectedRelationshipType = widget.initialRelationshipType;
    useLocation = widget.initialUseLocation;
    distanceRange = widget.initialDistanceRange;
  }

  @override
  Widget build(BuildContext context) {
    // Map underlying values to localized labels
    final gymStageMap = {
      'Todos': tr('all'),
      'Mantenimiento': tr('maintenance'),
      'Volumen': tr('volume'),
      'Definición': tr('definition'),
    };
    final relationshipTypeMap = {
      'Todos': tr('all'),
      'Amistad': tr('friendship'),
      'Relación': tr('relationship'),
      'Casual': tr('casual'),
      'Otro': tr('other'),
      'Pendiente': tr('pending'),
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tr("filter"),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 40),
            _buildRangeSlider(
              label: tr("age_range"),
              values: ageRange,
              min: 18,
              max: 100,
              divisions: 82,
              onChanged: (values) {
                setState(() {
                  ageRange = values;
                });
              },
            ),
            _buildRangeSlider(
              label: tr("weight_range"),
              values: weightRange,
              min: 40,
              max: 200,
              divisions: 160,
              onChanged: (values) {
                setState(() {
                  weightRange = values;
                });
              },
            ),
            _buildRangeSlider(
              label: tr("height_range"),
              values: heightRange,
              min: 100,
              max: 250,
              divisions: 150,
              onChanged: (values) {
                setState(() {
                  heightRange = values;
                });
              },
            ),
            const SizedBox(height: 10),
            // Dropdown Gym Stage
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr("gym_stage_filter"), style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: selectedGymStage,
                    dropdownColor: Colors.grey[850],
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: gymStageMap.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    )).toList(),
                    onChanged: (newValue) {
                      setState(() { selectedGymStage = newValue!; });
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
            // Dropdown Relationship Type
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr("relationship_type_filter"), style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: selectedRelationshipType,
                    dropdownColor: Colors.grey[850],
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: relationshipTypeMap.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    )).toList(),
                    onChanged: (newValue) {
                      setState(() { selectedRelationshipType = newValue!; });
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.hasLocation)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text(
                      tr("filter_by_location"),
                      style: const TextStyle(color: Colors.white),
                    ),
                    value: useLocation,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) {
                      setState(() {
                        useLocation = val;
                      });
                    },
                  ),
                  if (useLocation)
                    _buildRangeSlider(
                      label: tr("distance_km"),
                      values: distanceRange,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: (values) {
                        setState(() {
                          distanceRange = values;
                        });
                      },
                    ),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () async {
                final filters = <String, String>{
                  'ageMin': ageRange.start.round().toString(),
                  'ageMax': ageRange.end.round().toString(),
                  'weightMin': weightRange.start.round().toString(),
                  'weightMax': weightRange.end.round().toString(),
                  'heightMin': heightRange.start.round().toString(),
                  'heightMax': heightRange.end.round().toString(),
                  'gymStage': selectedGymStage,
                  'relationshipGoal': selectedRelationshipType,
                  'useLocation': useLocation ? 'true' : 'false',
                };

                if (useLocation) {
                  filters['distanceMin'] =
                      distanceRange.start.round().toString();
                  filters['distanceMax'] = distanceRange.end.round().toString();
                }

                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                final token = await authProvider.getToken();

                if (token != null) {
                  final matchService = MatchService(token: token);
                  final result = await matchService
                      .getSuggestedMatchesWithFilters(filters);

                  if (result['success'] == true) {
                    List<dynamic> matchesJson = result['matches'];
                    List<User> matches =
                        matchesJson.map((json) => User.fromJson(json)).toList();

                    Navigator.of(context).pop({
                      'matches': matches,
                      'ageRange': ageRange,
                      'weightRange': weightRange,
                      'heightRange': heightRange,
                      'gymStage': selectedGymStage,
                      'relationshipType': selectedRelationshipType,
                      'useLocation': useLocation,
                      'distanceRange': distanceRange,
                    });
                    return;
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ??
                            tr("error_fetching_more_users")),
                      ),
                    );
                  }
                }

                Navigator.of(context).pop();
              },
              child: Text(
                tr("apply"),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop({'remove': true});
              },
              child: Text(
                tr("remove_filter"),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSlider({
    required String label,
    required RangeValues values,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<RangeValues> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: divisions,
          labels: RangeLabels(
            "${values.start.round()}",
            "${values.end.round()}",
          ),
          activeColor: Colors.blueAccent,
          inactiveColor: Colors.grey,
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
