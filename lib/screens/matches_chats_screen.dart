// lib/screens/matches_chats_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../models/user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import './chat_screen.dart';

class MatchesChatsScreen extends StatefulWidget {
  const MatchesChatsScreen({Key? key}) : super(key: key);

  @override
  State<MatchesChatsScreen> createState() => _MatchesChatsScreenState();
}

class _MatchesChatsScreenState extends State<MatchesChatsScreen> {
  bool isLoading = true;
  String errorMessage = '';
  List<User> myMatches = [];
  List<User> allMyMatches = []; // To store all matches, with or without messages

  String? currentUserId;
  Map<String, Map<String, dynamic>> lastMessages = {};

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchMyMatches();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarga al volver al foco
    _fetchMyMatches();
  }

  Future<void> _fetchMyMatches() async {
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
      final userService = UserService(token: token);

      // 1) Traer todos los matches
      final allMatchesResult = await userService.getMatches(page: 0, limit: 1000);
      if (allMatchesResult['success'] != true) {
        setState(() {
          errorMessage = allMatchesResult['message'] ?? tr("error_fetching_matches");
          isLoading = false;
        });
        return;
      }
      final fullMatchesList = List<User>.from(
        allMatchesResult['matches'].map((x) => User.fromJson(x)),
      );

      // 2) Traer los últimos mensajes Y los IDs de matches visibles
      final messagesData = await _fetchAllLastMessages(token, fullMatchesList);
      final Map<String, Map<String, dynamic>> lastMsgMap = messagesData['lastMsgMap'];
      final List<String> visibleMatchUserIds = messagesData['visibleMatchUserIds'];

      // 3) Filtrar fullMatchesList para obtener solo los matches visibles
      List<User> visibleMatches = fullMatchesList.where((user) {
        return visibleMatchUserIds.contains(user.id);
      }).toList();

      // 4) Ordenar visibleMatches:
      //    - Primero, los que tienen mensajes, por fecha de último mensaje descendente.
      //    - Luego, los que no tienen mensajes, quizás por nombre o fecha de match (si disponible).
      visibleMatches.sort((a, b) {
        final msgA = lastMsgMap[a.id];
        final msgB = lastMsgMap[b.id];
        if (msgA == null && msgB == null) return 0;
        if (msgA == null) return 1;
        if (msgB == null) return -1;
        final dateA = DateTime.tryParse(msgA['createdAt']?.toString() ?? '');
        final dateB = DateTime.tryParse(msgB['createdAt']?.toString() ?? '');

        final bool hasMsgA = msgA != null;
        final bool hasMsgB = msgB != null;

        if (hasMsgA && hasMsgB) {
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1; // B primero
          if (dateB == null) return -1; // A primero
          return dateB.compareTo(dateA); // Más reciente primero
        } else if (hasMsgA) {
          return -1; // A (con mensaje) antes que B (sin mensaje)
        } else if (hasMsgB) {
          return 1; // B (con mensaje) antes que A (sin mensaje)
        } else {
          // Ambos sin mensajes. Ordenar por username como fallback.
          return a.username.compareTo(b.username);
        }
      });

      setState(() {
        myMatches = visibleMatches; // Usar la lista filtrada y ordenada
        lastMessages = lastMsgMap; // Esto sigue siendo útil para mostrar el contenido del último mensaje
        isLoading = false;
        errorMessage = ''; // Limpiar errores previos
      });
    } catch (e) {
      setState(() {
        errorMessage = tr("unexpected_error") + ": $e";
        isLoading = false;
      });
    }
  }

  bool _isMessageUnread(Map<String, dynamic>? lastMsg) {
    if (lastMsg == null) return false;
    final isSentByOther = lastMsg['sender'].toString() != currentUserId;
    final seenAt = lastMsg['seenAt'];
    return isSentByOther && seenAt == null;
  }

  Future<Map<String, dynamic>> _fetchAllLastMessages(
      String token, List<User> matches) async {
    final url = Uri.parse(
        'https://gymder-api-production.up.railway.app/api/messages/lastConversations');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });

    final Map<String, Map<String, dynamic>> lastMsgMap = {};
    List<String> visibleMatchUserIds = [];

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        for (var item in data['lastMessages'] as List) {
          final matchId = item['_id']?.toString(); // Ensure it's a string
          if (matchId != null) {
             final lastMsg = item['lastMsg'];
             lastMsgMap[matchId] = Map<String, dynamic>.from(lastMsg);
          }
        }
        if (data['visibleMatchUserIds'] != null) {
          visibleMatchUserIds = List<String>.from(data['visibleMatchUserIds'].map((id) => id.toString()));
        }
      }
    } else {
      print('Error al obtener últimos mensajes: ${response.statusCode}');
    }
    return {'lastMsgMap': lastMsgMap, 'visibleMatchUserIds': visibleMatchUserIds};
  }

  Future<void> _hideConversation(String otherUserId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;

      final url = Uri.parse(
          'https://gymder-api-production.up.railway.app/api/messages/conversation/hide');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'otherUserId': otherUserId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            myMatches.removeWhere((u) => u.id == otherUserId);
            lastMessages.remove(otherUserId);
          });
        } else {
          print(tr("cannot_hide_conversation") + ": ${data['message']}");
        }
      } else {
        print(tr("error_hiding_conversation") +
            ": ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      print(tr("error_hiding_conversation") + ": $e");
    }
  }

  void _showDeleteDialog(User matchedUser) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                tr("delete_conversation"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr("delete_conversation_message", args: [matchedUser.username]),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      child: Text(tr("cancel"),
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _hideConversation(matchedUser.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: Text(tr("delete"),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    strokeWidth: 3,
                    backgroundColor: Color(0xFF303030),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr("loading_chats"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.redAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : myMatches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white54,
                            size: 80,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr("no_matches_yet"),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 82.0, left: 16.0, right: 16.0, bottom: 6.0),
                          child: Text(
                            tr("messages"),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SafeArea(
                            top: false,
                            bottom: true,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              itemCount: myMatches.length,
                              itemBuilder: (context, index) {
                                final matchedUser = myMatches[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Card(
                                    color: Colors.grey[850],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    elevation: 4,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      onLongPress: () =>
                                          _showDeleteDialog(matchedUser),
                                      leading: CircleAvatar(
                                        radius: 30,
                                        backgroundImage: (matchedUser
                                                        .profilePicture !=
                                                    null &&
                                                matchedUser.profilePicture!.url
                                                    .isNotEmpty)
                                            ? CachedNetworkImageProvider(
                                                matchedUser.profilePicture!.url)
                                            : null,
                                        child: (matchedUser.profilePicture ==
                                                    null ||
                                                matchedUser.profilePicture!.url
                                                    .isEmpty)
                                            ? const Icon(Icons.person, size: 30)
                                            : null,
                                      ),
                                      title: Row(
                                        children: [
                                          Text(
                                            matchedUser.username,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          // Logo de verificación
                                          if (matchedUser.verificationStatus == 'true')
                                            Padding(
                                              padding: const EdgeInsets.only(left: 6.0),
                                              child: Transform.rotate(
                                                angle: 3.14159 / 1000,
                                                child: Image.asset(
                                                  'assets/images/verificado.png',
                                                  width: 18,
                                                  height: 18,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          if (_isMessageUnread(
                                              lastMessages[matchedUser.id]))
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  left: 8),
                                              width: 12,
                                              height: 12,
                                              decoration: const BoxDecoration(
                                                color: Colors.blue,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        () {
                                          final lastMsg =
                                              lastMessages[matchedUser.id];
                                          if (lastMsg != null) {
                                            if (lastMsg['type'] == 'image') {
                                              return "🖼️ " + tr("image");
                                            } else {
                                              return lastMsg['message'] ??
                                                  tr("tap_to_chat");
                                            }
                                          }
                                          return tr("tap_to_chat");
                                        }(),
                                        style: TextStyle(
                                          color: _isMessageUnread(
                                                  lastMessages[matchedUser.id])
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 16,
                                          fontWeight: _isMessageUnread(
                                                  lastMessages[matchedUser.id])
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      onTap: () {
                                        final authProvider =
                                            Provider.of<AuthProvider>(context,
                                                listen: false);
                                        final currentUserId =
                                            authProvider.user!.id;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChatScreen(
                                              currentUserId: currentUserId,
                                              matchedUserId: matchedUser.id,
                                            ),
                                          ),
                                        ).then((_) => _fetchMyMatches());
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
