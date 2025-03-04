import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../models/user.dart';
import 'chat_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';

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
      final result = await userService.getMatches();
      if (result['success']) {
        setState(() {
          myMatches = List<User>.from(
            result['matches'].map((x) => User.fromJson(x)),
          );
          isLoading = false;
        });

        final lastMsgMap = await _fetchAllLastMessages(token, myMatches);
        setState(() {
          lastMessages = lastMsgMap;
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
        print('Last Messages: $map');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(20, 20, 20, 0.0),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    errorMessage,
                    style:
                        const TextStyle(fontSize: 18, color: Colors.redAccent),
                  ),
                )
              : myMatches.isEmpty
                  ? Center(
                      child: Text(
                        tr("no_matches_yet"),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 82.0, left: 16.0, right: 16.0, bottom: 1.0),
                          child: Text(
                            tr("messages"),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: () {
                            // Ordenar matches por el timestamp del último mensaje
                            final sortedMatches = List<User>.from(myMatches);
                            sortedMatches.sort((a, b) {
                              final msgA = lastMessages[a.id];
                              final msgB = lastMessages[b.id];

                              if (msgA == null && msgB == null) return 0;
                              if (msgA == null) return 1;
                              if (msgB == null) return -1;

                              final dateA = DateTime.tryParse(
                                  msgA['createdAt']?.toString() ?? '');
                              final dateB = DateTime.tryParse(
                                  msgB['createdAt']?.toString() ?? '');

                              if (dateA == null && dateB == null) return 0;
                              if (dateA == null) return 1;
                              if (dateB == null) return -1;

                              return dateB.compareTo(dateA);
                            });

                            return ListView.builder(
                              itemCount: sortedMatches.length,
                              itemBuilder: (context, index) {
                                final matchedUser = sortedMatches[index];
                                return GestureDetector(
                                  onLongPress: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(tr("delete_conversation")),
                                        content: Text(tr(
                                            "delete_conversation_message",
                                            args: [matchedUser.username])),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(),
                                            child: Text(tr("cancel")),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(ctx).pop();
                                              _hideConversation(matchedUser.id);
                                            },
                                            child: Text(tr("delete")),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Card(
                                      color: Colors.grey[850],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      elevation: 4,
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.all(16),
                                        leading: CircleAvatar(
                                          radius: 30,
                                          backgroundImage:
                                              (matchedUser.profilePicture !=
                                                          null &&
                                                      matchedUser
                                                          .profilePicture!
                                                          .url
                                                          .isNotEmpty)
                                                  ? NetworkImage(matchedUser
                                                      .profilePicture!.url)
                                                  : null,
                                          child: (matchedUser.profilePicture ==
                                                      null ||
                                                  matchedUser.profilePicture!
                                                      .url.isEmpty)
                                              ? const Icon(Icons.person,
                                                  size: 30)
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
                                  ),
                                );
                              },
                            );
                          }(),
                        ),
                      ],
                    ),
    );
  }
}
