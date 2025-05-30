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
import '../services/routine_service.dart';
import '../models/routine.dart';
import '../widgets/routines/read_only_routine_card.dart';
import 'chat_screen.dart';
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
  bool isCurrentUser = false;
  
  // Variables para rutinas
  List<Routine> userRoutines = [];
  bool isLoadingRoutines = true;
  String routinesErrorMessage = '';
  bool hasLiked = false;
  bool isPremium = false;
  bool isMatch = false; // Variable para verificar si ya hay un match
  bool didLikeOrQuickLike = false; // Flag para rastrear si el usuario ha dado like o quick like

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

  Future<void> _fetchUserRoutines(String userId) async {
    setState(() {
      isLoadingRoutines = true;
      routinesErrorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      
      if (token == null) {
        setState(() {
          isLoadingRoutines = false;
          routinesErrorMessage = tr('error_loading_routines');
        });
        return;
      }

      final routineService = RoutineService(token: token);
      final result = await routineService.getUserRoutinesByUserId(userId);

      if (result['success'] == true) {
        final List<dynamic> routinesJson = result['routines'] ?? [];
        final List<Routine> routines = routinesJson
            .map((routineJson) => Routine.fromJson(routineJson))
            .toList();

        setState(() {
          userRoutines = routines;
          isLoadingRoutines = false;
        });
      } else {
        setState(() {
          isLoadingRoutines = false;
          routinesErrorMessage = result['message'] ?? tr('error_loading_routines');
        });
      }
    } catch (e) {
      setState(() {
        isLoadingRoutines = false;
        routinesErrorMessage = e.toString();
      });
    }
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

      // Obtener el estado premium del usuario actual
      final currentUser = authProvider.user;
      if (currentUser != null) {
        setState(() {
          isPremium = currentUser.isPremium;
        });
      }

      // 1. Primero verificamos si el usuario ya está en nuestra lista de matches
      if (currentUser != null && currentUser.matches != null) {
        isMatch = currentUser.matches!.contains(widget.userId);
      }

      // 2. Si no encontramos match local, consultamos los matches actuales al servidor
      if (!isMatch) {
        final matchesUrl = Uri.parse(
          'https://gymder-api-production.up.railway.app/api/matches',
        );
        final matchesResponse = await http.get(
          matchesUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (matchesResponse.statusCode == 200) {
          final matchesData = jsonDecode(matchesResponse.body);
          if (matchesData != null && matchesData['matches'] != null) {
            // Verificar si el usuario que estamos viendo está en la lista de matches
            final matches = matchesData['matches'] as List;
            for (var match in matches) {
              if (match['_id'] == widget.userId) {
                isMatch = true;
                break;
              }
            }
          }
        }
      }

      // 3. Obtenemos el perfil del usuario
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
          // Verificar si el usuario actual ya ha dado like al perfil
          final hasLikedStatus = data['hasLiked'] ?? false;
          
          setState(() {
            user = User.fromJson(data['user']);
            hasLiked = hasLikedStatus;
            isLoading = false;
          });
          
          // Verificar si es el usuario actual para cargar rutinas
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          isCurrentUser = user?.id == authProvider.user?.id;

          _fetchUserRoutines(user!.id);
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
          onPressed: () => Navigator.pop(context, didLikeOrQuickLike),
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

    // Calcular el número de pestañas basado en si hay rutinas o no
    final int tabCount = userRoutines.isNotEmpty ? 3 : 2;
    
    return DefaultTabController(
      length: tabCount,
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
          // Username con logo de verificación si está verificado
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                user!.username ?? '',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              // Logo de verificación
              if (user!.verificationStatus == 'true')
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Transform.rotate(
                    angle: 3.14159 / 1000,
                    child: Image.asset(
                      'assets/images/verificado.png',
                      width: 23,
                      height: 23,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],
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
            
          // Botones de acción (Like y Quick Like) solo si no hay match
          if (!isMatch)
            _buildActionButtons(),

          const SizedBox(height: 16),
          // Pestañas
          TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: tr('about_me')),
              Tab(text: tr('photos_profile')),
              if (userRoutines.isNotEmpty)
                Tab(text: tr('routines')),
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
                
                // ─── RUTINAS ─── (Solo se incluye si hay rutinas)
                if (userRoutines.isNotEmpty)
                  ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: userRoutines.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: ReadOnlyRoutineCard(
                          routine: userRoutines[index],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget para avatar de match
  Widget _buildMatchAvatar(String? imageUrl, {double radius = 50}) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.person, color: Colors.white, size: 40),
                ),
              )
            : Container(
                color: Colors.grey[800],
                child: const Icon(Icons.person, color: Colors.white, size: 40),
              ),
      ),
    );
  }
  
  // Modal que se muestra cuando se crea un match
  Future<void> _mostrarModalMatch(User matchedUser) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user!;
    
    await showGeneralDialog(
      context: context,
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionDuration: const Duration(milliseconds: 400),
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF111111), Color(0xFF222222)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título e icono
                    const Icon(
                      Icons.favorite,
                      color: Colors.pink,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr("match_title"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr("match_message", namedArgs: {"username": matchedUser.username ?? ""}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    // Avatares
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMatchAvatar(currentUser.profilePicture?.url, radius: 50),
                        const SizedBox(width: 20),
                        _buildMatchAvatar(matchedUser.profilePicture?.url, radius: 50),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Botones
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              currentUserId: currentUser.id!,
                              matchedUserId: matchedUser.id!,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        tr("send_message"),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        tr("continue_browsing"),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Mostrar diálogo para comprar Quick Likes
  Future<bool?> _showBuyQuickLikeDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr("no_quicklikes_title"),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr("no_quicklikes_message"),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        tr("cancel"),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        tr("buy_more_quick_likes_modal"),
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
  }
  
  // Mostrar diálogo de límite de likes alcanzado
  void _showLikeLimitDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                tr("like_limit_reached"),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr("like_limit_message"),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  // Aquí se puede navegar a la pantalla de compra de premium
                },
                child: Text(
                  tr("buy_premium"),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  tr("close"),
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Función para manejar el like
  Future<void> _handleLike() async {
    if (hasLiked) return; // Si ya ha dado like, no hacer nada
    
    setState(() {
      isLoading = true;
    });
    
    try {
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
      final result = await userService.likeUser(widget.userId);
      
      // Imprimir la respuesta para depuración
      print("Respuesta completa del like: $result");
      
      if (result['success'] == true) {
        // Actualizar estado de like y marcar que se ha realizado una acción
        setState(() {
          hasLiked = true;
          didLikeOrQuickLike = true; // Marcar que se ha dado like
          isLoading = false;
        });
        
        // Revisar diferentes claves posibles para el match
        if (result['matchedUser'] != null) {
          User matchedUser;
          
          // Verificar si matchedUser ya es un objeto User o si es un Map que necesita ser convertido
          if (result['matchedUser'] is User) {
            // Ya es un objeto User, usarlo directamente
            matchedUser = result['matchedUser'] as User;
          } else {
            // Es un Map, convertirlo a User
            matchedUser = User.fromJson(result['matchedUser']);
          }
          
          // Asegurar que el modal se muestre antes de continuar
          await _mostrarModalMatch(matchedUser);
        } else if (result['match'] != null) {
          print("Encontrado match en la respuesta");
          User matchedUser;
          
          if (result['match'] is User) {
            matchedUser = result['match'] as User;
          } else {
            matchedUser = User.fromJson(result['match']);
          }
          
          await _mostrarModalMatch(matchedUser);
        } else if (result['data'] != null && result['data']['matchedUser'] != null) {
          print("Encontrado data.matchedUser en la respuesta");
          User matchedUser;
          
          if (result['data']['matchedUser'] is User) {
            matchedUser = result['data']['matchedUser'] as User;
          } else {
            matchedUser = User.fromJson(result['data']['matchedUser']);
          }
          
          await _mostrarModalMatch(matchedUser);
        }
      } else if (result['message'] == 'like_limit_reached' || result['limitReached'] == true) {
        setState(() => isLoading = false);
        _showLikeLimitDialog();
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("error_liking_user"))),
        );
      }
    } catch (e, stackTrace) {
      print("Error al dar like: $e");
      print("Stack trace: $stackTrace");
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("error_sending_like"))),
      );
    }
  }
  
  // Diálogo de confirmación para Quick Like
  Future<bool> _showConfirmQuickLikeDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flash_on,
                  color: Colors.blue,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              // Título
              Text(
                tr("confirm_quicklike_title"),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Mensaje
              Text(
                tr("confirm_quicklike_message"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        tr("cancel"),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        tr("use_quick_like"),
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
    ) ?? false; // Si el diálogo se cierra sin una respuesta, devuelve false
  }

  // Función para manejar el Quick Like (para usuarios premium)
  Future<void> _handleQuickLike() async {
    if (hasLiked) return; // Si ya ha dado like, no hacer nada
    
    // Mostrar diálogo de confirmación primero
    final confirmed = await _showConfirmQuickLikeDialog();
    if (!confirmed) return; // Si el usuario cancela, no continuar
    
    setState(() {
      isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;
      final token = await authProvider.getToken();
      
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("auth_error"))),
        );
        setState(() => isLoading = false);
        return;
      }
      
      // Verificar si el usuario tiene Quick Likes disponibles
      if (currentUser != null && currentUser.topLikeCount <= 0) {
        setState(() => isLoading = false);
        final buy = await _showBuyQuickLikeDialog();
        if (buy == true) {
          // Navegar a la pantalla de compra de Quick Likes
          // Aquí se puede implementar la navegación a la pantalla de compra
        }
        return;
      }
      
      final userService = UserService(token: token);
      final result = await userService.superLikeUser(widget.userId);
      
      // Imprimir la respuesta para depuración
      print("Respuesta completa del quick like: $result");
      
      if (result['success'] == true) {
        setState(() {
          hasLiked = true;
          didLikeOrQuickLike = true; // Marcar que se ha dado quick like
          isLoading = false;
        });
        
        // Revisar diferentes claves posibles para el match
        bool matchFound = false;
        
        if (result['matchedUser'] != null) {
          print("Encontrado matchedUser en la respuesta de quick like");
          User matchedUser;
          
          // Verificar si matchedUser ya es un objeto User o si es un Map que necesita ser convertido
          if (result['matchedUser'] is User) {
            // Ya es un objeto User, usarlo directamente
            matchedUser = result['matchedUser'] as User;
          } else {
            // Es un Map, convertirlo a User
            matchedUser = User.fromJson(result['matchedUser']);
          }
          
          await _mostrarModalMatch(matchedUser);
          matchFound = true;
        } else if (result['match'] != null) {
          print("Encontrado match en la respuesta de quick like");
          User matchedUser;
          
          if (result['match'] is User) {
            matchedUser = result['match'] as User;
          } else {
            matchedUser = User.fromJson(result['match']);
          }
          
          await _mostrarModalMatch(matchedUser);
          matchFound = true;
        } else if (result['data'] != null && result['data']['matchedUser'] != null) {
          print("Encontrado data.matchedUser en la respuesta de quick like");
          User matchedUser;
          
          if (result['data']['matchedUser'] is User) {
            matchedUser = result['data']['matchedUser'] as User;
          } else {
            matchedUser = User.fromJson(result['data']['matchedUser']);
          }
          
          await _mostrarModalMatch(matchedUser);
          matchFound = true;
        }
        
        // Si no hay match, mostrar mensaje de quick like enviado
        if (!matchFound) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr("quick_like_sent"))),
          );
        }
      } else {
        setState(() {
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? tr("error_sending_quick_like"))),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
  
  // Función para construir los botones de acción
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón de Like
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: TextButton.icon(
                onPressed: hasLiked ? null : _handleLike,
                icon: Icon(
                  FontAwesomeIcons.heart,
                  color: hasLiked ? Colors.red : Colors.white,
                  size: 18,
                ),
                label: Text(
                  tr('like'),
                  style: TextStyle(
                    color: hasLiked ? Colors.grey : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: TextButton.styleFrom(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            
            // Separador vertical
            if (isPremium)
              Container(
                height: 24,
                width: 1,
                color: Colors.white.withOpacity(0.3),
              ),
            
            // Botón de Quick Like (solo para usuarios premium)
            if (isPremium)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: TextButton.icon(
                  onPressed: hasLiked ? null : _handleQuickLike,
                  icon: Icon(
                    FontAwesomeIcons.bolt,
                    color: hasLiked ? Colors.grey : Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    tr('quick_like'),
                    style: TextStyle(
                      color: hasLiked ? Colors.grey : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(30),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
