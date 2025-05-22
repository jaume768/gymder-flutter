import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'register_screen.dart';
import 'tiktok_like_screen.dart';
import 'login_screen.dart';
import 'matches_chats_screen.dart';
import 'my_profile_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool fromGoogle;
  const HomeScreen({Key? key, this.fromGoogle = false}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Clave para acceder al State de TikTokLikeScreen
  final _tikTokKey = GlobalKey<TikTokLikeScreenState>();

  List<User> suggestedMatches = [];
  bool isLoading = true;
  String errorMessage = '';
  int _selectedIndex = 2; // Índice por defecto (Home - el botón central)

  late TikTokLikeScreen _tikTokLikeScreen;
  late Widget _matchesScreen;

  // In-App Purchase
  final InAppPurchase _iap = InAppPurchase.instance;
  bool _iapAvailable = false;
  List<ProductDetails> _products = [];
  late StreamSubscription<List<PurchaseDetails>> _sub;
  String get _topLikeId => Platform.isIOS ? 'quicklike768' : 'top_like';

  @override
  void initState() {
    super.initState();
    _fetchSuggestedMatches();
    _initIAP();
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdated, onDone: () {
      _sub.cancel();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _fetchSuggestedMatches() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final svc = UserService(token: token);
    final result = await svc.getSuggestedMatches();
    if (result['success'] == true) {
      setState(() {
        suggestedMatches =
            List<User>.from(result['matches'].map((x) => User.fromJson(x)));
        isLoading = false;
        _tikTokLikeScreen = TikTokLikeScreen(
          key: _tikTokKey,
          users: suggestedMatches,
          onBuyQuickLike: _buyTopLike,
        );
        _matchesScreen = MatchesChatsScreen(key: UniqueKey());
      });
    } else {
      setState(() {
        errorMessage = result['message'] ?? tr("error_fetching_matches");
        isLoading = false;
      });
    }
  }

  Future<void> _initIAP() async {
    _iapAvailable = await _iap.isAvailable();
    if (!_iapAvailable) return;
    final response = await _iap.queryProductDetails({_topLikeId});
    if (response.error == null && response.productDetails.isNotEmpty) {
      setState(() {
        _products = response.productDetails;
      });
    }
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.productID != _topLikeId) continue;

      if (purchase.status == PurchaseStatus.purchased) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final token = await auth.getToken();
        if (token != null) {
          final svc = UserService(token: token);
          final res = await svc.purchaseTopLike();
          if (res['success'] == true) {
            await auth.refreshUser();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('TopLike comprado 🎉')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res['message'] ?? tr('error'))),
            );
          }
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de compra: ${purchase.error?.message ?? 'Unknown error'}')),
        );
      }
    }
  }

  void _buyTopLike() {
    if (!_iapAvailable || _products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('in_app_not_available'))),
      );
      return;
    }
    final product = _products.firstWhere((p) => p.id == _topLikeId);
    final param = PurchaseParam(productDetails: product);
    _iap.buyConsumable(purchaseParam: param);
  }

  /// Gestión de taps en la barra inferior
  void _onItemTapped(int index) {
    // Logs para debugging
    print('Tap en el índice $index');
    
    // Manejo especial para el botón de perfil
    if (index == 4) {
      print('Navegando a perfil');
      Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const MyProfileScreen()),
      ).then((shouldRefresh) {
        if (shouldRefresh == true) {
          _tikTokKey.currentState?.reloadProfiles();
        }
      });
      return;
    }

    // Para botones que aún no tienen pantalla implementada
    if (index == 1) {
      print('Botón en desarrollo: $index');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('screen_coming_soon'))));
      return;
    }

    // Para pantallas implementadas (Mensajes y Home)
    print('Cambiando a pantalla: $index');
    setState(() {
      // Recrear la pantalla de chats siempre que se seleccione
      if (index == 0) {
        _matchesScreen = MatchesChatsScreen(key: UniqueKey());
      }

      _selectedIndex = index;
    });
  }

  List<Widget> _widgetOptions() => [
        _matchesScreen, // 0: Mensajes/Chats
        Container(), // 1: Estadísticas (placeholder)
        _tikTokLikeScreen, // 2: Home (pantalla principal)
        const SearchScreen(), // 3: Buscar Perfil
      ];

  @override
  Widget build(BuildContext context) {
    // Siempre recrear chats si está seleccionado
    if (_selectedIndex == 0) {
      _matchesScreen = MatchesChatsScreen(key: UniqueKey());
    }

    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user!;

    // Si registro incompleto, redirigir
    if (!widget.fromGoogle &&
        (user.gender == 'Pendiente' || user.relationshipGoal == 'Pendiente')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const RegisterScreen(fromGoogle: true)),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : IndexedStack(
                  index: _selectedIndex,
                  children: _widgetOptions(),
                ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // -------------------------------------
  // BARRA DE NAVEGACIÓN INFERIOR
  // -------------------------------------
  Widget _buildBottomBar() {
    return SizedBox(
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Fondo e íconos laterales
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 70,
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Grupo izquierdo
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Estadísticas (placeholder)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _onItemTapped(1),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 6),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bar_chart,
                                      size: 22,
                                      color: Colors.grey.shade600,
                                    ),
                                    Text(
                                      tr('statistics'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Mensajes/Chats
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _onItemTapped(0),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 6),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.message,
                                      size: 22,
                                      color: _selectedIndex == 0
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                    ),
                                    Text(
                                      tr('messages'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _selectedIndex == 0
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hueco botón central
                    const SizedBox(width: 70),
                    // Grupo derecho
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 25), // Margen izquierdo para todo el grupo
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // Buscar Perfil (placeholder)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _onItemTapped(3),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 6),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search,
                                        size: 22,
                                        color: Colors.grey.shade600,
                                      ),
                                      Text(
                                        tr('search_profile'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 29),
                            // Perfil
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _onItemTapped(4),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 6),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 22,
                                        color: Colors.grey.shade600,
                                      ),
                                      Text(
                                        tr('profile'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Botón central FAB-like con modal
          Positioned(
            bottom: 5,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (_selectedIndex != 2) {
                      _onItemTapped(2);
                    } else {
                      // Mostrar modal para dar like o quicklike
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        barrierColor: Colors.black54,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tr('what_do_you_want'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      // Usar el método que maneja la animación y el like
                                      if (_tikTokKey.currentState != null) {
                                        _tikTokKey.currentState!.handleLikeFromModal();
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        children: [
                                          Icon(Icons.favorite, color: Colors.red, size: 24),
                                          const SizedBox(width: 12),
                                          Text(
                                            tr('dar_like'),
                                            style: const TextStyle(color: Colors.white, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      Future.microtask(() {
                                        _tikTokKey.currentState?.useSuperLike();
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        children: [
                                          SvgPicture.asset(
                                            'assets/images/rayo.svg',
                                            width: 34,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            tr('use_quick_like'),
                                            style: const TextStyle(color: Colors.white, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      tr('cancel'),
                                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  customBorder: const CircleBorder(),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selectedIndex == 2 ? Colors.white : Colors.grey.shade800,
                          border: Border.all(
                            color: _selectedIndex == 2 ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 100,
                            height: 100,
                          ),
                        ),
                      ),
                      // Contador de QuickLikes
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final user = auth.user!;
                          return Positioned(
                            right: -3,
                            top: -9,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF00C6FF), Color(0xFF004A9F)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Text(
                                user.topLikeCount > 0 ? '${user.topLikeCount}' : '+',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
