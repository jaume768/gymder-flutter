// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:gymder/screens/tiktok_like_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import 'profile_swipe_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart'; // Crea este archivo si planeas implementarlo en el futuro

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<User> suggestedMatches = [];
  bool isLoading = true;
  String errorMessage = '';

  // Índice del botón seleccionado en la barra de navegación inferior
  int _selectedIndex = 1; // 0: Chat, 1: Corazón, 2: Perfil

  @override
  void initState() {
    super.initState();
    _fetchSuggestedMatches();
  }

  Future<void> _fetchSuggestedMatches() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken(); // Uso del método público

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
        suggestedMatches = List<User>.from(result['matches'].map((x) => User.fromJson(x)));
        isLoading = false;
      });
    } else {
      setState(() {
        errorMessage = result['message'] ?? 'Error al obtener matches';
        isLoading = false;
      });
    }
  }

  // Lista de widgets para cada pestaña
  final List<Widget> _widgetOptions = <Widget>[
    const ChatScreen(), // Implementa este widget cuando esté listo
    // ProfileSwipeScreen se manejará dinámicamente
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

    // Puedes agregar funcionalidades para otros botones aquí en el futuro
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gymder'),
        backgroundColor: const Color.fromRGBO(64, 65, 65, 1), // Fondo gris oscuro
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await authProvider.logoutUser();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
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
        ),
      )
          : TikTokLikeScreen(users: suggestedMatches))
          : _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color.fromRGBO(64, 65, 65, 1), // Fondo gris oscuro
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble, color: Colors.white),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite, color: Colors.white),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, color: Colors.white),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        onTap: _onItemTapped,
      ),
      backgroundColor: const Color.fromRGBO(64, 65, 65, 1), // Fondo gris oscuro
    );
  }
}
