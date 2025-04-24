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
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          title: Text(
            tr("personal_information"),
            style: const TextStyle(color: Colors.white),
          ),
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
        body: Column(
          children: [
            const SizedBox(height: 16),

            // ─── Foto de perfil + icono de editar ─────────────────
            Center(
              child: SizedBox(
                width: 140,
                height: 140,
                child: Stack(
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
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 24,
                            semanticLabel: tr("edit_button"),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // ─── Nombre de usuario ────────────────────────────────
            Text(
              user.username ?? '',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            // ─── Biografía ─────────────────────────────────────────
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
                  ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoBox(
                              title: tr('gender_display'),
                              content: user.gender ?? tr("not_specified"),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoBox(
                              title: tr('goal_title'),
                              content: user.goal ?? tr("not_specified"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoBox(
                        title: tr('what_are_you_looking_for'),
                        content: user.relationshipGoal ?? tr("not_specified"),
                      ),
                      _buildInfoBox(
                        title: tr('location'),
                        content: (user.city != null && user.city!.isNotEmpty)
                            ? '${user.city}, ${user.country}'
                            : tr("location_not_defined"),
                      ),
                      _buildInfoBox(
                        title: tr("basic_lifts_profile"),
                        content:
                        "${tr('squat')}: ${user.squatWeight != null ? '${user.squatWeight} kg' : tr('not_defined')}\n"
                            "${tr('bench_press')}: ${user.benchPressWeight != null ? '${user.benchPressWeight} kg' : tr('not_defined')}\n"
                            "${tr('deadlift')}: ${user.deadliftWeight != null ? '${user.deadliftWeight} kg' : tr('not_defined')}",
                      ),
                    ],
                  ),

                  // ────────── PESTAÑA FOTOS ───────────────── (igual que antes)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: user.photos != null && user.photos!.isNotEmpty
                        ? GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
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
      ),
    );
  }
}
