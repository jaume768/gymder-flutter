import 'package:app/screens/premium_purchase_page.dart';
import 'package:app/screens/single_user_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/match_service.dart';
import '../services/user_service.dart';
import 'chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<User> _randomUsers = [];
  bool _isFetchingMore = false;
  final int _limit = 20;
  List<User> _likedUsers = [];

  int scrollCount = 0;
  int likeCount = 0;
  int previousPageIndex = 0;
  int _currentPageIndex = 0;
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

  // Para controlar perfiles ya enviados al backend (ya vistos)
  final Set<String> _seenProfileIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLimitsData();
    _verticalPageController = PageController(keepPage: true);
    _randomUsers = List.from(widget.users);
    _randomUsers.shuffle();
    previousPageIndex = 0;
    _fetchLikedUsers();

    // Programar un salto a la posición guardada después de que se construya la UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPageIndex > 0 && _currentPageIndex < _randomUsers.length) {
        _verticalPageController.jumpToPage(_currentPageIndex);
        previousPageIndex = _currentPageIndex;
      }
    });
  }

  // Método para cargar los datos de límites guardados
  Future<void> _loadLimitsData() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      scrollCount = prefs.getInt('scrollCount') ?? 0;
      likeCount = prefs.getInt('likeCount') ?? 0;
      _currentPageIndex = prefs.getInt('currentPageIndex') ?? 0;

      // Recuperar tiempos de límites alcanzados, si existen
      final scrollLimitTimeString = prefs.getString('scrollLimitReachedTime');
      final likeLimitTimeString = prefs.getString('likeLimitReachedTime');

      if (scrollLimitTimeString != null) {
        scrollLimitReachedTime = DateTime.parse(scrollLimitTimeString);
      }

      if (likeLimitTimeString != null) {
        likeLimitReachedTime = DateTime.parse(likeLimitTimeString);
      }
    });
  }

  // Método para guardar los datos de límites
  Future<void> _saveLimitsData() async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setInt('scrollCount', scrollCount);
    prefs.setInt('likeCount', likeCount);
    prefs.setInt('currentPageIndex', _currentPageIndex);

    if (scrollLimitReachedTime != null) {
      prefs.setString(
          'scrollLimitReachedTime', scrollLimitReachedTime!.toIso8601String());
    } else {
      prefs.remove('scrollLimitReachedTime');
    }

    if (likeLimitReachedTime != null) {
      prefs.setString(
          'likeLimitReachedTime', likeLimitReachedTime!.toIso8601String());
    } else {
      prefs.remove('likeLimitReachedTime');
    }
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
      print(tr("liked_users_count", args: [_likedUsers.length.toString()]));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? tr("error_getting_likes"))),
      );
    }
  }

  Future<void> _fetchMoreUsers() async {
    if (_isFetchingMore) return;
    setState(() {
      _isFetchingMore = true;
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) return;
    final matchService = MatchService(token: token);

    // Construir filtros para la paginación
    Map<String, String> filters = {};
    filters['skip'] = _randomUsers.length.toString();
    filters['limit'] = _limit.toString();

    final result = await matchService.getSuggestedMatchesWithFilters(filters);
    if (result['success'] == true) {
      List<dynamic> matchesJson = result['matches'];
      List<User> newUsers =
          matchesJson.map((json) => User.fromJson(json)).toList();

      // Filtrar usuarios que ya hayan sido liked
      newUsers = newUsers
          .where((user) => !_likedUsers.any((liked) => liked.id == user.id))
          .toList();

      setState(() {
        _randomUsers.addAll(newUsers);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(result['message'] ?? tr("error_fetching_more_users"))),
      );
    }
    setState(() {
      _isFetchingMore = false;
    });
  }

  // Llamada para actualizar en el backend el perfil "visto"
  Future<void> _updateSeenProfile(String userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) return;
    final matchService = MatchService(token: token);
    await matchService.updateSeenProfiles([userId]);
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
          tr("like_limit_reached"),
          tr("like_limit_message", args: [
            remaining.inHours.toString(),
            (remaining.inMinutes % 60).toString()
          ]),
        );
        return;
      } else {
        setState(() {
          likeCount = 0;
          likeLimitReachedTime = null;
        });
      }
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
      if (!userIsPremium) likeCount++;
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

    if (!userIsPremium) {
      _checkLikeLimit(localMaxLike);
      // Guardar el estado del contador de likes
      _saveLimitsData();
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

  void _checkScrollLimit(int maxScrollLimit) {
    if (scrollCount >= maxScrollLimit) {
      scrollLimitReachedTime ??= DateTime.now();
      Duration timePassed = DateTime.now().difference(scrollLimitReachedTime!);
      if (timePassed < limitDuration) {
        Duration remaining = limitDuration - timePassed;
        _showPremiumDialog(
          tr("premium_function"),
          tr("scroll_limit_message", args: [
            remaining.inHours.toString(),
            (remaining.inMinutes % 60).toString()
          ]),
        );
        // Guardamos el estado de límite alcanzado
        _saveLimitsData();
      } else {
        setState(() {
          scrollCount = 0;
          scrollLimitReachedTime = null;
        });
        // Actualizamos al eliminar el límite
        _saveLimitsData();
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
          tr("like_limit_reached"),
          tr("like_limit_message", args: [
            remaining.inHours.toString(),
            (remaining.inMinutes % 60).toString()
          ]),
        );
        // Guardamos el estado de límite alcanzado
        _saveLimitsData();
      } else {
        setState(() {
          likeCount = 0;
          likeLimitReachedTime = null;
        });
        // Actualizamos al eliminar el límite
        _saveLimitsData();
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
                tr("match_message", args: [matchedUser.username ?? ""]),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthProvider>(context);
    final int maxScrollLimit = (auth.user?.gender == 'Masculino') ? 25 : 45;
    final List<User> combinedUsers = List<User>.from(_randomUsers);
    for (var likedUser in _likedUsers) {
      if (!combinedUsers.any((user) => user.id == likedUser.id)) {
        combinedUsers.add(likedUser);
      }
    }
    final List<User> currentList = showRandom ? combinedUsers : _likedUsers;

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
                : NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.axis == Axis.vertical) {
                        if (!auth.user!.isPremium &&
                            notification.direction == ScrollDirection.forward) {
                          _showPremiumDialog(
                            tr("premium_function"),
                            tr("premium_scroll_message"),
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
                      key: ValueKey(showRandom),
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
                          if (scrollCount >= maxScrollLimit) {
                            _verticalPageController
                                .jumpToPage(previousPageIndex);
                            return;
                          } else {
                            setState(() {
                              scrollCount++;
                            });
                            _checkScrollLimit(maxScrollLimit);
                          }
                        }
                        previousPageIndex = pageIndex;

                        // Guardar la posición actual para mantenerla entre navegaciones
                        _currentPageIndex = pageIndex;
                        _saveLimitsData();

                        final viewedUser = currentList[pageIndex];
                        if (!_seenProfileIds.contains(viewedUser.id)) {
                          _seenProfileIds.add(viewedUser.id);
                          _updateSeenProfile(viewedUser.id);
                        }

                        // Si se acerca al final, cargar más usuarios
                        if (showRandom &&
                            pageIndex >= currentList.length - 10) {
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
                            setState(() {
                              showRandom = false;
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
                        var allUsers = await _fetchAllUsersWithoutFilter();
                        if (allUsers != null) {
                          setState(() {
                            _randomUsers = allUsers;
                            _randomUsers.shuffle();
                            showRandom = true;
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

class FilterModalContent extends StatefulWidget {
  final bool hasLocation;
  final RangeValues initialAgeRange;
  final RangeValues initialWeightRange;
  final RangeValues initialHeightRange;
  final String initialGymStage;
  final String initialRelationshipType;

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
              divisions: 110,
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
            _buildDropdown(
              label: tr("gym_stage_filter"),
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
              label: tr("relationship_type_filter"),
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
