import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'edit_profile_screen.dart';
import 'home_screen.dart';
import 'photo_gallery_screen.dart';
import 'login_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({Key? key}) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<AuthProvider>(context, listen: false).refreshUser();
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
    final authProvider = Provider.of<AuthProvider>(context);
    final User? user = authProvider.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
        ),
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 0.0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Foto de perfil y botón de editar
            Stack(
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.white,
                  backgroundImage: user.profilePicture != null
                      ? CachedNetworkImageProvider(user.profilePicture!.url)
                      : const AssetImage('assets/images/default_profile.png')
                          as ImageProvider,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen()),
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child:
                          const Icon(Icons.edit, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Nombre de usuario
            Text(
              user.username ?? '',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            // Mostrar la biografía debajo del nombre (alineada a la izquierda)
            if (user.biography != null && user.biography!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  user.biography!,
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            Card(
              color: const Color.fromRGBO(38, 38, 38, 1.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.flag,
                    title: 'Objetivo',
                    content: user.goal ?? 'No especificado',
                  ),
                  const Divider(
                      color: Colors.white24, indent: 16, endIndent: 16),
                  _buildInfoTile(
                    icon: Icons.wc,
                    title: 'Género',
                    content: user.gender ?? 'No especificado',
                  ),
                  const Divider(
                      color: Colors.white24, indent: 16, endIndent: 16),
                  _buildInfoTile(
                    icon: Icons.favorite,
                    title: 'Objetivo de Relación',
                    content: user.relationshipGoal ?? 'No especificado',
                  ),
                  const Divider(
                      color: Colors.white24, indent: 16, endIndent: 16),
                  _buildInfoTile(
                    icon: Icons.location_on,
                    title: 'Ubicación',
                    content: (user.city != null && user.city!.isNotEmpty) ||
                            (user.country != null && user.country!.isNotEmpty)
                        ? '${user.city ?? ''}, ${user.country ?? ''}'
                        : 'Falta definir tu ubicación',
                  ),
                ],
              ),
            ),
            // Mostrar fotos adicionales si existen
            if (user.photos != null && user.photos!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Fotografías:',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: user.photos!.length,
                itemBuilder: (context, index) {
                  final photo = user.photos![index];
                  return GestureDetector(
                    onTap: () {
                      final urls = user.photos!.map((p) => p.url).toList();
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
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[800]),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error, color: Colors.white),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            // Botón de Cerrar sesión
            ElevatedButton(
              onPressed: () async {
                await authProvider.logoutUser();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 82),
          ],
        ),
      ),
    );
  }
}
