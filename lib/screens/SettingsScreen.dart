import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

/// Pantalla de Notificaciones
class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("Notificaciones", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: const Center(
        child: Text(
          "Configuración de Notificaciones",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}

/// Pantalla de Privacidad
class PrivacidadScreen extends StatelessWidget {
  const PrivacidadScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacidad", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: const Center(
        child: Text(
          "Configuración de Privacidad",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}

/// Pantalla de Idiomas
class IdiomasScreen extends StatelessWidget {
  const IdiomasScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Idiomas", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: const Center(
        child: Text(
          "Configuración de Idiomas",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}

/// Pantalla de Suscripciones y Pagos
class SuscripcionesPagosScreen extends StatelessWidget {
  const SuscripcionesPagosScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Suscripciones y Pagos",
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: const Center(
        child: Text(
          "Opciones de Suscripciones y Pagos",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}

/// Pantalla de Seguridad
class SeguridadScreen extends StatelessWidget {
  const SeguridadScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seguridad", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: const Center(
        child: Text(
          "Configuración de Seguridad",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}

/// Pantalla de Permisos de la Aplicación
class PermisosAppScreen extends StatelessWidget {
  const PermisosAppScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Permisos de la aplicación",
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: const Center(
        child: Text(
          "Configuración de Permisos",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}

/// Pantalla de Ajustes (SettingsScreen)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  Future<void> _confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Estás seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (result == true) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logoutUser();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _optionSelected(BuildContext context, String option) {
    switch (option) {
      case "Notificaciones":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
        );
        break;
      case "Privacidad":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrivacidadScreen()),
        );
        break;
      case "Idiomas":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IdiomasScreen()),
        );
        break;
      case "Suscripciones y pagos":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SuscripcionesPagosScreen()),
        );
        break;
      case "Seguridad":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SeguridadScreen()),
        );
        break;
      case "Permisos de la aplicación":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PermisosAppScreen()),
        );
        break;
      case "Cerrar sesión":
        _confirmLogout(context);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Seleccionaste: $option")),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> options = [
      {"title": "Notificaciones", "icon": Icons.notifications},
      {"title": "Privacidad", "icon": Icons.lock},
      {"title": "Idiomas", "icon": Icons.language},
      {"title": "Suscripciones y pagos", "icon": Icons.payment},
      {"title": "Seguridad", "icon": Icons.security},
      {"title": "Permisos de la aplicación", "icon": Icons.apps},
      {"title": "Cerrar sesión", "icon": Icons.logout},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ajustes", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: ListView.separated(
        itemCount: options.length,
        separatorBuilder: (context, index) =>
            const Divider(color: Colors.white24),
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
