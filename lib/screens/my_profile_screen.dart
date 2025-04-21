import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'SettingsScreen.dart';
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
        title:
            Text(tr("personal_information"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          )
        ],
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 0.0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile picture and edit button
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
                      child: Icon(Icons.edit,
                          color: Colors.white,
                          size: 24,
                          semanticLabel: tr("edit_button")),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Username
            Text(
              user.username ?? '',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            // Biografía / Biography
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
                    title: tr("objective"),
                    content: user.goal ?? tr("not_specified"),
                  ),
                  const Divider(
                      color: Colors.white24, indent: 16, endIndent: 16),
                  _buildInfoTile(
                    icon: Icons.wc,
                    title: tr("gender_display"),
                    content: user.gender ?? tr("not_specified"),
                  ),
                  const Divider(
                      color: Colors.white24, indent: 16, endIndent: 16),
                  _buildInfoTile(
                    icon: Icons.favorite,
                    title: tr("relationship_goal"),
                    content: user.relationshipGoal ?? tr("not_specified"),
                  ),
                  const Divider(
                      color: Colors.white24, indent: 16, endIndent: 16),
                  _buildInfoTile(
                    icon: Icons.location_on,
                    title: tr("location"),
                    content: (user.city != null && user.city!.isNotEmpty) ||
                            (user.country != null && user.country!.isNotEmpty)
                        ? '${user.city ?? ''}, ${user.country ?? ''}'
                        : tr("location_not_defined"),
                  ),
                ],
              ),
            ),
            // Fotografías adicionales
            if (user.photos != null && user.photos!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                tr("photos"),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              // Si deseas usar traducción para "Fotografías:" reemplázalo por:
              // Text(tr("photographs"), style: ... )
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
          ],
        ),
      ),
    );
  }
}
