import 'package:flutter/material.dart';
import 'package:gymder/screens/tiktok_like_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import 'matches_chats_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

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
      });
    } else {
      setState(() {
        errorMessage = result['message'] ?? 'Error al obtener matches';
        isLoading = false;
      });
    }
  }

  final List<Widget> _widgetOptions = <Widget>[
    const MatchesChatsScreen(),  // Aquí en vez de ChatScreen directo
    const SizedBox.shrink(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
    // Puedes agregar lógica adicional para otros índices si es necesario.
  }

  @override
  Widget build(BuildContext context) {
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
          : _selectedIndex == 1
          ? (suggestedMatches.isEmpty
          ? const Center(
          child: Text(
            'No hay más matches disponibles.',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ))
          : TikTokLikeScreen(users: suggestedMatches))
          : _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono Chat
            GestureDetector(
              onTap: () => _onItemTapped(0),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: _selectedIndex == 0
                    ? Colors.white
                    : Colors.grey.shade700,
                child: Icon(
                  Icons.chat_bubble,
                  color: _selectedIndex == 0 ? Colors.black : Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 40),
            // Icono Matches (corazón) - central y más grande
            GestureDetector(
              onTap: () => _onItemTapped(1),
              child: CircleAvatar(
                radius: 34,
                backgroundColor: _selectedIndex == 1
                    ? Colors.white
                    : Colors.grey.shade700,
                child: Icon(
                  Icons.favorite,
                  color: _selectedIndex == 1 ? Colors.black : Colors.white,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(width: 40),
            // Icono Perfil
            GestureDetector(
              onTap: () => _onItemTapped(2),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: _selectedIndex == 2
                    ? Colors.white
                    : Colors.grey.shade700,
                child: Icon(
                  Icons.person,
                  color: _selectedIndex == 2 ? Colors.black : Colors.white,
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