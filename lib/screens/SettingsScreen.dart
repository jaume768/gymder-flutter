// lib/screens/settingsScreen.dart
import 'package:app/screens/splash_screen.dart';
import 'package:app/screens/suscripciones_pagos_screen.dart';
import 'package:app/screens/premium_purchase_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'PromoCodeScreen.dart';
import 'login_screen.dart';
import 'AcercaDeScreen.dart';
import 'my_matches_screen.dart';
import 'verification_screen.dart';

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
        MaterialPageRoute(builder: (_) => const PremiumPurchasePage()),
      );
    } else if (option == tr("security")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SeguridadScreen()),
      );
    } else if (option == tr("identity_verification")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VerificationScreen()),
      );
    } else if (option == tr("promo_code")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PromoCodeScreen()),
      );
    } else if (option == tr("app_permissions")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PermisosAppScreen()),
      );
    } else if (option == tr("my_matches")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyMatchesScreen()),
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
    final bool? confirmed = await showDialog<bool>(
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
              Icon(Icons.exit_to_app, size: 48, color: Colors.blueAccent),
              const SizedBox(height: 12),
              Text(
                tr("logout_confirm_title"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr("logout_confirm_content"),
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
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.blueAccent),
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr("confirm"),
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

    if (confirmed == true) {
      // Aquí cerramos la sesión
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
      {"title": tr("my_matches"), "icon": Icons.favorite},
      {"title": tr("identity_verification"), "icon": Icons.verified_user},
      {"title": tr("notifications"), "icon": Icons.notifications},
      {"title": tr("languages"), "icon": Icons.language},
      {"title": tr("subscriptions_payments"), "icon": Icons.payment},
      {"title": tr("promo_code"), "icon": Icons.card_giftcard},
      {"title": tr("security"), "icon": Icons.security},
      {"title": tr("app_permissions"), "icon": Icons.apps},
      {"title": tr("about"), "icon": Icons.info},
      {"title": tr("logout"), "icon": Icons.logout},
    ];

    return Scaffold(
      appBar: AppBar(
        title:
            Text(tr("settings"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculamos la altura aproximada que necesitarán todas las opciones
          // Altura estimada de cada elemento (ListTile + Divider)
          final itemHeight = 72.0; // ~56 para ListTile + ~16 para Divider
          final totalContentHeight = options.length * itemHeight;
          
          // Determinamos si se necesita scroll basado en si el contenido excede la altura disponible
          final needsScroll = totalContentHeight > constraints.maxHeight;
          
          return SingleChildScrollView(
            // Solo permitir scroll cuando sea necesario
            physics: needsScroll 
                ? const AlwaysScrollableScrollPhysics() 
                : const NeverScrollableScrollPhysics(),
            child: Column(
              children: List.generate(options.length * 2 - 1, (index) {
                // Para los índices pares, mostramos un ListTile (la opción)
                if (index.isEven) {
                  final optionIndex = index ~/ 2;
                  final option = options[optionIndex];
                  return ListTile(
                    leading: Icon(option["icon"], color: Colors.white70),
                    title: Text(option["title"],
                        style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        color: Colors.white70, size: 16),
                    onTap: () => _optionSelected(context, option["title"]),
                  );
                } 
                // Para los índices impares, mostramos un divisor
                else {
                  return const Divider(color: Colors.white24);
                }
              }),
            ),
          );
        },
      ),
    );
  }
}

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});
  @override
  _NotificacionesScreenState createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  bool _notificarMatches = true;
  bool _notificarMensajes = true;
  bool _notificarLikes = true;
  bool _loading = true;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    // 1) Obtener token y luego preferencias del backend
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) return;

    final result = await UserService(token: token).getNotificationSettings();
    if (result['success'] == true) {
      setState(() {
        _notificarMatches = result['settings']['matches'] as bool;
        _notificarMensajes = result['settings']['messages'] as bool;
        _notificarLikes = result['settings']['likes'] as bool;
        _loading = false;
      });
    } else {
      // Manejar error...
      setState(() => _loading = false);
    }

    // 2) Suscribirte o no a topics según lo leído
    _updateSubscription('new_matches', _notificarMatches);
    _updateSubscription('messages', _notificarMensajes);
    _updateSubscription('new_likes', _notificarLikes);
  }

  Future<void> _updatePreference(String key, bool value) async {
    setState(() {
      switch (key) {
        case 'matches':
          _notificarMatches = value;
          break;
        case 'messages':
          _notificarMensajes = value;
          break;
        case 'likes':
          _notificarLikes = value;
          break;
      }
    });
    // 1) Guardar en tu backend
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token != null) {
      await UserService(token: token).setNotificationSetting(key, value);
    }
    // 2) Suscribir / desuscribir topic FCM
    final topic = {
      'matches': 'new_matches',
      'messages': 'messages',
      'likes': 'new_likes',
    }[key]!;
    _updateSubscription(topic, value);
  }

  void _updateSubscription(String topic, bool subscribe) {
    if (subscribe) {
      _fcm.subscribeToTopic(topic);
    } else {
      _fcm.unsubscribeFromTopic(topic);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color.fromRGBO(20, 20, 20, 1),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("notifications"),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Lista de items que mostraremos
          final notificationItems = [
            SwitchListTile(
              title: Text(tr("notify_new_matches"),
                  style: const TextStyle(color: Colors.white)),
              value: _notificarMatches,
              activeColor: Colors.blueAccent,
              onChanged: (v) => _updatePreference('matches', v),
            ),
            SwitchListTile(
              title: Text(tr("notify_messages"),
                  style: const TextStyle(color: Colors.white)),
              value: _notificarMensajes,
              activeColor: Colors.blueAccent,
              onChanged: (v) => _updatePreference('messages', v),
            ),
            SwitchListTile(
              title: Text(tr("notify_likes"),
                  style: const TextStyle(color: Colors.white)),
              value: _notificarLikes,
              activeColor: Colors.blueAccent,
              onChanged: (v) => _updatePreference('likes', v),
            ),
          ];
          
          // Calculamos altura aproximada del contenido
          final itemHeight = 60.0; // Altura estimada de cada switch
          final totalContentHeight = notificationItems.length * itemHeight;
          
          // Determinamos si se necesita scroll
          final needsScroll = totalContentHeight > constraints.maxHeight;
          
          return SingleChildScrollView(
            // Física de scroll condicional
            physics: needsScroll
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: Column(children: notificationItems),
          );
        },
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
  final List<String> idiomas = [
    "Español",
    "English",
    "Français",
    "Deutsch",
    "Italiano",
  ];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = context.locale.languageCode;
    idiomaSeleccionado = {
      'es': 'Español',
      'en': 'English',
      'fr': 'Français',
      'de': 'Deutsch',
      'it': 'Italiano',
    }[code]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(tr("languages"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Generamos los items de idiomas
          final languageItems = idiomas.map((idioma) {
            return RadioListTile(
              title:
                  Text(idioma.tr(), style: const TextStyle(color: Colors.white)),
              value: idioma,
              groupValue: idiomaSeleccionado,
              activeColor: Colors.blueAccent,
              onChanged: (String? value) {
                setState(() => idiomaSeleccionado = value!);
                final newCode = {
                  'Español': 'es',
                  'English': 'en',
                  'Français': 'fr',
                  'Deutsch': 'de',
                  'Italian': 'it',
                }[value]!;
                context.setLocale(Locale(newCode));
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                );
              },
            );
          }).toList();
          
          // Calculamos altura aproximada del contenido
          final itemHeight = 55.0; // Altura estimada de cada opción de idioma
          final totalContentHeight = idiomas.length * itemHeight;
          
          // Determinamos si se necesita scroll
          final needsScroll = totalContentHeight > constraints.maxHeight;
          
          return SingleChildScrollView(
            // Física de scroll condicional
            physics: needsScroll
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: Column(children: languageItems),
          );
        },
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
  bool updateSuccess = false;
  String updateMessage = '';

  Future<void> _changePassword() async {
    // Validación local
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        updateSuccess = false;
        updateMessage = tr("passwords_do_not_match");
      });
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
        updateSuccess = false;
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
      updateSuccess = result['success'] == true;
      updateMessage = result['message'] ?? '';
      if (updateSuccess) {
        // Limpia los campos si se cambió bien
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(tr("security"), style: const TextStyle(color: Colors.white)),
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

            // Contraseña actual
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

            // Nueva contraseña
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

            // Confirmar nueva contraseña
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

            // Botón de actualizar
            ElevatedButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
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

            // Mensaje de resultado
            if (updateMessage.isNotEmpty)
              Text(
                updateMessage,
                style: TextStyle(
                  color: updateSuccess ? Colors.green : Colors.redAccent,
                ),
                textAlign: TextAlign.center,
              ),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Preparamos la lista de widgets de permisos
          final permissionItems = <Widget>[];
          
          for (int i = 0; i < permisos.length; i++) {
            // Añadimos cada item de permiso
            final permiso = permisos[i];
            permissionItems.add(
              ListTile(
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
              ),
            );
            
            // Añadimos el separador si no es el último elemento
            if (i < permisos.length - 1) {
              permissionItems.add(const Divider(color: Colors.white24));
            }
          }
          
          // Calculamos altura aproximada del contenido
          final itemHeight = 90.0; // Altura estimada de cada item de permiso
          final dividerHeight = 16.0;
          // Altura total: cada item + cada divisor (excepto el último) 
          final totalContentHeight = (permisos.length * itemHeight) + 
              ((permisos.length - 1) * dividerHeight);
          
          // Determinamos si se necesita scroll
          final needsScroll = totalContentHeight > constraints.maxHeight;
          
          return SingleChildScrollView(
            // Física de scroll condicional
            physics: needsScroll
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(children: permissionItems),
            ),
          );
        },
      ),
    );
  }
}
