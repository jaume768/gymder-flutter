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

  Future<void> _fetchUserProfile() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        setState(() {
          errorMessage = tr("token_not_found_auth");
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse(
        'https://gymder-api-production.up.railway.app/api/users/profile/${widget.userId}',
      );
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

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

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr("block_user"),
            style: const TextStyle(color: Colors.white)),
        content: Text(tr("block_user_confirm"),
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr("cancel"),
                style: const TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr("block"),
                style: const TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("auth_error"))),
      );
      setState(() => isLoading = false);
      return;
    }

    final userService = UserService(token: token);
    final result = await userService.blockUser(widget.userId);
    setState(() => isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] ?? tr("error_blocking_user"))),
    );
    if (result['success'] == true) Navigator.pop(context);
  }

  Widget _buildInfoBox({
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(8),
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(20, 20, 20, 0.0),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr("user_profile"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.block, color: Colors.white),
            tooltip: tr("block_user"),
            onPressed: _blockUser,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
          ? Center(
        child: Text(
          errorMessage,
          style: const TextStyle(color: Colors.redAccent),
        ),
      )
          : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    // Preparo el contenido de "Básicos"
    final basicsContent = [
      "${tr('squat')}: ${user!.squatWeight != null ? '${user!.squatWeight} kg' : tr('not_defined')}",
      "${tr('bench_press')}: ${user!.benchPressWeight != null ? '${user!.benchPressWeight} kg' : tr('not_defined')}",
      "${tr('deadlift')}: ${user!.deadliftWeight != null ? '${user!.deadliftWeight} kg' : tr('not_defined')}",
    ].join('\n');

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // ─── Foto de perfil ────────────────────────────────
          Center(
            child: CircleAvatar(
              radius: 70,
              backgroundColor: Colors.white,
              backgroundImage: user!.profilePicture != null
                  ? CachedNetworkImageProvider(user!.profilePicture!.url)
                  : const AssetImage('assets/images/default_profile.png')
              as ImageProvider,
            ),
          ),

          const SizedBox(height: 16),
          // ─── Nombre de usuario ─────────────────────────────
          Text(
            user!.username ?? '',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          // ─── Biografía ─────────────────────────────────────
          if (user!.biography != null && user!.biography!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                user!.biography!,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 16),
          // ─── Pestañas SOBRE MI / FOTOS ──────────────────────
          TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: tr('about_me')),
              Tab(text: tr('photos_profile')),
            ],
          ),

          // ─── Contenido de cada pestaña ────────────────────────
          Expanded(
            child: TabBarView(
              children: [
                // ────────── PESTAÑA SOBRE MI ─────────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila: Género | Objetivo
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoBox(
                              title: tr('gender_display'),
                              content: user!.gender ?? tr("not_specified"),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoBox(
                              title: tr('goal_title'),
                              content: user!.goal ?? tr("not_specified"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Caja ancho completo
                      _buildInfoBox(
                        title: tr('what_are_you_looking_for'),
                        content: user!.relationshipGoal ?? tr("not_specified"),
                      ),

                      // Ubicación
                      _buildInfoBox(
                        title: tr('location'),
                        content: (user!.city?.isNotEmpty ?? false)
                            ? '${user!.city}, ${user!.country}'
                            : tr("location_not_defined"),
                      ),

                      // Básicos
                      _buildInfoBox(
                        title: tr("basic_lifts_profile"),
                        content: basicsContent,
                      ),
                    ],
                  ),
                ),

                // ────────── PESTAÑA FOTOS ─────────────────
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: user!.photos != null && user!.photos!.isNotEmpty
                      ? GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: user!.photos!.length,
                    itemBuilder: (context, index) {
                      final photo = user!.photos![index];
                      return GestureDetector(
                        onTap: () {
                          final urls = user!.photos!
                              .map((p) => p.url)
                              .toList();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PhotoGalleryScreen(
                                imageUrls: urls,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: CachedNetworkImage(
                          imageUrl: photo.url,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) =>
                              Container(color: Colors.grey[800]),
                          errorWidget: (ctx, url, err) =>
                          const Icon(Icons.error,
                              color: Colors.white),
                        ),
                      );
                    },
                  )
                      : Center(
                    child: Text(
                      tr('no_photos'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
