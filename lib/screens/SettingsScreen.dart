// lib/screens/settingsScreen.dart
import 'package:app/screens/splash_screen.dart';
import 'package:app/screens/suscripciones_pagos_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'login_screen.dart';
import 'AcercaDeScreen.dart';

/// Estilo común para todos los botones "Cancelar", "Modificar", "Actualizar", etc.
final ButtonStyle kAppButtonStyle = TextButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: Colors.black,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(28),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
);

/// PANTALLA PRINCIPAL DE AJUSTES
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  void _optionSelected(BuildContext context, String option) {
    if (option == tr("notifications")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
      );
    } else if (option == tr("languages")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IdiomasScreen()),
      );
    } else if (option == tr("subscriptions_payments")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SuscripcionesPagosScreen()),
      );
    } else if (option == tr("security")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SeguridadScreen()),
      );
    } else if (option == tr("app_permissions")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PermisosAppScreen()),
      );
    } else if (option == tr("about")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AcercaDeScreen()),
      );
    } else if (option == tr("logout")) {
      _confirmLogout(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("selected_option", args: [option]))),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr("logout_confirm_title")),
        content: Text(tr("logout_confirm_content")),
        actions: [
          TextButton(
            style: kAppButtonStyle,
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr("cancel")),
          ),
          TextButton(
            style: kAppButtonStyle,
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr("confirm")),
          ),
        ],
      ),
    );

    if (result == true) {
      Provider.of<AuthProvider>(context, listen: false).logoutUser();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> options = [
      {"title": tr("notifications"), "icon": Icons.notifications},
      {"title": tr("languages"), "icon": Icons.language},
      {"title": tr("subscriptions_payments"), "icon": Icons.payment},
      {"title": tr("security"), "icon": Icons.security},
      {"title": tr("app_permissions"), "icon": Icons.apps},
      {"title": tr("about"), "icon": Icons.info},
      {"title": tr("logout"), "icon": Icons.logout},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr("settings"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: ListView.separated(
        itemCount: options.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white24),
        itemBuilder: (context, index) {
          final option = options[index];
          return ListTile(
            leading: Icon(option["icon"], color: Colors.white70),
            title: Text(option["title"],
                style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 16),
            onTap: () => _optionSelected(context, option["title"]),
          );
        },
      ),
    );
  }
}

/// PANTALLA DE NOTIFICACIONES
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({Key? key}) : super(key: key);
  @override
  _NotificacionesScreenState createState() => _NotificacionesScreenState();
}
class _NotificacionesScreenState extends State<NotificacionesScreen> {
  bool notificarMatches = true;
  bool notificarMensajes = true;
  bool notificarLikes = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("notifications"),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(tr("notify_new_matches"),
                style: const TextStyle(color: Colors.white)),
            value: notificarMatches,
            activeColor: Colors.blueAccent,
            onChanged: (v) => setState(() => notificarMatches = v),
          ),
          SwitchListTile(
            title: Text(tr("notify_messages"),
                style: const TextStyle(color: Colors.white)),
            value: notificarMensajes,
            activeColor: Colors.blueAccent,
            onChanged: (v) => setState(() => notificarMensajes = v),
          ),
          SwitchListTile(
            title: Text(tr("notify_likes"),
                style: const TextStyle(color: Colors.white)),
            value: notificarLikes,
            activeColor: Colors.blueAccent,
            onChanged: (v) => setState(() => notificarLikes = v),
          ),
        ],
      ),
    );
  }
}

/// PANTALLA DE IDIOMAS
class IdiomasScreen extends StatefulWidget {
  const IdiomasScreen({Key? key}) : super(key: key);
  @override
  _IdiomasScreenState createState() => _IdiomasScreenState();
}
class _IdiomasScreenState extends State<IdiomasScreen> {
  late String idiomaSeleccionado;
  final List<String> idiomas = ["Español", "English"];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = context.locale.languageCode;
    idiomaSeleccionado = current == 'en' ? 'English' : 'Español';
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("languages"),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: ListView(
        children: idiomas.map((idioma) {
          return RadioListTile(
            title: Text(idioma.tr(),
                style: const TextStyle(color: Colors.white)),
            value: idioma,
            groupValue: idiomaSeleccionado,
            activeColor: Colors.blueAccent,
            onChanged: (String? value) {
              setState(() => idiomaSeleccionado = value!);
              context.setLocale(Locale(value == "Español" ? 'es' : 'en'));
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SplashScreen()),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

/// PANTALLA DE SEGURIDAD
class SeguridadScreen extends StatefulWidget {
  const SeguridadScreen({Key? key}) : super(key: key);
  @override
  _SeguridadScreenState createState() => _SeguridadScreenState();
}
class _SeguridadScreenState extends State<SeguridadScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool isUpdating = false;
  String updateMessage = '';

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => updateMessage = tr("passwords_do_not_match"));
      return;
    }
    setState(() {
      isUpdating = true;
      updateMessage = '';
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) {
      setState(() {
        isUpdating = false;
        updateMessage = tr("token_not_found_login");
      });
      return;
    }
    final userService = UserService(token: token);
    final result = await userService.changePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );
    setState(() {
      isUpdating = false;
      updateMessage = result['message'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("security"),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(tr("change_password"),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: tr("current_password"),
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: tr("new_password"),
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: tr("confirm_new_password"),
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: kAppButtonStyle,
              onPressed: isUpdating ? null : _changePassword,
              child: isUpdating
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(tr("update_password")),
            ),
            const SizedBox(height: 10),
            if (updateMessage.isNotEmpty)
              Text(updateMessage, style: const TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}

/// PANTALLA DE PERMISOS DE LA APLICACIÓN
class PermisosAppScreen extends StatelessWidget {
  const PermisosAppScreen({Key? key}) : super(key: key);

  void _openAppSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final permisos = [
      {
        "title": tr("location"),
        "description": tr("location_permission_description")
      },
      {
        "title": tr("camera"),
        "description": tr("camera_permission_description")
      },
      {
        "title": tr("storage"),
        "description": tr("storage_permission_description")
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr("app_permissions"),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: ListView.separated(
        itemCount: permisos.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white24),
        itemBuilder: (context, index) {
          final permiso = permisos[index];
          return ListTile(
            leading: const Icon(Icons.info, color: Colors.white70),
            title: Text(permiso["title"]!,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text(permiso["description"]!,
                style: const TextStyle(color: Colors.white70)),
            trailing: ElevatedButton(
              style: kAppButtonStyle,
              onPressed: _openAppSettings,
              child: Text(tr("modify")),
            ),
          );
        },
      ),
    );
  }
}

/// PLACEHOLDER PARA PREMIUM PURCHASE
class PremiumPurchasePage extends StatelessWidget {
  const PremiumPurchasePage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("become_premium"),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          tr("premium_screen_text"),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
