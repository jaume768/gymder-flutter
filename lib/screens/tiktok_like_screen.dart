import 'package:app/screens/premium_purchase_page.dart';
import 'package:app/screens/single_user_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/match_service.dart';
import '../services/user_service.dart';
import 'chat_screen.dart';

class LimitedScrollPhysics extends ScrollPhysics {
  final bool premium;
  final int scrollCount;
  final int maxDownwardScroll;

  const LimitedScrollPhysics({
    ScrollPhysics? parent,
    required this.premium,
    required this.scrollCount,
    required this.maxDownwardScroll,
  }) : super(parent: parent);

  @override
  LimitedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LimitedScrollPhysics(
      parent: buildParent(ancestor),
      premium: premium,
      scrollCount: scrollCount,
      maxDownwardScroll: maxDownwardScroll,
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (!premium && value < position.pixels) {
      return value - position.pixels;
    }
    if (!premium &&
        scrollCount >= maxDownwardScroll &&
        value > position.pixels) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
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
  late List<User> _randomUsers;
  List<User> _likedUsers = [];

  int scrollCount = 0;
  int likeCount = 0;
  int previousPageIndex = 0;
  DateTime? scrollLimitReachedTime;
  DateTime? likeLimitReachedTime;
  final Duration limitDuration = const Duration(hours: 10);
  final Duration likeLimitDuration = const Duration(hours: 10);

  // Variables para persistir filtros
  RangeValues ageRangeFilter = const RangeValues(18, 50);
  RangeValues weightRangeFilter = const RangeValues(50, 100);
  RangeValues heightRangeFilter = const RangeValues(150, 200);
  String gymStageFilter = 'Mantenimiento';
  String relationshipTypeFilter = 'Amistad';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _verticalPageController = PageController();
    _randomUsers = List.from(widget.users);
    _randomUsers.shuffle(); // Orden aleatorio de usuarios
    previousPageIndex = 0;

    // Cargar los usuarios que te han dado like al iniciar
    _fetchLikedUsers();
  }

