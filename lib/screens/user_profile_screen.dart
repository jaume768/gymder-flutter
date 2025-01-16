// lib/screens/user_profile_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

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
        title: const Text('Bloquear usuario'),
        content:
            const Text('¿Estás seguro de que deseas bloquear a este usuario?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bloquear')),
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
          const SnackBar(content: Text('Error de autenticación')));
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
          SnackBar(content: Text(result['message'] ?? 'Usuario bloqueado')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Error al bloquear usuario')));
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'No se encontró token de autenticación.';
        });
        return;
      }

      final url =
          Uri.parse('https://gymder-api-production.up.railway.app/api/users/profile/${widget.userId}');
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
            errorMessage = 'Usuario no encontrado.';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Error al obtener datos del usuario.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Widget _buildInfoTile(
      {required IconData icon,
      required String title,
      required String content}) {
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
        title: const Text(
          'Perfil del Usuario',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[900],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Text(errorMessage,
                      style: const TextStyle(color: Colors.redAccent)))
              : user == null
                  ? const Center(child: Text('Usuario no encontrado.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
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
                          Text(
                            '${user!.firstName ?? ''} ${user!.lastName ?? ''}',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            color: Colors.grey[850],
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                _buildInfoTile(
                                  icon: Icons.flag,
                                  title: 'Objetivo',
                                  content: user!.goal ?? 'No especificado',
                                ),
                                const Divider(
                                    color: Colors.white24,
                                    indent: 16,
                                    endIndent: 16),
                                _buildInfoTile(
                                  icon: Icons.wc,
                                  title: 'Género',
                                  content: user!.gender ?? 'No especificado',
                                ),
                                const Divider(
                                    color: Colors.white24,
                                    indent: 16,
                                    endIndent: 16),
                                _buildInfoTile(
                                  icon: Icons.favorite,
                                  title: 'Objetivo de Relación',
                                  content: user!.relationshipGoal ??
                                      'No especificado',
                                ),
                              ],
                            ),
                          ),
                          if (user!.photos != null &&
                              user!.photos!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Fotografías:',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
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
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[800],
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error,
                                            color: Colors.white),
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _blockUser,
                            icon: const Icon(Icons.block, color: Colors.white),
                            label: const Text('Bloquear usuario',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
