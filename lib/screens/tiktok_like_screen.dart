import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gymder/screens/premium_purchase_page.dart';
import 'package:gymder/screens/single_user_view.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
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

class _TikTokLikeScreenState extends State<TikTokLikeScreen> {
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

  @override
  void initState() {
    super.initState();
    _verticalPageController = PageController();
    _randomUsers = List.from(widget.users);
    previousPageIndex = 0;
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error al obtener likes')),
      );
    }
  }

  Future<void> _handleLike(int userIndex) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final user = _randomUsers[userIndex];
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

    setState(() {
      _randomUsers.removeAt(userIndex);
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

    final authProviderForLike =
    Provider.of<AuthProvider>(context, listen: false);
    if (!(authProviderForLike.user?.isPremium ?? false)) {
      int localMaxScroll =
      (authProviderForLike.user?.gender == 'Masculino') ? 40 : 75;
      int localMaxLike =
      (authProviderForLike.user?.gender == 'Masculino') ? 20 : 40;

      setState(() {
        scrollCount++;
        likeCount++;
      });

      _checkScrollLimit(localMaxScroll);
      _checkLikeLimit(localMaxLike);
    }
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

  @override
  Widget build(BuildContext context) {
    final currentList = showRandom ? _randomUsers : _likedUsers;

    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final int maxScrollLimit = (auth.user?.gender == 'Masculino') ? 25 : 45;

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
                          if (!auth.user!.isPremium &&
                              notification.direction ==
                                  ScrollDirection.forward) {
                            _showPremiumDialog(
                              "Función Premium",
                              "Para hacer scroll hacia arriba y volver al usuario anterior necesitas ser premium. ¿Deseas comprarlo?",
                            );
                          }
                          if (!auth.user!.isPremium &&
                              notification.direction ==
                                  ScrollDirection.reverse) {
                            _checkScrollLimit(maxScrollLimit);
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
                              onDoubleTapLike:
                                  showRandom ? () => _handleLike(index) : () {},
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
                      child: const Text('Random'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            !showRandom ? Colors.white : Colors.black45,
                        foregroundColor:
                            !showRandom ? Colors.black : Colors.white,
                        elevation: 0,
                      ),
                      onPressed: () {
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
                      child: const Text('Le gustas'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
