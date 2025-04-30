// lib/screens/PromoCodeScreen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';

class PromoCodeScreen extends StatefulWidget {
  const PromoCodeScreen({Key? key}) : super(key: key);

  @override
  State<PromoCodeScreen> createState() => _PromoCodeScreenState();
}

class _PromoCodeScreenState extends State<PromoCodeScreen> with WidgetsBindingObserver {
  final TextEditingController _promoCodeController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  
  // Usamos Future para asegurar datos frescos en cada construcción
  late Future<String?> _promoCodeFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _promoCodeFuture = _getPromoCode();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Actualizar cuando la app vuelve al primer plano
      setState(() {
        _promoCodeFuture = _getPromoCode();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Actualizar cada vez que las dependencias cambian
    setState(() {
      _promoCodeFuture = _getPromoCode();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _promoCodeController.dispose();
    super.dispose();
  }

  // Obtener el código promocional del usuario si ya tiene uno
  Future<String?> _getPromoCode() async {
    // Forzar una actualización del usuario primero
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.refreshUser();
    
    final user = authProvider.user;
    if (user != null && user.promoCode != null && user.promoCode!.isNotEmpty) {
      return user.promoCode;
    }
    return null;
  }

  // Aplicar código promocional
  Future<void> _applyPromoCode() async {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = tr("enter_promo_code");
        _successMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      
      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = tr("session_expired");
        });
        return;
      }

      final userService = UserService(token: token);
      final result = await userService.applyPromoCode(code);

      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        // Mostrar mensaje de éxito
        setState(() {
          _successMessage = result['message'];
          _promoCodeController.clear();
        });
        
        // Actualizar el usuario para reflejar el código promocional aplicado
        await authProvider.refreshUser();
        
        // Actualizar el Future para refrescar la UI
        setState(() {
          _promoCodeFuture = _getPromoCode();
        });
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
        
        // Si ya tiene un código aplicado, actualizar el Future también
        if (result.containsKey('usedCode') && result['usedCode'] != null) {
          setState(() {
            _promoCodeFuture = Future.value(result['usedCode']);
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = tr("connection_error") + ": $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("promo_code"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: FutureBuilder<String?>(
        future: _promoCodeFuture,
        builder: (context, snapshot) {
          // Mostrar indicador de carga mientras se obtiene el código
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          // Obtener el código promocional del snapshot
          final appliedPromoCode = snapshot.data;
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (appliedPromoCode != null) ...[
                  // Mostrar el código promocional aplicado
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              tr("promo_code_applied"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          appliedPromoCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr("promo_code_already_used"),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // Formulario para ingresar código promocional
                  Text(
                    tr("enter_promo_code_below"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _promoCodeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: tr("promo_code"),
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white54),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                      errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                      suffixIcon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white70),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.check, color: Colors.white),
                              onPressed: _applyPromoCode,
                            ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _applyPromoCode(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _applyPromoCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      tr("apply_code"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_successMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _successMessage,
                        style: const TextStyle(color: Colors.green),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                _buildInfoCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                tr("about_promo_codes"),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr("promo_code_info"),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            tr("promo_code_limitation"),
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
