// lib/screens/settingsScreen.dart
import 'package:app/screens/splash_screen.dart';
import 'package:app/screens/suscripciones_pagos_screen.dart';
import 'package:app/screens/premium_purchase_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              Icon(Icons.exit_to_app, size: 48, color: Colors.redAccent),
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
                        backgroundColor: Colors.redAccent,
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
      Provider.of<AuthProvider>(context, listen: false).logoutUser();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Contamos cuántas opciones totales hay
    const int totalOptions =
        4 /* Cuenta */ + 5 /* Preferencias */ + 1 /* Acerca de */;
    // Altura estimada por ListTile + Divider
    const double optionHeight = 72.0;
    final double totalContentHeight = totalOptions * optionHeight;

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
          final bool needsScroll = totalContentHeight > constraints.maxHeight;
          return SingleChildScrollView(
            physics: needsScroll
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Sección: Cuenta ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      tr("account"),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildOptionTile(context, tr("my_matches"), Icons.favorite),
                  _buildOptionTile(context, tr("identity_verification"),
                      Icons.verified_user),
                  _buildOptionTile(context, tr("security"), Icons.security),
                  _buildOptionTile(context, tr("logout"), Icons.logout,
                      titleColor: Colors.redAccent,
                      iconColor: Colors.redAccent),

                  const SizedBox(height: 24),

                  // --- Sección: Preferencias ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      tr("preferences"),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildOptionTile(
                      context, tr("notifications"), Icons.notifications),
                  _buildOptionTile(context, tr("languages"), Icons.language),
                  _buildOptionTile(
                      context, tr("subscriptions_payments"), Icons.payment),
                  _buildOptionTile(
                      context, tr("promo_code"), Icons.card_giftcard),
                  _buildOptionTile(context, tr("app_permissions"), Icons.apps),

                  const SizedBox(height: 24),

                  // --- Sección: Acerca de ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      tr("about"),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildOptionTile(context, tr("about"), Icons.info),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    String title,
    IconData icon, {
    Color titleColor = Colors.white,
    Color iconColor = Colors.white,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: iconColor.withOpacity(0.87)),
          title: Text(title, style: TextStyle(color: titleColor)),
          trailing:
              Icon(Icons.chevron_right, color: iconColor.withOpacity(0.87)),
          onTap: () => _optionSelected(context, title),
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        const Divider(color: Colors.white24, thickness: 1, height: 1),
      ],
    );
  }
}

/// PANTALLA DE NOTIFICACIONES
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
  final _fcm = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final token = await Provider.of<AuthProvider>(context, listen: false).getToken();
    if (token == null) return;
    final result = await UserService(token: token).getNotificationSettings();
    setState(() {
      if (result['success'] == true) {
        _notificarMatches = result['settings']['matches'] as bool;
        _notificarMensajes = result['settings']['messages'] as bool;
        _notificarLikes = result['settings']['likes'] as bool;
      }
      _loading = false;
    });
    // Sincronizar topics FCM
    _updateSubscription('new_matches', _notificarMatches);
    _updateSubscription('messages', _notificarMensajes);
    _updateSubscription('new_likes', _notificarLikes);
  }

  Future<void> _toggleOption(String key, bool newValue) async {
    HapticFeedback.selectionClick();
    setState(() {
      switch (key) {
        case 'matches':
          _notificarMatches = newValue;
          break;
        case 'messages':
          _notificarMensajes = newValue;
          break;
        case 'likes':
          _notificarLikes = newValue;
          break;
      }
    });
    final token = await Provider.of<AuthProvider>(context, listen: false).getToken();
    if (token != null) {
      await UserService(token: token).setNotificationSetting(key, newValue);
    }
    final topic = {
      'matches': 'new_matches',
      'messages': 'messages',
      'likes': 'new_likes',
    }[key]!;
    _updateSubscription(topic, newValue);
  }

  void _updateSubscription(String topic, bool subscribe) {
    if (subscribe) _fcm.subscribeToTopic(topic);
    else _fcm.unsubscribeFromTopic(topic);
  }

  Widget _buildCardOption({
    required IconData icon,
    required String labelKey,
    required bool value,
    required VoidCallback onTap,
  }) {
    final colorOn = Colors.blueAccent.withOpacity(0.15);
    final colorOff = const Color(0xFF2C2C2C);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value ? colorOn : colorOff,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                tr(labelKey),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            Switch(
              value: value,
              activeColor: Colors.blueAccent,
              inactiveThumbColor: Colors.white54,
              inactiveTrackColor: Colors.white24,
              onChanged: (_) => onTap(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color.fromRGBO(20, 20, 20, 1),
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    final options = [
      {
        'icon': Icons.favorite,
        'key': 'matches',
        'label': 'notify_new_matches',
        'value': _notificarMatches,
      },
      {
        'icon': Icons.message,
        'key': 'messages',
        'label': 'notify_messages',
        'value': _notificarMensajes,
      },
      {
        'icon': Icons.thumb_up,
        'key': 'likes',
        'label': 'notify_likes',
        'value': _notificarLikes,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr("notifications"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.blueAccent),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cards = options.map((opt) {
            return _buildCardOption(
              icon: opt['icon'] as IconData,
              labelKey: opt['label'] as String,
              value: opt['value'] as bool,
              onTap: () => _toggleOption(opt['key'] as String, !(opt['value'] as bool)),
            );
          }).toList();

          // scroll condicional
          const singleCardHeight = 72.0;
          final totalHeight = cards.length * singleCardHeight;
          final needsScroll = totalHeight > constraints.maxHeight;

          return SingleChildScrollView(
            physics: needsScroll
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 16),
                ...cards,
                const SizedBox(height: 24),
              ],
            ),
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
  late String _idiomaSeleccionado;
  late String _idiomaPendiente;

  final List<String> _idiomas = [
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
    _idiomaSeleccionado = {
      'es': 'Español',
      'en': 'English',
      'fr': 'Français',
      'de': 'Deutsch',
      'it': 'Italiano',
    }[code]!;
    _idiomaPendiente = _idiomaSeleccionado;
  }

  void _applyLanguageChange() {
    if (_idiomaPendiente != _idiomaSeleccionado) {
      final newCode = {
        'Español': 'es',
        'English': 'en',
        'Français': 'fr',
        'Deutsch': 'de',
        'Italiano': 'it',
      }[_idiomaPendiente]!;

      context.setLocale(Locale(newCode));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplashScreen()),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Widget _buildOptionCard(String idioma) {
    final isSelected = _idiomaPendiente == idioma;
    return InkWell(
      onTap: () => setState(() => _idiomaPendiente = idioma),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white12 : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white24,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                idioma.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("languages"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final optionCards = _idiomas.map(_buildOptionCard).toList();

          // Calcula si necesita scroll (deja 72px para el botón)
          const itemHeight = 56.0;
          final totalHeight = optionCards.length * itemHeight;
          final needsScroll = totalHeight > constraints.maxHeight - 72;

          final list = Column(children: optionCards);

          return SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: 72,
                  child: needsScroll
                      ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: list,
                  )
                      : list,
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: ElevatedButton(
                    onPressed: _applyLanguageChange,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      tr("save"),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                )
              ],
            ),
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
