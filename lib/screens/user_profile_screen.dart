// lib/screens/user_profile_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  // Mapas que convierten el texto del API a claves para tr(...)
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
    'Citas': 'casual',
    'Relación seria': 'relationship',
    'Casual': 'casual',
    'Otro': 'other',
    'Pendiente': 'pending',
  };

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
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                tr("block_user"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr("block_user_confirm"),
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
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr("cancel"),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr("block"),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          // si pasas customIcon lo usa, si no usa el Icon clásico
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(20, 20, 20, 0.0),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr("user_profile"),
            style: const TextStyle(color: Colors.white)),
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
    // Muestras básicos de levantamientos
    final basicsContent =
        "${tr('squat')}: ${user!.squatWeight != null ? '${user!.squatWeight} kg' : tr('not_defined')}\n"
        "${tr('bench_press')}: ${user!.benchPressWeight != null ? '${user!.benchPressWeight} kg' : tr('not_defined')}\n"
        "${tr('deadlift')}: ${user!.deadliftWeight != null ? '${user!.deadliftWeight} kg' : tr('not_defined')}";

    // Claves dinámicas para traducción
    final genderKey = _genderKeyMap[user!.gender ?? 'Pendiente'] ?? 'pending';
    final fitnessGoalKey =
        _fitnessGoalKeyMap[user!.goal ?? 'Pendiente'] ?? 'pending';
    final relationshipGoalKey =
        _relationshipGoalKeyMap[user!.relationshipGoal ?? 'Pendiente'] ??
            'pending';

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Foto
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
          // Username
          Text(
            user!.username ?? '',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          // Biografía
          if (user!.biography != null && user!.biography!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 24.0, right: 24.0),
              child: Text(
                user!.biography!,
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

          // Contenido
          Expanded(
            child: TabBarView(
              children: [
                // ─── SOBRE MÍ ───
                ListView(
                  padding: const EdgeInsets.all(16),
                  physics:
                      const NeverScrollableScrollPhysics(), // desactiva el scroll
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
                      customIcon: Icon(Icons.people, color: Colors.white70),
                      title: tr('what_are_you_looking_for'),
                      content: tr('relationship_goal_map.$relationshipGoalKey'),
                    ),
                    _buildOptionBox(
                      icon: Icons.place,
                      title: tr('location'),
                      content: (user!.city != null && user!.city!.isNotEmpty)
                          ? '${user!.city}, ${user!.country}'
                          : tr("location_not_defined"),
                    ),
                    _buildOptionBox(
                      icon: Icons.fitness_center,
                      title: tr('basic_lifts_profile'),
                      content: basicsContent,
                    ),
                  ],
                ),

                // ─── FOTOS ───
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: user!.photos?.length ?? 0,
                    itemBuilder: (context, index) {
                      final photo = user!.photos![index];
                      final urls = user!.photos!.map((p) => p.url).toList();
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoGalleryScreen(
                              imageUrls: urls,
                              initialIndex: index,
                            ),
                          ),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: photo.url,
                          fit: BoxFit.cover,
                          placeholder: (c, u) =>
                              Container(color: Colors.grey[800]),
                          errorWidget: (c, u, e) =>
                              const Icon(Icons.error, color: Colors.white),
                        ),
                      );
                    },
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