  @override
  void dispose() {
    _verticalPageController.dispose();
    super.dispose();
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
      print("Usuarios que me dieron like: ${_likedUsers.length}");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error al obtener likes')),
      );
    }
  }

  Future<void> _handleLike(int userIndex) async {
    if (_isProcessing) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userIsPremium = authProvider.user?.isPremium ?? false;

    int localMaxLike = (authProvider.user?.gender == 'Masculino') ? 20 : 40;

    // Verificar el límite de likes antes de proceder
    if (!userIsPremium && likeCount >= localMaxLike) {
      likeLimitReachedTime ??= DateTime.now();
      Duration timePassed = DateTime.now().difference(likeLimitReachedTime!);
      if (timePassed < likeLimitDuration) {
        Duration remaining = likeLimitDuration - timePassed;
        _showPremiumDialog(
          "Límite de likes alcanzado",
          "Has llegado al número máximo de likes. Espera ${remaining.inHours} horas y ${remaining.inMinutes % 60} minutos o mira un video para expandirlo.",
        );
        return; // Cancela el like sin enviarlo
      } else {
        // Reinicia el contador si ya pasó el tiempo
        setState(() {
          likeCount = 0;
          likeLimitReachedTime = null;
        });
      }
    }

    // Ya no incrementamos scrollCount aquí, solo likeCount
    _isProcessing = true;
    final user = _randomUsers[userIndex];

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
      final currentUser = authProvider.user;
      if (result['matchedUser'] != null && currentUser != null) {
        _mostrarModalMatch(context, currentUser, user);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error al dar like')),
      );
    }

    setState(() {
      _randomUsers.removeAt(userIndex);
      // Incrementa solo el contador de likes aquí
      if (!userIsPremium) likeCount++;
    });

    if (_randomUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay más usuarios')),
      );
    } else if (userIndex < _randomUsers.length) {
      _verticalPageController.animateToPage(
        userIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
      );
    }

    _isProcessing = false;

    // Verifica el límite de likes nuevamente en caso de que se necesite mostrar el aviso
    if (!userIsPremium) {
      _checkLikeLimit(localMaxLike);
    }
  }

  Future<void> _handleLikeFromLeGustas(int userIndex) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final user = _likedUsers[userIndex];
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
        final currentUser =
            Provider.of<AuthProvider>(context, listen: false).user;
        if (result['matchedUser'] != null && currentUser != null) {
          _mostrarModalMatch(context, currentUser, user);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error al dar like')),
      );
    }

    setState(() {
      _likedUsers.removeAt(userIndex);
    });

    _isProcessing = false;
  }

  void _checkScrollLimit(int maxScrollLimit) {
    if (scrollCount >= maxScrollLimit) {
      scrollLimitReachedTime ??= DateTime.now();
      Duration timePassed = DateTime.now().difference(scrollLimitReachedTime!);
      if (timePassed < limitDuration) {
        Duration remaining = limitDuration - timePassed;
        _showPremiumDialog(
          "Límite de scroll alcanzado",
          "Has llegado al número máximo de scrolls. Espera ${remaining.inHours} horas y ${remaining.inMinutes % 60} minutos o mira un video para expandirlo.",
        );
      } else {
        setState(() {
          scrollCount = 0;
          scrollLimitReachedTime = null;
        });
      }
    }
  }

  void _checkLikeLimit(int maxLikeLimit) {
    if (likeCount >= maxLikeLimit) {
      likeLimitReachedTime ??= DateTime.now();
      Duration timePassed = DateTime.now().difference(likeLimitReachedTime!);
      if (timePassed < likeLimitDuration) {
        Duration remaining = likeLimitDuration - timePassed;
        _showPremiumDialog(
          "Límite de likes alcanzado",
          "Has llegado al número máximo de likes. Espera ${remaining.inHours} horas y ${remaining.inMinutes % 60} minutos o mira un video para expandirlo.",
        );
      } else {
        setState(() {
          likeCount = 0;
          likeLimitReachedTime = null;
        });
      }
    }
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
            child: const Text("Cancelar",
                style: TextStyle(color: Colors.blueAccent)),
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
            child: const Text("Comprar",
                style: TextStyle(color: Colors.blueAccent)),
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
          backgroundColor: Colors.black.withValues(alpha: 0.6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¡Tienes un match!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Tú y ${matchedUser.username} os habéis dado like mutuamente',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
              // Sección de las dos fotos
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
                  Navigator.pop(context); // Cierra el modal
                  // Luego navegas al chat
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
                child: const Text(
                  'Enviar mensaje',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Simplemente cierras el modal
                },
                child: const Text(
                  'Seguir navegando',
                  style: TextStyle(color: Colors.grey),
                ),
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

  @override
  Widget build(BuildContext context) {
    super
        .build(context);
    final auth = Provider.of<AuthProvider>(context);
    final int maxScrollLimit = (auth.user?.gender == 'Masculino') ? 25 : 45;
    final currentList = showRandom ? _randomUsers : _likedUsers;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: currentList.isEmpty
                ? const Center(
                    child: Text(
                      'No hay usuarios para mostrar.',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.axis == Axis.vertical) {
                        if (!auth.user!.isPremium &&
                            notification.direction == ScrollDirection.forward) {
                          _showPremiumDialog(
                            "Función Premium",
                            "Para hacer scroll hacia arriba y volver al usuario anterior necesitas ser premium. ¿Deseas comprarlo?",
                          );
                        }
                        if (!auth.user!.isPremium &&
                            notification.direction == ScrollDirection.reverse) {
                          _checkScrollLimit(maxScrollLimit);
                        }
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _verticalPageController,
                      scrollDirection: Axis.vertical,
                      physics: LimitedScrollPhysics(
                        premium: auth.user?.isPremium ?? false,
                        scrollCount: scrollCount,
                        maxDownwardScroll: maxScrollLimit,
                      ),
                      itemCount: currentList.length,
                      onPageChanged: (pageIndex) {
                        if (!auth.user!.isPremium &&
                            pageIndex > previousPageIndex) {
                          setState(() {
                            scrollCount++;
                          });
                          _checkScrollLimit(maxScrollLimit);
                        }
                        previousPageIndex = pageIndex;
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
            left: 60,
            right: 0,
            child: Row(
              children: [
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
                          setState(() {
                            showRandom = true;
                          });
                        },
                        child: const Text('Aleatorio'),
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
                              "Función Premium",
                              "Para ver a las personas que le gustas necesitas ser premium. ¿Deseas comprarlo?",
                            );
                          } else {
                            setState(() {
                              showRandom = false;
                            });
                            if (_likedUsers.isEmpty) {
                              _fetchLikedUsers();
                            }
                          }
                        },
                        child: Text('Le gustas (${_likedUsers.length})'),
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
                            initialAgeRange: ageRangeFilter,
                            initialWeightRange: weightRangeFilter,
                            initialHeightRange: heightRangeFilter,
                            initialGymStage: gymStageFilter,
                            initialRelationshipType: relationshipTypeFilter,
                          ),
                        );
                      },
                    );

                    if (result != null && result is Map) {
                      if (result['remove'] == true) {
                        // Quitar filtro: cargar todos los usuarios
                        var allUsers = await _fetchAllUsersWithoutFilter();
                        if (allUsers != null) {
                          setState(() {
                            _randomUsers = allUsers;
                            _randomUsers.shuffle();
                            showRandom = true;

                            // Resetear filtros a valores predeterminados si se desea
                            ageRangeFilter = const RangeValues(18, 50);
                            weightRangeFilter = const RangeValues(50, 100);
                            heightRangeFilter = const RangeValues(150, 200);
                            gymStageFilter = 'Mantenimiento';
                            relationshipTypeFilter = 'Amistad';
                          });
                        }
                      } else if (result['matches'] != null) {
                        List<User> matches = List<User>.from(result['matches']);
                        setState(() {
                          _randomUsers = matches;
                          _randomUsers.shuffle();
                          showRandom = true;

                          // Actualizar variables de filtro con los valores seleccionados
                          ageRangeFilter = result['ageRange'] as RangeValues;
                          weightRangeFilter =
                              result['weightRange'] as RangeValues;
                          heightRangeFilter =
                              result['heightRange'] as RangeValues;
                          gymStageFilter = result['gymStage'] as String;
                          relationshipTypeFilter =
                              result['relationshipType'] as String;
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

// Definición de FilterModalContent con valores iniciales
class FilterModalContent extends StatefulWidget {
  final bool hasLocation; // <-- Nuevo: si el user tiene location
  final RangeValues initialAgeRange;
  final RangeValues initialWeightRange;
  final RangeValues initialHeightRange;
  final String initialGymStage;
  final String initialRelationshipType;

  // Podrías también recibir 'initialUseLocation' y 'initialDistanceRange' si quieres que se guarde
  // el estado de la última vez. Para simplificar, supondremos que es false por defecto.

  const FilterModalContent({
    Key? key,
    required this.hasLocation,
    required this.initialAgeRange,
    required this.initialWeightRange,
    required this.initialHeightRange,
    required this.initialGymStage,
    required this.initialRelationshipType,
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
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra superior "drag"
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Filtrar",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 40),

            // Filtros de edad, peso, altura
            _buildRangeSlider(
              label: "Rango de edad",
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
              label: "Rango de peso (kg)",
              values: weightRange,
              min: 40,
              max: 150,
              divisions: 110,
              onChanged: (values) {
                setState(() {
                  weightRange = values;
                });
              },
            ),
            _buildRangeSlider(
              label: "Rango de altura (cm)",
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
            _buildDropdown(
              label: "Etapa en el gym",
              value: selectedGymStage,
              items: const ['Todos', 'Mantenimiento', 'Volumen', 'Definición'],
              onChanged: (String? newValue) {
                setState(() {
                  selectedGymStage = newValue!;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildDropdown(
              label: "Tipo de relación",
              value: selectedRelationshipType,
              items: const [
                'Todos',
                'Amistad',
                'Relación',
                'Casual',
                'Otro',
                'Pendiente'
              ],
              onChanged: (String? newValue) {
                setState(() {
                  selectedRelationshipType = newValue!;
                });
              },
            ),
            const SizedBox(height: 20),

            // Solo si el user tiene location, mostramos la opción:
            if (widget.hasLocation)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text(
                      "Filtrar por ubicación",
                      style: TextStyle(color: Colors.white),
                    ),
                    value: useLocation,
                    onChanged: (val) {
                      setState(() {
                        useLocation = val;
                      });
                    },
                  ),
                  // Si useLocation = true, mostramos el RangeSlider de distancias
                  if (useLocation)
                    _buildRangeSlider(
                      label: "Distancia (km)",
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

            // Botón "Aplicar"
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
                // Construimos el map "filters" con strings
                final filters = <String, String>{
                  'ageMin': ageRange.start.round().toString(),
                  'ageMax': ageRange.end.round().toString(),
                  'weightMin': weightRange.start.round().toString(),
                  'weightMax': weightRange.end.round().toString(),
                  'heightMin': heightRange.start.round().toString(),
                  'heightMax': heightRange.end.round().toString(),
                  'gymStage': selectedGymStage,
                  'relationshipGoal': selectedRelationshipType,
                  // Enviamos si se filtra x ubicación:
                  'useLocation': useLocation ? 'true' : 'false',
                };

                // Si se filtra x ubicación, agregamos distanceMin y distanceMax:
                if (useLocation) {
                  filters['distanceMin'] =
                      distanceRange.start.round().toString();
                  filters['distanceMax'] = distanceRange.end.round().toString();
                }

                // Llamada al backend:
                final authProvider =
                    // ignore: use_build_context_synchronously
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

                    // Retornar matches y los nuevos valores:
                    // Devuelve un map para que el parent reciba.
                    // Por ejemplo:
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
                        content: Text(
                            result['message'] ?? 'Error al obtener matches'),
                      ),
                    );
                  }
                }

                Navigator.of(context).pop();
              },
              child: const Text(
                "Aplicar",
                style: TextStyle(color: Colors.black),
              ),
            ),

            const SizedBox(height: 10),

            // Botón "Quitar filtro"
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
              child: const Text(
                "Quitar filtro",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------
  // Helpers para construir UI
  // ---------------------------------

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

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value: value,
            dropdownColor: Colors.grey[850],
            style: const TextStyle(color: Colors.white),
            isExpanded: true,
            underline: const SizedBox(),
            items: items.map<DropdownMenuItem<String>>((val) {
              return DropdownMenuItem(
                value: val,
                child: Text(val),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
