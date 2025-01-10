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
  final String _premiumProductId =
      'your_premium_product_id'; // Reemplaza con tu productId real
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
    if (!_available) {
      // Manejar caso donde las compras no están disponibles
      return;
    }

    // Consultar detalles del producto
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
        // Verifica y consume/actualiza la compra aquí si es necesario.

        // Notificar al backend para actualizar el usuario a premium
        await _updateUserToPremium();

        // Confirmar compra
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        // Manejar errores en la compra
      }
    }
  }

  Future<void> _updateUserToPremium() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) return;

    final userService = UserService(token: token);
    "final result = await userService.subscribePremium();";
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ahora eres usuario Premium')),
    );
  }

  void _buyPremium() {
    final product = _products.firstWhere((p) => p.id == _premiumProductId,
        orElse: () => throw Exception('Producto no encontrado'));
    final purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compra Premium')),
      body: Center(
        child: _available && _products.isNotEmpty
            ? ElevatedButton(
                onPressed: _buyPremium,
                child: const Text('Comprar Premium'),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
