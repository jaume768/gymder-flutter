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
        // Notificar al backend para actualizar el usuario a premium
        await _updateUserToPremium();

        // Confirmar compra
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        // Manejar errores en la compra si es necesario
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
        const SnackBar(content: Text('Ahora eres usuario Premium')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error en la suscripción')),
      );
    }
  }

  void _buyPremium() {
    final product = _products.firstWhere((p) => p.id == _premiumProductId,
        orElse: () => throw Exception('Producto no encontrado'));
    final purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Widget _buildAdvantage(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyanAccent),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Compra Premium'),
        backgroundColor: Colors.grey[900],
      ),
      body: _available
          ? (_products.isNotEmpty
          ? SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Ventajas de ser Premium",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey[700]),
                    _buildAdvantage("Scrolls infinitos", Icons.swap_vert),
                    _buildAdvantage("Likes infinitos", Icons.favorite),
                    _buildAdvantage("Acceso al apartado de 'Le gustas'", Icons.thumb_up),
                    _buildAdvantage("Scroll hacia arriba desbloqueado", Icons.arrow_upward),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: _buyPremium,
              child: const Text('Comprar Premium'),
            ),
          ],
        ),
      )
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'No se encontraron productos.',
            style: TextStyle(color: Colors.white),
          ),
          ElevatedButton(
            onPressed: _initialize,
            child: const Text('Reintentar'),
          ),
        ],
      ))
          : const Center(
        child: Text(
          'Las compras in-app no están disponibles.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
