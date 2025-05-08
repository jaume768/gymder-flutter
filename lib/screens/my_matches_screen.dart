import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'user_profile_screen.dart';
import 'chat_screen.dart';

class MyMatchesScreen extends StatefulWidget {
  const MyMatchesScreen({Key? key}) : super(key: key);

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen> {
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMoreMatches = true;
  String errorMessage = '';
  List<User> myMatches = [];
  String? currentUserId;
  int currentPage = 0;
  final int pageSize = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchMyMatches();
    
    // Añadir listener para detectar cuando el usuario llega al final de la lista
    _scrollController.addListener(_scrollListener);
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore && hasMoreMatches) {
      _loadMoreMatches();
    }
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyMatches() async {
    // Reiniciamos los valores de paginación
    currentPage = 0;
    myMatches = [];
    hasMoreMatches = true;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = tr("token_not_found_login");
        });
        return;
      }

      currentUserId = authProvider.user?.id;

      await _loadMoreMatches(); // Cargamos la primera página
    } catch (e) {
      setState(() {
        errorMessage = tr("unexpected_error") + ": $e";
        isLoading = false;
      });
    }
  }
  
  Future<void> _loadMoreMatches() async {
    if (isLoadingMore || !hasMoreMatches) return;
    
    setState(() {
      isLoadingMore = true;
      if (currentPage == 0) isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;
      
      final userService = UserService(token: token);
      final result = await userService.getMatches(page: currentPage, limit: pageSize);
      
      if (result['success']) {
        final newMatches = List<User>.from(
          result['matches'].map((x) => User.fromJson(x)),
        );
        
        // Obtenemos información de paginación
        final pagination = result['pagination'];
        final hasMore = pagination?['hasMore'] ?? false;
        
        setState(() {
          myMatches.addAll(newMatches);
          hasMoreMatches = hasMore;
          currentPage++;
          isLoading = false;
          isLoadingMore = false;
        });
      } else {
        setState(() {
          errorMessage = result['message'] ?? tr("error_fetching_matches");
          isLoading = false;
          isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = tr("unexpected_error") + ": $e";
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  // Verificar si existe una conversación con el usuario y abrirla, o crear una nueva
  Future<void> _openOrCreateChat(String matchedUserId) async {
    try {
      if (currentUserId == null) return;
      
      // Navegar directamente a la pantalla de chat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            currentUserId: currentUserId!,
            matchedUserId: matchedUserId,
          ),
        ),
      ).then((_) {
        // Actualizar lista de matches al volver
        _fetchMyMatches();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("error_opening_chat") + ": $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      appBar: AppBar(
        title: Text(tr("my_matches"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 18, color: Colors.redAccent),
                  ),
                )
              : myMatches.isEmpty
                  ? Center(
                      child: Text(
                        tr("no_matches_yet"),
                        style: const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: myMatches.length + (isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == myMatches.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        
                        final matchedUser = myMatches[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Card(
                            color: Colors.grey[850],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 4,
                            child: InkWell(
                              onTap: () {
                                // Navegar al perfil del usuario
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserProfileScreen(
                                      userId: matchedUser.id,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(15),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    // Foto de perfil
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.grey[800],
                                      backgroundImage:
                                          (matchedUser.profilePicture != null &&
                                                  matchedUser.profilePicture!.url
                                                      .isNotEmpty)
                                              ? CachedNetworkImageProvider(
                                                  matchedUser.profilePicture!.url)
                                              : null,
                                      child: (matchedUser.profilePicture == null ||
                                              matchedUser.profilePicture!.url.isEmpty)
                                          ? const Icon(Icons.person, size: 30, color: Colors.white70)
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    // Información del usuario
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            matchedUser.username ?? "Usuario",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (matchedUser.city?.isNotEmpty ?? false)
                                            Text(
                                              "${matchedUser.city}, ${matchedUser.country}",
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Botón para enviar mensaje
                                    ElevatedButton(
                                      onPressed: () => _openOrCreateChat(matchedUser.id),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: Text(tr("send_message")),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
