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
  bool showRandom = true;
  late List<User> _randomUsers;
  List<User> _likedUsers = [];

  @override
  void initState() {
    super.initState();
    _verticalPageController = PageController();
    _randomUsers = List.from(widget.users);
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
  }

  @override
  Widget build(BuildContext context) {
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
                : PageView.builder(
                    controller: _verticalPageController,
                    scrollDirection: Axis.vertical,
                    itemCount: currentList.length,
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
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: showRandom ? Colors.white : Colors.black45,
                    foregroundColor: showRandom ? Colors.black : Colors.white,
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
                    foregroundColor: !showRandom ? Colors.black : Colors.white,
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() {
                      showRandom = false;
                    });
                    if (_likedUsers.isEmpty) {
                      _fetchLikedUsers();
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
  }
}
