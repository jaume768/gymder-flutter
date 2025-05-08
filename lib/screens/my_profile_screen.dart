// lib/screens/MyProfileScreen.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'SettingsScreen.dart';
import 'edit_profile_screen.dart';
import 'photo_gallery_screen.dart';
import 'verification_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({Key? key}) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  // Mapas que convierten el texto en español del API a claves para tr(...)
  static const Map<String, String> _genderKeyMap = {
    'Masculino': 'male',
    'Femenino': 'female',
    'No Binario': 'non_binary',
    'Prefiero no decirlo': 'prefer_not_to_say',
    'Otro': 'other',
    'Pendiente': 'pending',
  };
  static const Map<String, String> _fitnessGoalKeyMap = {
    'Volumen': 'volume',
    'Definición': 'definition',
    'Mantenimiento': 'maintenance',
    'Otro': 'other',
    'Pendiente': 'pending',
  };
  static const Map<String, String> _relationshipGoalKeyMap = {
    'Amistad': 'friendship',
    'Casual': 'casual',
    'Relación': 'relationship',
    'Otro': 'other',
    'Pendiente': 'pending',
  };

  @override
  void initState() {
    super.initState();
    // Refrescar usuario al entrar
    Provider.of<AuthProvider>(context, listen: false).refreshUser();
  }

  /// Caja de opción con icono, título a la izquierda y valor a la derecha
  Widget _buildOptionBox({
    IconData? icon,
    Widget? customIcon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          customIcon ?? Icon(icon, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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

  Future<bool> _onWillPop() async {
    // Al hacer swipe-back o back físico, devolvemos true
    Navigator.pop(context, true);
    return false;
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

    // Traducciones dinámicas
    final genderKey = _genderKeyMap[user.gender] ?? 'pending';
    final fitnessGoalKey = _fitnessGoalKeyMap[user.goal] ?? 'pending';
    final relationshipGoalKey =
        _relationshipGoalKeyMap[user.relationshipGoal] ?? 'pending';

    return WillPopScope(
      onWillPop: _onWillPop,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context, true),
            ),
            title: Text(
              tr('personal_information'),
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
          backgroundColor: const Color.fromRGBO(20, 20, 20, 0.8),
          body: Column(
            children: [
              const SizedBox(height: 16),
              // Foto de perfil + botón editar
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
                            ? CachedNetworkImageProvider(
                                user.profilePicture!.url)
                            : const AssetImage(
                                    'assets/images/default_profile.png')
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
                              semanticLabel: tr('edit_button'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Nombre de usuario con logo de verificación si está verificado
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    user.username ?? '',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  // Logo de verificación
                  if (user.verificationStatus == 'true')
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Transform.rotate(
                        angle: 3.14159 / 1000,
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                ],
              ),
              
              // Botón de verificación si la cuenta no está verificada
              if (user.verificationStatus != 'true')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => const VerificationScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_outlined,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tr('add_verification_badge'),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (user.biography != null && user.biography!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 8.0),
                  child: Text(
                    user.biography!,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              // Pestañas
              TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: tr('about_me')),
                  Tab(text: tr('photos_profile')),
                ],
              ),
              // Contenido de cada pestaña
              Expanded(
                child: TabBarView(
                  children: [
                    // === SOBRE MÍ ===
                    ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: [
                        _buildOptionBox(
                          icon: Icons.person,
                          title: tr('gender_display'),
                          content: tr('gender.$genderKey'),
                        ),
                        _buildOptionBox(
                          customIcon: SvgPicture.asset(
                            'assets/images/muscle.svg',
                            width: 24,
                            height: 24,
                            color: Colors.white70,
                          ),
                          title: tr('goal_title'),
                          content: tr('fitness_goal.$fitnessGoalKey'),
                        ),
                        _buildOptionBox(
                          icon: Icons.people,
                          title: tr('what_are_you_looking_for'),
                          content:
                              tr('relationship_goal_map.$relationshipGoalKey'),
                        ),
                        _buildOptionBox(
                          icon: Icons.place,
                          title: tr('location'),
                          content: (user.city != null && user.city!.isNotEmpty)
                              ? '${user.city}, ${user.country}'
                              : tr('location_not_defined'),
                        ),
                        _buildOptionBox(
                          icon: Icons.fitness_center,
                          title: tr('basic_lifts_profile'),
                          content:
                              "${tr('squat')}: ${user.squatWeight != null ? '${user.squatWeight} kg' : tr('not_defined')}\n"
                              "${tr('bench_press')}: ${user.benchPressWeight != null ? '${user.benchPressWeight} kg' : tr('not_defined')}\n"
                              "${tr('deadlift')}: ${user.deadliftWeight != null ? '${user.deadliftWeight} kg' : tr('not_defined')}",
                        ),
                      ],
                    ),

                    // === FOTOS ===
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: (user.photos != null && user.photos!.isNotEmpty)
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
                                    final urls =
                                        user.photos!.map((p) => p.url).toList();
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
                                    errorWidget: (ctx, url, error) =>
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
        ),
      ),
    );
  }
}
