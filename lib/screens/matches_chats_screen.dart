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

  String? currentUserId;
  Map<String, Map<String, dynamic>> lastMessages = {};

  // Controlador de scroll (opcional)
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
      final result = await userService.getMatches(page: 0, limit: 1000);
      if (result['success']) {
        final matchesList = List<User>.from(
          result['matches'].map((x) => User.fromJson(x)),
        );
        final lastMsgMap = await _fetchAllLastMessages(token, matchesList);
        // Ordenar por último mensaje
        matchesList.sort((a, b) {
          final msgA = lastMsgMap[a.id];
          final msgB = lastMsgMap[b.id];
          if (msgA == null && msgB == null) return 0;
          if (msgA == null) return 1;
          if (msgB == null) return -1;
          final dateA = DateTime.tryParse(msgA['createdAt']?.toString() ?? '');
          final dateB = DateTime.tryParse(msgB['createdAt']?.toString() ?? '');
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });
        setState(() {
          myMatches = matchesList;
          lastMessages = lastMsgMap;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = result['message'] ?? tr("error_fetching_matches");
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = tr("unexpected_error") + ": $e";
        isLoading = false;
      });
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchAllLastMessages(
      String token, List<User> matches) async {
    final url = Uri.parse(
        'https://gymder-api-production.up.railway.app/api/messages/lastConversations');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });

    final Map<String, Map<String, dynamic>> map = {};

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final List<dynamic> lastMessages = data['lastMessages'];
        for (var item in lastMessages) {
          final matchId = item['_id'];
          final lastMsg = item['lastMsg'];
          map[matchId] = lastMsg;
        }
      }
    } else {
      print('Error en la respuesta: ${response.statusCode}');
    }
    return map;
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
            ": ${response.statusCode}\nBody: ${response.body}");
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
                              // añadimos padding bottom para que el último ítem siempre se vea
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
                                      title: Text(
                                        matchedUser.username,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
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
                                        ).then((_) {
                                          _fetchMyMatches();
                                        });
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
