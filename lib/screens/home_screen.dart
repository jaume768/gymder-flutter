// lib/screens/home_screen.dart

import 'package:app/screens/register_screen.dart';
import 'package:app/screens/tiktok_like_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'login_screen.dart';
import 'matches_chats_screen.dart';
import 'my_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool fromGoogle; // nuevo parámetro
  const HomeScreen({Key? key, this.fromGoogle = false}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<User> suggestedMatches = [];
  bool isLoading = true;
  String errorMessage = '';
  int _selectedIndex = 1;

  // Instanciamos nuestras pantallas:
  late TikTokLikeScreen _tikTokLikeScreen;
  late Widget _matchesScreen;

  @override
  void initState() {
    super.initState();
    _fetchSuggestedMatches();
  }

  Future<void> _fetchSuggestedMatches() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    if (token == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final userService = UserService(token: token);
    final result = await userService.getSuggestedMatches();

    if (result['success']) {
      setState(() {
        suggestedMatches =
            List<User>.from(result['matches'].map((x) => User.fromJson(x)));
        isLoading = false;
        _tikTokLikeScreen = TikTokLikeScreen(users: suggestedMatches);
        _matchesScreen = MatchesChatsScreen(key: UniqueKey());
      });
    } else {
      setState(() {
        errorMessage = result['message'] ?? tr("error_fetching_matches");
        isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      if (index == 0) {
        _matchesScreen = MatchesChatsScreen(key: UniqueKey());
      }
      _selectedIndex = index;
    });
  }

  List<Widget> _widgetOptions() {
    return [
      _matchesScreen,
      _tikTokLikeScreen,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (!widget.fromGoogle &&
        user != null &&
        (user.gender == 'Pendiente' || user.relationshipGoal == 'Pendiente')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const RegisterScreen(fromGoogle: true)),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : IndexedStack(
                  index: _selectedIndex,
                  children: _widgetOptions(),
                ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _onItemTapped(0),
              child: CircleAvatar(
                radius: 24,
                backgroundColor:
                    _selectedIndex == 0 ? Colors.white : Colors.grey.shade800,
                child: Icon(
                  Icons.chat_bubble,
                  color: _selectedIndex == 0 ? Colors.black : Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 40),
            GestureDetector(
              onTap: () => _onItemTapped(1),
              child: CircleAvatar(
                radius: 34,
                backgroundColor:
                    _selectedIndex == 1 ? Colors.white : Colors.grey.shade800,
                child: Icon(
                  Icons.favorite,
                  color: _selectedIndex == 1 ? Colors.black : Colors.white,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(width: 40),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade800,
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
