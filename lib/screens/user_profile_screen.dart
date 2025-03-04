import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'photo_gallery_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool isLoading = true;
  String errorMessage = '';
  User? user;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("block_user")),
        content: Text(tr("block_user_confirm")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr("cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr("block")),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("auth_error"))),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    final userService = UserService(token: token);
    final result = await userService.blockUser(widget.userId);

    setState(() {
      isLoading = false;
    });

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? tr("user_blocked"))),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? tr("error_blocking_user"))),
      );
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = tr("token_not_found_auth");
        });
        return;
      }

      final url = Uri.parse(
          'https://gymder-api-production.up.railway.app/api/users/profile/${widget.userId}');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['user'] != null) {
          setState(() {
            user = User.fromJson(data['user']);
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = tr("user_not_found");
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = tr("error_fetching_user_data");
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      subtitle: Text(content, style: const TextStyle(color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr("user_profile"),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.block, color: Colors.white),
            tooltip: tr("block_user"),
            onPressed: _blockUser,
          )
        ],
      ),
      backgroundColor: Colors.grey[900],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              : user == null
                  ? Center(child: Text(tr("user_not_found")))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Foto de perfil
                          CircleAvatar(
                            radius: 70,
                            backgroundColor: Colors.white,
                            backgroundImage: user!.profilePicture != null
                                ? CachedNetworkImageProvider(
                                    user!.profilePicture!.url)
                                : const AssetImage(
                                        'assets/images/default_profile.png')
                                    as ImageProvider,
                          ),
                          const SizedBox(height: 16),
                          // Nombre del usuario
                          Text(
                            user!.username ?? '',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          // Biografía
                          if (user!.biography != null &&
                              user!.biography!.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                user!.biography!,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 8),
                          // Información adicional en tarjeta
                          Card(
                            color: Colors.grey[850],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildInfoTile(
                                  icon: Icons.flag,
                                  title: tr("goal_title"),
                                  content: user!.goal ?? tr("not_specified"),
                                ),
                                const Divider(
                                    color: Colors.white24,
                                    indent: 16,
                                    endIndent: 16),
                                _buildInfoTile(
                                  icon: Icons.wc,
                                  title: tr("gender_display"),
                                  content: user!.gender ?? tr("not_specified"),
                                ),
                                const Divider(
                                    color: Colors.white24,
                                    indent: 16,
                                    endIndent: 16),
                                _buildInfoTile(
                                  icon: Icons.favorite,
                                  title: tr("relationship_goal"),
                                  content: user!.relationshipGoal ??
                                      tr("not_specified"),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
