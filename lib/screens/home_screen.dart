// lib/screens/home_screen.dart

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
  int _selectedIndex = 1;

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
        // Creamos solo una vez el widget con la misma Key
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
          SnackBar(
            content: Text(
              'Error de compra: ${purchase.error?.message ?? 'Unknown error'}',
            ),
          ),
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

  void _onItemTapped(int index) {
    setState(() {
      if (index == 0) {
        _matchesScreen = MatchesChatsScreen(key: UniqueKey());
      }
      _selectedIndex = index;
    });
  }

  List<Widget> _widgetOptions() => [_matchesScreen, _tikTokLikeScreen];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    // Si el registro de Google quedó incompleto, redirige
    if (!widget.fromGoogle &&
        user != null &&
        (user.gender == 'Pendiente' || user.relationshipGoal == 'Pendiente')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RegisterScreen(fromGoogle: true),
          ),
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
      bottomNavigationBar: _buildBottomBar(auth, user!),
    );
  }

  Widget _buildBottomBar(AuthProvider auth, User user) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Chats
          GestureDetector(
            onTap: () => _onItemTapped(0),
            child: CircleAvatar(
              radius: 27,
              backgroundColor:
                  _selectedIndex == 0 ? Colors.white : Colors.grey.shade800,
              child: Icon(
                Icons.chat_bubble,
                color: _selectedIndex == 0 ? Colors.black : Colors.white,
                size: 28,
              ),
            ),
          ),

          const SizedBox(width: 40),

          // TikTok-like / SuperLike
          GestureDetector(
            onTap: () {
              if (_selectedIndex == 0) {
                _onItemTapped(1);
              } else {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  barrierColor: Colors.black54,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
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
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
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
                                _buyTopLike();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Icon(Icons.credit_card,
                                        color: Colors.white, size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                      tr('buy_more_quick_likes'),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 16),
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
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
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 16),
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
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 16),
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 37,
                  backgroundColor:
                      _selectedIndex == 1 ? Colors.white : Colors.grey.shade800,
                  child: Icon(
                    Icons.favorite,
                    color: _selectedIndex == 1 ? Colors.black : Colors.white,
                    size: 45,
                  ),
                ),
                Positioned(
                  right: -2,
                  top: -8,
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
                ),
              ],
            ),
          ),

          const SizedBox(width: 40),

          // Perfil
          GestureDetector(
            onTap: () {
              Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const MyProfileScreen()),
              ).then((shouldRefresh) {
                if (shouldRefresh == true) {
                  // Llama al método público que actualiza la lista sin resetear el controller
                  _tikTokKey.currentState?.reloadProfiles();
                }
              });
            },
            child: CircleAvatar(
              radius: 27,
              backgroundColor: Colors.grey.shade800,
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
