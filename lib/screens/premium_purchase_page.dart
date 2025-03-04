// lib/screens/premium_purchase_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';

class PremiumPurchasePage extends StatefulWidget {
  const PremiumPurchasePage({Key? key}) : super(key: key);

  @override
  State<PremiumPurchasePage> createState() => _PremiumPurchasePageState();
}

class _PremiumPurchasePageState extends State<PremiumPurchasePage> {
  final InAppPurchase _iap = InAppPurchase.instance;
  final String _premiumProductId = 'gymswipe_premium';
  bool _available = false;
  List<ProductDetails> _products = [];
  late Stream<List<PurchaseDetails>> _subscription;

  @override
  void initState() {
    super.initState();
    _initialize();
    _subscription = _iap.purchaseStream;
    _subscription.listen(_listenToPurchaseUpdated);
  }

  Future<void> _initialize() async {
    _available = await _iap.isAvailable();
    if (!_available) return;
    Set<String> ids = {_premiumProductId};
    ProductDetailsResponse response = await _iap.queryProductDetails(ids);
    if (response.error == null) {
      setState(() {
        _products = response.productDetails;
      });
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.productID == _premiumProductId &&
          purchase.status == PurchaseStatus.purchased) {
        await _updateUserToPremium();
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        // Manejar errores en la compra (puedes agregar lógica adicional aquí)
      }
    }
  }

  Future<void> _updateUserToPremium() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) return;
    final userService = UserService(token: token);
    final result = await userService.subscribePremium();

    if (result['success'] == true) {
      await authProvider.refreshUser();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("become_premium".tr())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "error_subscription".tr())),
      );
    }
  }

  void _buyPremium() {
    final product = _products.firstWhere(
      (p) => p.id == _premiumProductId,
      orElse: () => throw Exception("product_not_found".tr()),
    );
    final purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Widget _buildAdvantage(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _available ? _buildPremiumContent() : _buildNotAvailable(),
    );
  }

  Widget _buildPremiumContent() {
    return Stack(
      children: [
        // Imagen de fondo
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/premium_background.jpg"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Superposición oscura
        Container(
          color: Colors.black.withOpacity(0.6),
        ),
        // Contenido principal
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Encabezado con botón de regreso
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      "become_premium".tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 40),
                // Beneficios (glassmorphism)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "premium_screen_text".tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(color: Colors.white70),
                      _buildAdvantage("infinite_scrolls".tr(), Icons.swap_vert),
                      _buildAdvantage("unlimited_likes".tr(), Icons.favorite),
                      _buildAdvantage("access_le_gustas".tr(), Icons.thumb_up),
                      _buildAdvantage(
                          "upward_scroll_unlocked".tr(), Icons.arrow_upward),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Botón para comprar premium
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _buyPremium,
                  child: Text(
                    "buy_premium".tr(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_products.isEmpty)
                  Column(
                    children: [
                      Text(
                        "no_products_found".tr(),
                        style: const TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: _initialize,
                        child: Text(
                          "retry".tr(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotAvailable() {
    return Center(
      child: Text(
        "in_app_not_available".tr(),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
