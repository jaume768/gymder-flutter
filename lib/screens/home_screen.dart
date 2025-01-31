import 'package:app/screens/register_screen.dart';
import 'package:app/screens/tiktok_like_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'login_screen.dart';
import 'matches_chats_screen.dart';
import 'my_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
  // Para forzar refresco en Matches, usaremos un UniqueKey o recrearemos la pantalla
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
        // Instanciamos la pantalla de swipes:
        _tikTokLikeScreen = TikTokLikeScreen(users: suggestedMatches);
        // Instanciamos MatchesChatsScreen (con UniqueKey para refrescar si queremos):
        _matchesScreen = MatchesChatsScreen(key: UniqueKey());
      });
    } else {
      setState(() {
        errorMessage = result['message'] ?? 'Error al obtener matches';
        isLoading = false;
      });
    }
  }

  // Refrescar la pantalla de Matches cada vez que se hace tap en la opción 0
  void _onItemTapped(int index) {
    setState(() {
      if (index == 0) {
        // Recreamos la pantalla de Matches para que se ejecute initState y se refresque
        _matchesScreen = MatchesChatsScreen(key: UniqueKey());
      }
      _selectedIndex = index;
    });
  }

  // Solo dos pantallas en los tabs:
  List<Widget> _widgetOptions() {
    return [
      _matchesScreen, // index 0
      _tikTokLikeScreen, // index 1
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // Si el usuario está pendiente en gender o relationshipGoal, lo enviamos a completar registro
    if (user != null &&
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
      // Ahora el bottom nav solo tendrá 2 íconos: Chats y Swipes, y un 3er ícono que
      // NO cambia el tab, sino que hace push al perfil.
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Opción 0: Matches
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
            // Opción 1: Swipes (TikTokLikeScreen)
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
            // "Opción 2": Perfil -> Pero realmente hacemos un push
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
