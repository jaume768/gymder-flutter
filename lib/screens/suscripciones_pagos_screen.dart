// lib/screens/suscripciones_pagos_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'premium_purchase_page.dart';

/// Estilo común para los botones de esta pantalla
final ButtonStyle kAppButtonStyle = TextButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: Colors.black,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(28),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
);

class SuscripcionesPagosScreen extends StatefulWidget {
  const SuscripcionesPagosScreen({Key? key}) : super(key: key);

  @override
  _SuscripcionesPagosScreenState createState() =>
      _SuscripcionesPagosScreenState();
}

class _SuscripcionesPagosScreenState extends State<SuscripcionesPagosScreen> {
  bool isLoading = false;
  String errorMessage = '';

  Future<void> _cancelSubscription() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) {
      setState(() {
        isLoading = false;
        errorMessage = tr("token_not_found_login");
      });
      return;
    }

    final userService = UserService(token: token);
    final result = await userService.cancelPremium();

    if (result['success'] == true) {
      await authProvider.refreshUser();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? tr("subscription_cancelled")),
        ),
      );
    } else {
      setState(() {
        errorMessage = result['message'] ?? tr("error_cancelling_subscription");
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _confirmCancelSubscription() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.subscriptions, size: 48, color: Colors.blueAccent),
              const SizedBox(height: 12),
              Text(
                tr("confirm_cancel_subscription"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr("confirm_cancel_subscription_message"),
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
                        side: const BorderSide(color: Colors.blueAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr("no"),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr("yes"),
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

    if (result == true) {
      _cancelSubscription();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final bool esPremium = user?.isPremium ?? false;
    String fechaExpiracion = '';
    if (esPremium && user?.premiumExpiration != null) {
      fechaExpiracion =
          user!.premiumExpiration!.toLocal().toString().split(' ')[0];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr("subscriptions_payments"),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: Colors.grey[850],
              child: ListTile(
                leading: const Icon(Icons.payment, color: Colors.white),
                title: Text(
                  esPremium ? tr("premium_user") : tr("standard_user"),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: esPremium && fechaExpiracion.isNotEmpty
                    ? Text(
                        "${tr("expires_on")}: $fechaExpiracion",
                        style: const TextStyle(color: Colors.white70),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            if (!esPremium)
              ElevatedButton(
                style: kAppButtonStyle,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PremiumPurchasePage()),
                  );
                },
                child: Text(tr("become_premium")),
              ),
            if (esPremium)
              ElevatedButton(
                style: kAppButtonStyle,
                onPressed: isLoading ? null : _confirmCancelSubscription,
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr("cancel_subscription")),
              ),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
