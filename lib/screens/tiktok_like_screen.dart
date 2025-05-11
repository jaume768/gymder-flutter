import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/screens/single_user_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app/screens/premium_purchase_page.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/match_service.dart';
import '../services/user_service.dart';
import '../screens/chat_screen.dart';

class ReverseScrollPhysics extends PageScrollPhysics {
  final bool blockReverse;
  const ReverseScrollPhysics({
    ScrollPhysics? parent,
    required this.blockReverse,
  }) : super(parent: parent);

  @override
  ReverseScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReverseScrollPhysics(
      parent: buildParent(ancestor),
      blockReverse: blockReverse,
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // offset > 0 → gesto de arrastrar hacia abajo = anterior página
    if (blockReverse && offset > 0) {
      return 0.0; // cortamos el scroll
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }
}

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
  final VoidCallback onBuyQuickLike;    // ⚡️ nuevo callback

  const TikTokLikeScreen({
    Key? key,
    required this.users,
    required this.onBuyQuickLike,
  }) : super(key: key);

  @override
  State<TikTokLikeScreen> createState() => TikTokLikeScreenState();
}

class TikTokLikeScreenState extends State<TikTokLikeScreen>
    with AutomaticKeepAliveClientMixin {
  late PageController _verticalPageController;
  bool _isProcessing = false;
  bool showRandom = true;
  List<User> _randomUsers = [];
  bool _isFetchingMore = false;
  final int _limit = 20;
  List<User> _likedUsers = [];
  bool _isLoading = true;
  int _lastFetchThreshold = 0;

  int _currentPageIndex = 0;
  bool _hasShownScrollLimitDialog = false;
  bool _isLikeLimitReached = false;
  DateTime? _likeLimitResetAt;
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
  bool _currentFilterByBasics = false;
  RangeValues _currentSquatRange = const RangeValues(0, 300);
  RangeValues _currentBenchRange = const RangeValues(0, 200);
  RangeValues _currentDeadliftRange = const RangeValues(0, 400);

  // Variable para almacenar los filtros activos que se usarán en la paginación
  Map<String, String> _activeFilters = {};

  // Variable para rastrear cuándo comenzó la última solicitud de carga
  DateTime? _lastFetchStartTime;

  @override
  bool get wantKeepAlive => true;

  Future<void> _markInitialProfilesAsSeen() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) return;
    final matchService = MatchService(token: token);
    await matchService.updateSeenProfiles(_loadedProfileIds.toList());
    // opcional: _seenProfileIds.addAll(_loadedProfileIds);
  }

  @override
  @override
  void initState() {
    super.initState();
    _verticalPageController = PageController();
    _verticalPageController.addListener(() async {
      final idx = _verticalPageController.page?.round() ?? 0;
      if (idx != previousPageIndex) {
        previousPageIndex = idx;
        final seenId = _randomUsers[idx].id;
        // 1) Añádelo a tu set local
        _seenProfileIds.add(seenId);
        // 2) Envía al servidor
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final token = await auth.getToken();
        if (token != null) {
          await MatchService(token: token).updateSeenProfiles([seenId]);
        }
      }
    });
    Future.wait([_loadInitialBatch(), _fetchLikedUsers()]).whenComplete(() {
      setState(() => _isLoading = false);
    });
    _setupFCM();
  }

  Future<void> _loadInitialBatch() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) return;
    final matchService = MatchService(token: token);

    // Pedimos la primera página (skip = 0)
    final filters = Map<String, String>.from(_activeFilters);
    filters['limit'] = '20';
    filters['skip'] = '0';

    final res = await matchService.getSuggestedMatchesWithFilters(filters);
    if (res['success'] == true) {
      setState(() {
        _randomUsers =
            res['matches'].map<User>((j) => User.fromJson(j)).toList();
        _loadedProfileIds = _randomUsers.map((u) => u.id).toSet();
      });
    }
  }

  Future<void> reloadProfiles() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) return;

    final service = UserService(token: token);
    final result = await service.getSuggestedMatches();
    if (result['success'] == true) {
      setState(() {
        _randomUsers =
            List<User>.from(result['matches'].map((j) => User.fromJson(j)));
        _loadedProfileIds
          ..clear()
          ..addAll(_randomUsers.map((u) => u.id));

        // Resetear índices para volver al inicio
        _currentPageIndex = 0;
        previousPageIndex = 0;
        _savedRandomPosition = 0;
      });

      // Usar post-frame callback para resetear el PageController después de que el estado se actualice
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _randomUsers.isNotEmpty) {
          _verticalPageController.jumpToPage(0);
          // Precargar la primera imagen para mejorar la experiencia
          _preloadImagesForUser(_randomUsers[0]);
          if (_randomUsers.length > 1) {
            _preloadImagesForUser(_randomUsers[1]);
          }
        }
      });
    }
  }

  void _resetScrollLimitDialogFlag() {
    _hasShownScrollLimitDialog = false;
  }

  void _showQuickLikeNotAllowedDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícono de bloqueo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Título
              Text(
                tr("quicklike_not_allowed_title"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Mensaje
              Text(
                tr("quicklike_not_allowed_legustas"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),

              // Botón Aceptar
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    tr("ok"),
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> useSuperLike() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.user!;
    // 0) Si no tiene QuickLikes
    if (currentUser.topLikeCount <= 0) {
      final buy = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr("no_quicklikes_title"),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(tr("no_quicklikes_message"),
                    textAlign: TextAlign.center,
                    style:
                    const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white38),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(tr("cancel"),
                            style: const TextStyle(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(tr("buy_more_quick_likes_modal"),
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (buy == true) {
        // ⚡️ en lugar de PremiumPurchasePage, llamamos al callback:
        widget.onBuyQuickLike();
      }
      setState(() => _isProcessing = false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr("confirm_quicklike_title"),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(tr("confirm_quicklike_message"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(tr("cancel"),
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(tr("yes"),
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Si el usuario canceló, reseteamos y salimos
    if (confirmed != true) {
      setState(() => _isProcessing = false);
      return;
    }

    final token = await auth.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr("token_not_found"))));
      setState(() => _isProcessing = false);
      return;
    }

    final service = UserService(token: token);
    // ponemos un timeout por si el servidor no responde
    Map<String, dynamic>? res;
    try {
      res = await service
          .superLikeUser(_randomUsers[_currentPageIndex].id)
          .timeout(Duration(seconds: 8));
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr("error_timeout"))));
      setState(() => _isProcessing = false);
      return;
    }

    if (res['success'] != true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res['message'] ?? tr("error"))));
      setState(() => _isProcessing = false);
      return;
    }

    // 3) Muestro match o SnackBar
    final matchedMap = res['matchedUser'] as Map<String, dynamic>?;
    if (matchedMap != null) {
      final matchedUser = User.fromJson(matchedMap);
      _mostrarModalMatch(context, auth.user!, matchedUser);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr("superlike_sent"))));
    }

    // 4) Saco el perfil de la lista y animo al siguiente
    setState(() {
      _randomUsers.removeAt(_currentPageIndex);
      if (_currentPageIndex >= _randomUsers.length)
        _currentPageIndex = _randomUsers.length - 1;
      _isProcessing = false; // 🎯 Reset aquí
    });

    if (_randomUsers.isNotEmpty) {
      _verticalPageController.animateToPage(
        _currentPageIndex.clamp(0, _randomUsers.length - 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }

    // 5) Ahora, en background, refresco el user
    unawaited(auth.refreshUser());
  }

  Future<void> _checkLikeLimitStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) return;
    final service = UserService(token: token);
    final res = await service.getLikeLimitStatus();
    if (res['success'] == true && res['limitActive'] == true) {
      setState(() {
        _isLikeLimitReached = true;
        _likeLimitResetAt = DateTime.parse(res['resetAt']);
      });
    }
  }

  void _showLikeLimitDialog() {
    final hoursLeft = _likeLimitResetAt != null
        ? _likeLimitResetAt!.difference(DateTime.now()).inHours
        : 0;
    final title = tr("premium_function");
    final content = tr("like_limit_message", args: [hoursLeft.toString()]);
    _showPremiumDialog(title, content);
  }

  Future<void> _requestAndroidNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _setupFCM() async {
    if (Platform.isAndroid) {
      await _requestAndroidNotificationPermission();
    }

    final messaging = FirebaseMessaging.instance;

    // 1) Pedir permiso
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('Permiso de notificaciones denegado');
      return;
    }

    // 2) Obtener el token FCM y enviarlo al backend
    final fcmToken = await messaging.getToken();
    if (fcmToken != null) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = await auth.getToken();
      if (token != null) {
        await http.post(
          Uri.parse(
              'https://gymder-api-production.up.railway.app/api/users/fcm-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode({'token': fcmToken}),
        );
      }
    }

    // 3) Escuchar notificaciones en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      print(
          '¡Notificación recibida en foreground!: ${msg.notification?.title}');
      // Si usas flutter_local_notifications, muéstrala aquí
    });

    // 4) Manejar when the user taps on a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      // Por ejemplo, navegar al chat de quien te dio like...
      final data = msg.data;
      if (data['type'] == 'new_like') {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatScreen(
                    currentUserId: data['toUserId'],
                    matchedUserId: data['fromUserId'],
                  )),
        );
      }
    });
  }

  // Método para la inicialización completa de la pantalla
  Future<void> _initializeScreen() async {
    await _checkScrollLimitStatus();

    await _fetchLikedUsers();

    if (!_isScrollLimitReached && _randomUsers.length > 1) {
      final first = _randomUsers.removeAt(0);
      _randomUsers.shuffle();
      _randomUsers.insert(0, first);
      setState(() {});
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

  void _preloadImagesForUser(User user) {
    if (user.photos == null) return;
    for (var photo in user.photos!) {
      // Con CachedNetworkImageProvider
      precacheImage(
        CachedNetworkImageProvider(photo.url),
        context,
      );
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

        if (limitReached) {
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
    if (_hasShownScrollLimitDialog) return;
    _hasShownScrollLimitDialog = true;
    _showPremiumDialog(
      tr("premium_function"),
      tr("scroll_limit_message", args: [_remainingHours.toString()]),
    );
  }

  Future<void> _fetchMoreUsers() async {
    if (_isFetchingMore) return;
    setState(() => _isFetchingMore = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;

      final matchService = MatchService(token: token);

      // Preparamos filtros
      final Map<String, String> filters = Map.from(_activeFilters);
      filters['limit'] = _limit.toString();
      // *Ya no enviamos `skip`*

      print("Solicitando usuarios con filtros: $filters");
      final result = await matchService.getSuggestedMatchesWithFilters(filters);

      if (result['success'] == true) {
        List<dynamic> matchesData = result['matches'];
        print("Recibidos ${matchesData.length} usuarios del backend");

        List<User> newUsers =
            matchesData.map((data) => User.fromJson(data)).toList();

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

              // Ahora sí marcamos como vistos los nuevos perfiles que acabamos de obtener
              if (uniqueNewUsers.isNotEmpty) {
                matchService.updateSeenProfiles(
                    uniqueNewUsers.map((u) => u.id).toList());
              }

              // NO hacemos shuffle después de cada carga para mantener coherencia de índices
              // Esto permite que el PageController mantenga las referencias correctas

              print(
                  "Añadidos ${uniqueNewUsers.length} nuevos usuarios únicos. Total: ${_randomUsers.length}");
            } else {
              print(
                  "No se encontraron nuevos usuarios para añadir (todos los recibidos ya estaban cargados)");

              // Si no hay nuevos usuarios pero el backend devuelve éxito, intentar hacer una solicitud
              // con parámetros diferentes para obtener más resultados
              if (matchesData.isEmpty && _activeFilters.isNotEmpty) {
                // Programar una solicitud sin filtros para obtener más usuarios
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted) {
                    _tryFetchMoreWithoutFilters();
                  }
                });
              }
            }
          });
        }
      } else {
        print("Error al cargar más usuarios: ${result['message']}");
        if (mounted) {
          // Mostrar snackbar con error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('error_loading_more_profiles') ??
                  "Error al cargar más perfiles"),
              duration: Duration(seconds: 2),
              action: SnackBarAction(
                label: tr('retry') ?? "Reintentar",
                onPressed: () => _fetchMoreUsers(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching more users: $e');
      if (mounted) {
        // Mostrar snackbar de error con opción de reintento
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('error_loading_more_profiles') ??
                "Error al cargar más perfiles"),
            duration: Duration(seconds: 2),
            action: SnackBarAction(
              label: tr('retry') ?? "Reintentar",
              onPressed: () => _fetchMoreUsers(),
            ),
          ),
        );
      }
    } finally {
      // IMPORTANTE: Siempre reseteamos _isFetchingMore al finalizar, sin importar el resultado
      if (mounted) {
        setState(() {
          _isFetchingMore = false;
        });
      }
    }
  }

  // Método auxiliar para intentar cargar más usuarios sin filtros cuando no hay más resultados con filtros
  Future<void> _tryFetchMoreWithoutFilters() async {
    if (_isFetchingMore) return;

    setState(() => _isFetchingMore = true);

    try {
      print(
          "Intentando cargar usuarios sin filtros después de no encontrar resultados");
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;

      final matchService = MatchService(token: token);

      // NO marcamos como vistos antes de la solicitud
      // Solicitar sin filtros pero con parámetros de paginación
      final Map<String, String> basicFilters = {
        'limit': _limit.toString(),
        'skip': _randomUsers.length.toString(),
      };

      final result =
          await matchService.getSuggestedMatchesWithFilters(basicFilters);

      if (result['success'] == true && mounted) {
        final matchesData = result['matches'] as List<dynamic>;
        final newUsers =
            matchesData.map((data) => User.fromJson(data)).toList();

        setState(() {
          final uniqueNewUsers = newUsers
              .where((user) => !_loadedProfileIds.contains(user.id))
              .toList();

          if (uniqueNewUsers.isNotEmpty) {
            _randomUsers.addAll(uniqueNewUsers);

            for (var user in uniqueNewUsers) {
              _loadedProfileIds.add(user.id);
            }

            // Ahora sí, marcar como vistos los nuevos perfiles
            if (uniqueNewUsers.isNotEmpty) {
              matchService
                  .updateSeenProfiles(uniqueNewUsers.map((u) => u.id).toList());
            }

            // NO hacemos shuffle para mantener la coherencia de índices
            print(
                "Añadidos ${uniqueNewUsers.length} usuarios adicionales sin filtros");
          } else {
            print("No se encontraron nuevos usuarios sin filtros");
          }
        });
      } else {
        print("No se encontraron perfiles adicionales sin filtros");
      }
    } catch (e) {
      print('Error en carga sin filtros: $e');
    } finally {
      // IMPORTANTE: Siempre reseteamos _isFetchingMore al finalizar
      if (mounted) {
        setState(() => _isFetchingMore = false);
      }
    }
  }

  void _handleLike(int userIndex) async {
    if (_isProcessing) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isPremium = auth.user?.isPremium ?? false;

    if (!isPremium && _isLikeLimitReached) {
      _showLikeLimitDialog();
      return;
    }

    setState(() => _isProcessing = true);
    final token = await auth.getToken();
    if (token == null) {
      /* error token */ return;
    }
    final service = UserService(token: token);

    final user = _randomUsers[userIndex];
    final result = await service.likeUser(user.id);

    if (result['success'] == true) {
      // Si hay match, muestro modal…
      if (result['matchedUser'] != null) {
        _mostrarModalMatch(context, auth.user!, user);
      }

      if (_isScrollLimitReached && userIndex == _currentPageIndex) {
        String? nextProfileId;
        if (_randomUsers.length > userIndex + 1) {
          nextProfileId = _randomUsers[userIndex + 1].id;
        } else if (userIndex > 0) {
          nextProfileId = _randomUsers[userIndex - 1].id;
        }

        if (nextProfileId != null) {
          final matchService = MatchService(token: token);
          await matchService.updateScrollCount(nextProfileId);
        }
      }
      setState(() => _randomUsers.removeAt(userIndex));
    } else if (result['limitReached'] == true) {
      // Actualizo estado y muestro diálogo, pero NO lo quito de la lista
      setState(() {
        _isLikeLimitReached = true;
        _likeLimitResetAt = DateTime.parse(result['resetAt']);
      });
      _showLikeLimitDialog();
      // Importante: salgo sin ejecutar ninguna eliminación
      _isProcessing = false;
      return;
    } else {
      // Otro error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? tr("error_liking_user"))));
    }

    // Si la lista quedó vacía tras un like o match...
    if (_randomUsers.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr("no_more_users"))));
    } else {
      // Mantengo la posición actual para mostrar el siguiente perfil
      final nextIndex = userIndex.clamp(0, _randomUsers.length - 1);
      _verticalPageController.animateToPage(
        nextIndex,
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
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blue, Colors.black87],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícono premium
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Título
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Contenido
              Text(
                content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white24,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PremiumPurchasePage(),
                          ),
                        );
                      },
                      child: Text(
                        'Comprar Premium',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    BuildContext context,
    User usuarioActual,
    User matchedUser,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "MatchDialog",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        // El child se centra por defecto
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr("match_title"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr("match_message",
                        namedArgs: {"username": matchedUser.username ?? ""}),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
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
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr("continue_browsing"),
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        // Opcional: animación de fade + scale
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
              scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
              child: child),
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

  void _onSelectReportReason(String reasonKey) {
    Navigator.pop(context);
    if (reasonKey == 'other') {
      _showCustomReasonDialog();
    } else {
      _showConfirmReportDialog(reasonKey);
    }
  }

  void _showConfirmReportDialog(String reasonKey, {String? details}) {
    final reasonText = {
      'inappropriate_photos': tr('inappropriate_photos'),
      'fake_profile': tr('fake_profile'),
      'offensive_content': tr('offensive_content'),
      'other': tr('other_reason'),
    }[reasonKey]!;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('confirm_report_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('confirm_report_message',
                      namedArgs: {'reason': reasonText}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          tr('cancel'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _sendReport(reasonKey, details: details);
                        },
                        child: Text(
                          tr('confirm_report_button'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomReasonDialog() {
    String customText = '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: StatefulBuilder(
                builder: (ctx2, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('other_reason'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: tr('describe_reason'),
                            hintStyle: const TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) {
                            setState(() => customText = val);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white38),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(
                                tr('cancel'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: customText.trim().isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(ctx).pop();
                                      _showConfirmReportDialog(
                                        'other',
                                        details: customText.trim(),
                                      );
                                    },
                              child: Text(
                                tr('send'),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendReport(String reasonKey, {String? details}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) return;
    final userService = UserService(token: token);

    // La lista y el índice actuales
    final list = showRandom ? _randomUsers : _likedUsers;
    if (_currentPageIndex < 0 || _currentPageIndex >= list.length) return;
    final reportedUser = list[_currentPageIndex];

    final result = await userService.reportUser(
      reportedUser.id,
      reason: reasonKey,
      details: details,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'])),
    );

    if (result['success'] == true) {
      setState(() {
        // 1) Eliminamos al usuario reportado
        list.removeAt(_currentPageIndex);

        // 2) Ajustamos el índice si estamos al final
        if (_currentPageIndex >= list.length && list.isNotEmpty) {
          _currentPageIndex = list.length - 1;
        }
      });

      // 3) Saltamos a la página actual (ahora el siguiente perfil)
      if (list.isNotEmpty) {
        _verticalPageController.jumpToPage(_currentPageIndex);
      }
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
                  tr('report_user_title'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Divider(color: Colors.white54),
              ListTile(
                leading: Icon(Icons.photo, color: Colors.blueAccent),
                title: Text(
                  tr('inappropriate_photos'),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _onSelectReportReason('inappropriate_photos'),
              ),
              ListTile(
                leading: Icon(Icons.person_off, color: Colors.blueAccent),
                title: Text(
                  tr('fake_profile'),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _onSelectReportReason('fake_profile'),
              ),
              ListTile(
                leading: Icon(Icons.text_snippet, color: Colors.blueAccent),
                title: Text(
                  tr('offensive_content'),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _onSelectReportReason('offensive_content'),
              ),
              ListTile(
                leading: Icon(Icons.more_horiz, color: Colors.blueAccent),
                title: Text(
                  tr('other_reason'),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _onSelectReportReason('other'),
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
                child: Text(tr('cancel')),
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isPremium = auth.user?.isPremium == true;
    final List<User> currentList = showRandom ? _randomUsers : _likedUsers;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
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
                            final isPremium = Provider.of<AuthProvider>(context,
                                        listen: false)
                                    .user
                                    ?.isPremium ==
                                true;
                            final currentPage =
                                (_verticalPageController.page ?? 0).round();

                            // 1) Capturar over-scroll en la primera página (índice 0)
                            if (notification is OverscrollNotification &&
                                notification.overscroll < 0 &&
                                currentPage == 0 &&
                                !isPremium) {
                              _showPremiumDialog(
                                tr("premium_function"),
                                tr("upgrade_to_premium_message"),
                              );
                              return true;
                            }

                            // 2) Capturar scroll normal con dragDetails
                            if (notification is ScrollUpdateNotification &&
                                notification.dragDetails != null) {
                              final dy = notification.dragDetails!.delta.dy;

                              // Intento de scroll hacia arriba en cualquier página
                              if (dy > 0 && !isPremium) {
                                _verticalPageController.jumpToPage(currentPage);
                                _showPremiumDialog(
                                  tr("premium_function"),
                                  tr("upgrade_to_premium_message"),
                                );
                                return true;
                              }

                              // Bloquear scroll hacia adelante si llegaste al límite
                              if (dy < 0 && _isScrollLimitReached) {
                                _verticalPageController.jumpToPage(currentPage);
                                _showScrollLimitDialog();
                                return true;
                              }
                              return false;
                            }

                            return false;
                          },
                          child: PageView.builder(
                            controller: _verticalPageController,
                            scrollDirection: Axis.vertical,
                            physics: _isProcessing
                                ? const NeverScrollableScrollPhysics()
                                : const PageScrollPhysics(),
                            itemCount: currentList.length,
                            onPageChanged: (newPage) {
                              final isPremium = Provider.of<AuthProvider>(
                                          context,
                                          listen: false)
                                      .user
                                      ?.isPremium ==
                                  true;

                              if (_isScrollLimitReached &&
                                  newPage > previousPageIndex) {
                                _verticalPageController
                                    .jumpToPage(previousPageIndex);
                                _showScrollLimitDialog();
                                return;
                              }

                              if (!(newPage > previousPageIndex &&
                                  _isScrollLimitReached)) {
                                _resetScrollLimitDialogFlag();
                              }

                              if (!isPremium && newPage < previousPageIndex) {
                                _verticalPageController
                                    .jumpToPage(previousPageIndex);
                                _showPremiumDialog(
                                  tr("premium_function"),
                                  tr("upgrade_to_premium_message"),
                                );
                                return;
                              }

                              _updateScrollCount();

                              setState(() {
                                previousPageIndex = newPage;
                                _currentPageIndex = newPage;
                              });

                              final nextIndex = newPage + 1;
                              if (nextIndex < currentList.length) {
                                _preloadImagesForUser(currentList[nextIndex]);
                              }

                              if (showRandom &&
                                  !_isFetchingMore &&
                                  newPage >= _randomUsers.length - 2) {
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
                        icon: const Icon(Icons.warning, color: Colors.white),
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
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (_savedRandomPosition <
                                        _randomUsers.length) {
                                      _verticalPageController
                                          .jumpToPage(_savedRandomPosition);
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
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20),
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
                                final auth = Provider.of<AuthProvider>(context,
                                    listen: false);
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
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
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
                                  initialRelationshipType:
                                      _currentRelationshipType,
                                  initialUseLocation: _currentUseLocation,
                                  initialDistanceRange: _currentDistanceRange,
                                  initialFilterByBasics: _currentFilterByBasics,
                                  initialSquatRange: _currentSquatRange,
                                  initialBenchRange: _currentBenchRange,
                                  initialDeadliftRange: _currentDeadliftRange,
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
                                _currentWeightRange =
                                    const RangeValues(50, 100);
                                _currentHeightRange =
                                    const RangeValues(150, 200);
                                _currentGymStage = 'Todos';
                                _currentRelationshipType = 'Todos';
                                _currentUseLocation = false;
                                _currentDistanceRange =
                                    const RangeValues(5, 50);
                                _currentFilterByBasics = false;
                                _currentSquatRange = const RangeValues(0, 300);
                                _currentBenchRange = const RangeValues(0, 200);
                                _currentDeadliftRange =
                                    const RangeValues(0, 400);

                                // Limpiar los filtros activos cuando se quitan filtros
                                _activeFilters = {};
                              });

                              var allUsers =
                                  await _fetchAllUsersWithoutFilter();
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
                              List<User> matches =
                                  List<User>.from(result['matches']);
                              setState(() {
                                // Guardar los valores del filtro actual
                                print('Filtros aplicados:');
                                print(
                                    'Etapa de Gimnasio: ${result['gymStage']}');
                                print(
                                    'Tipo de Relación: ${result['relationshipType']}');
                                print('Usuarios recibidos: ${matches.length}');

                                _currentAgeRange = result['ageRange'];
                                _currentWeightRange = result['weightRange'];
                                _currentHeightRange = result['heightRange'];
                                _currentGymStage = result['gymStage'];
                                _currentRelationshipType =
                                    result['relationshipType'];
                                _currentUseLocation = result['useLocation'];
                                _currentDistanceRange = result['distanceRange'];
                                _currentFilterByBasics =
                                    result['filterByBasics'] as bool;
                                _currentSquatRange =
                                    result['squatRange'] as RangeValues;
                                _currentBenchRange =
                                    result['benchRange'] as RangeValues;
                                _currentDeadliftRange =
                                    result['deadliftRange'] as RangeValues;

                                // Guardar los filtros activos en el mapa para usarlos en paginación
                                _activeFilters = {
                                  'ageMin':
                                      _currentAgeRange.start.round().toString(),
                                  'ageMax':
                                      _currentAgeRange.end.round().toString(),
                                  'weightMin': _currentWeightRange.start
                                      .round()
                                      .toString(),
                                  'weightMax': _currentWeightRange.end
                                      .round()
                                      .toString(),
                                  'heightMin': _currentHeightRange.start
                                      .round()
                                      .toString(),
                                  'heightMax': _currentHeightRange.end
                                      .round()
                                      .toString(),
                                };

                                // Añadir gymStage si no es "Todos"
                                if (_currentGymStage != 'Todos') {
                                  _activeFilters['gymStage'] = _currentGymStage;
                                }

                                // Añadir relationshipType si no es "Todos"
                                if (_currentRelationshipType != 'Todos') {
                                  _activeFilters['relationshipType'] =
                                      _currentRelationshipType;
                                }

                                // Añadir filtros de localización si están activos
                                if (_currentUseLocation) {
                                  _activeFilters['useLocation'] = 'true';
                                  _activeFilters['distanceMin'] =
                                      _currentDistanceRange.start
                                          .round()
                                          .toString();
                                  _activeFilters['distanceMax'] =
                                      _currentDistanceRange.end
                                          .round()
                                          .toString();
                                }

                                // Añadir filtros de básicos si están activos
                                if (_currentFilterByBasics) {
                                  _activeFilters['filterByBasics'] = 'true';
                                  _activeFilters['squatMin'] =
                                      _currentSquatRange.start
                                          .round()
                                          .toString();
                                  _activeFilters['squatMax'] =
                                      _currentSquatRange.end.round().toString();
                                  _activeFilters['benchMin'] =
                                      _currentBenchRange.start
                                          .round()
                                          .toString();
                                  _activeFilters['benchMax'] =
                                      _currentBenchRange.end.round().toString();
                                  _activeFilters['deadliftMin'] =
                                      _currentDeadliftRange.start
                                          .round()
                                          .toString();
                                  _activeFilters['deadliftMax'] =
                                      _currentDeadliftRange.end
                                          .round()
                                          .toString();
                                }
                                _randomUsers = matches;
                                // Si hay filtros activos, NO hacer shuffle para mantener el orden de relevancia
                                if (_randomUsers.isNotEmpty &&
                                    _activeFilters.isEmpty) {
                                  _randomUsers.shuffle();
                                }
                                showRandom = true;
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.tune, color: Colors.white),
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

  // Estos son los NUEVOS campos:
  final bool initialFilterByBasics;
  final RangeValues initialSquatRange;
  final RangeValues initialBenchRange;
  final RangeValues initialDeadliftRange;

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

    // Y aquí los incoporamos al constructor:
    required this.initialFilterByBasics,
    this.initialSquatRange = const RangeValues(0, 300),
    this.initialBenchRange = const RangeValues(0, 200),
    this.initialDeadliftRange = const RangeValues(0, 400),
  }) : super(key: key);

  @override
  _FilterModalContentState createState() => _FilterModalContentState();
}

class _FilterModalContentState extends State<FilterModalContent> {
  // Rangos principales (ya los tienes)
  late RangeValues ageRange;
  late RangeValues weightRange;
  late RangeValues heightRange;
  late String selectedGymStage;
  late String selectedRelationshipType;
  bool useLocation = false;
  late RangeValues distanceRange;

  // Parámetros de "filtrar por básicos"
  late bool filterByBasics;
  late RangeValues squatRange;
  late RangeValues benchRange;
  late RangeValues deadliftRange;

  // Límites máximos para sliders de básicos
  static const double _maxSquat = 300;
  static const double _maxBench = 200;
  static const double _maxDeadlift = 400;

  @override
  void initState() {
    super.initState();

    // Inicializamos con los valores recibidos desde el padre
    ageRange = widget.initialAgeRange;
    weightRange = widget.initialWeightRange;
    heightRange = widget.initialHeightRange;
    selectedGymStage = widget.initialGymStage;
    selectedRelationshipType = widget.initialRelationshipType;
    useLocation = widget.initialUseLocation;
    distanceRange = widget.initialDistanceRange;

    // ¡Aquí el cambio clave!
    filterByBasics = widget.initialFilterByBasics;
    squatRange = widget.initialSquatRange;
    benchRange = widget.initialBenchRange;
    deadliftRange = widget.initialDeadliftRange;
  }

  @override
  Widget build(BuildContext context) {
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
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRangeSlider(
              label: tr("age_range"),
              values: ageRange,
              min: 18,
              max: 100,
              divisions: 82,
              onChanged: (v) => setState(() => ageRange = v),
            ),

            _buildRangeSlider(
              label: tr("weight_range"),
              values: weightRange,
              min: 40,
              max: 120,
              divisions: 80,
              onChanged: (v) => setState(() => weightRange = v),
            ),

            _buildRangeSlider(
              label: tr("height_range"),
              values: heightRange,
              min: 100,
              max: 250,
              divisions: 150,
              onChanged: (v) => setState(() => heightRange = v),
            ),

            const SizedBox(height: 10),

            _buildDropdown(
              label: tr("gym_stage_filter"),
              value: selectedGymStage,
              items: gymStageMap,
              onChanged: (v) => setState(() => selectedGymStage = v!),
            ),

            _buildDropdown(
              label: tr("relationship_type_filter"),
              value: selectedRelationshipType,
              items: relationshipTypeMap,
              onChanged: (v) => setState(() => selectedRelationshipType = v!),
            ),

            const SizedBox(height: 20),

            if (widget.hasLocation) ...[
              SwitchListTile(
                title: Text(tr("filter_by_location"),
                    style: TextStyle(color: Colors.white)),
                value: useLocation,
                activeColor: Colors.blueAccent,
                onChanged: (v) => setState(() => useLocation = v),
              ),
              if (useLocation)
                _buildRangeSlider(
                  label: tr("distance_km"),
                  values: distanceRange,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (v) => setState(() => distanceRange = v),
                ),
            ],

            const SizedBox(height: 20),
            // Switch: filtrar por básicos
            SwitchListTile(
              title: Text(tr("filter_by_basics"),
                  style: const TextStyle(color: Colors.white)),
              value: filterByBasics,
              activeColor: Colors.blueAccent,
              onChanged: (v) => setState(() => filterByBasics = v),
            ),

            // Si está activo, mostramos sliders de básicos con sus valores guardados
            if (filterByBasics) ...[
              _buildRangeSlider(
                label: tr("squat_kg"),
                values: squatRange,
                min: 0,
                max: _maxSquat,
                divisions: (_maxSquat ~/ 5),
                onChanged: (v) => setState(() => squatRange = v),
              ),
              _buildRangeSlider(
                label: tr("bench_press_kg"),
                values: benchRange,
                min: 0,
                max: _maxBench,
                divisions: (100),
                onChanged: (v) => setState(() => benchRange = v),
              ),
              _buildRangeSlider(
                label: tr("deadlift_kg"),
                values: deadliftRange,
                min: 0,
                max: _maxDeadlift,
                divisions: (_maxDeadlift ~/ 5),
                onChanged: (v) => setState(() => deadliftRange = v),
              ),
            ],

            const SizedBox(height: 20),

            // Botón "Aplicar"
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () async {
                // Construimos el mapa de filtros
                final filters = <String, String>{
                  'ageMin': ageRange.start.round().toString(),
                  'ageMax': ageRange.end.round().toString(),
                  'weightMin': weightRange.start.round().toString(),
                  'weightMax': weightRange.end.round().toString(),
                  'heightMin': heightRange.start.round().toString(),
                  'heightMax': heightRange.end.round().toString(),
                  'gymStage': selectedGymStage,
                  'relationshipGoal': selectedRelationshipType,
                  'useLocation': useLocation.toString(),
                };
                if (useLocation) {
                  filters['distanceMin'] =
                      distanceRange.start.round().toString();
                  filters['distanceMax'] = distanceRange.end.round().toString();
                }

                // Sólo añadimos básicos si el usuario realmente movió el slider
                if (filterByBasics) {
                  if (squatRange.start > 0 || squatRange.end < _maxSquat) {
                    filters['squatMin'] = squatRange.start.round().toString();
                    filters['squatMax'] = squatRange.end.round().toString();
                  }
                  if (benchRange.start > 0 || benchRange.end < _maxBench) {
                    filters['benchMin'] = benchRange.start.round().toString();
                    filters['benchMax'] = benchRange.end.round().toString();
                  }
                  if (deadliftRange.start > 0 ||
                      deadliftRange.end < _maxDeadlift) {
                    filters['deadliftMin'] =
                        deadliftRange.start.round().toString();
                    filters['deadliftMax'] =
                        deadliftRange.end.round().toString();
                  }
                }

                // Llamada al backend
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final token = await auth.getToken();
                if (token != null) {
                  final matchService = MatchService(token: token);
                  final result = await matchService
                      .getSuggestedMatchesWithFilters(filters);
                  if (result['success'] == true) {
                    List<User> matches = (result['matches'] as List)
                        .map((j) => User.fromJson(j))
                        .toList();
                    Navigator.of(context).pop({
                      'matches': matches,
                      'ageRange': ageRange,
                      'weightRange': weightRange,
                      'heightRange': heightRange,
                      'gymStage': selectedGymStage,
                      'relationshipType': selectedRelationshipType,
                      'useLocation': useLocation,
                      'distanceRange': distanceRange,
                      'filterByBasics': filterByBasics,
                      'squatRange': squatRange,
                      'benchRange': benchRange,
                      'deadliftRange': deadliftRange,
                    });
                    return;
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(result['message'] ??
                              tr("error_fetching_more_users"))),
                    );
                  }
                }

                Navigator.of(context).pop();
              },
              child: Text(tr("apply"),
                  style: const TextStyle(color: Colors.black)),
            ),

            const SizedBox(height: 10),

            // Botón "Quitar filtros"
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => Navigator.of(context).pop({'remove': true}),
              child: Text(tr("remove_filter"),
                  style: const TextStyle(color: Colors.white)),
            ),

            const SizedBox(height: 20),
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
            values.start.round().toString(),
            values.end.round().toString(),
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
    required Map<String, String> items,
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
              color: Colors.white24, borderRadius: BorderRadius.circular(10)),
          child: DropdownButton<String>(
            value: value,
            dropdownColor: Colors.grey[850],
            style: const TextStyle(color: Colors.white),
            isExpanded: true,
            underline: const SizedBox(),
            items: items.entries
                .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
