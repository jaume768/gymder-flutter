import 'package:flutter/material.dart';

/// -----------------------
/// PANTALLA PRINCIPAL DE AJUSTES
/// -----------------------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  // Función para navegar según la opción seleccionada.
  void _optionSelected(BuildContext context, String option) {
    switch (option) {
      case "Notificaciones":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
        break;
      case "Idiomas":
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const IdiomasScreen()));
        break;
      case "Suscripciones y Pagos":
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const SuscripcionesPagosScreen()));
        break;
      case "Seguridad":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SeguridadScreen()));
        break;
      case "Permisos de la Aplicación":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PermisosAppScreen()));
        break;
      case "Acerca de":
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AcercaDeScreen()));
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

  Future<void> _confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar"),
        content: const Text("¿Estás seguro que deseas cerrar sesión?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Cerrar sesión"),
          ),
        ],
      ),
    );

    if (result == true) {
      // Aquí debes implementar el logout, por ejemplo:
      // Provider.of<AuthProvider>(context, listen: false).logoutUser();
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> options = [
      {"title": "Notificaciones", "icon": Icons.notifications},
      {"title": "Idiomas", "icon": Icons.language},
      {"title": "Suscripciones y Pagos", "icon": Icons.payment},
      {"title": "Seguridad", "icon": Icons.security},
      {"title": "Permisos de la Aplicación", "icon": Icons.apps},
      {"title": "Acerca de", "icon": Icons.info},
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

/// -----------------------
/// PANTALLA DE NOTIFICACIONES
/// -----------------------
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({Key? key}) : super(key: key);

  @override
  _NotificacionesScreenState createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  bool notificarMatches = true;
  bool notificarMensajes = true;
  bool notificarLikes = true;
  bool agruparNotificaciones = false;

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
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Notificar nuevos matches",
                style: TextStyle(color: Colors.white)),
            value: notificarMatches,
            onChanged: (val) {
              setState(() => notificarMatches = val);
              // Aquí puedes llamar a un API para guardar la configuración.
            },
          ),
          SwitchListTile(
            title: const Text("Notificar mensajes",
                style: TextStyle(color: Colors.white)),
            value: notificarMensajes,
            onChanged: (val) {
              setState(() => notificarMensajes = val);
            },
          ),
          SwitchListTile(
            title: const Text("Notificar likes",
                style: TextStyle(color: Colors.white)),
            value: notificarLikes,
            onChanged: (val) {
              setState(() => notificarLikes = val);
            },
          ),
          SwitchListTile(
            title: const Text("Agrupar notificaciones",
                style: TextStyle(color: Colors.white)),
            value: agruparNotificaciones,
            onChanged: (val) {
              setState(() => agruparNotificaciones = val);
            },
          ),
        ],
      ),
    );
  }
}

/// -----------------------
/// PANTALLA DE IDIOMAS
/// -----------------------
class IdiomasScreen extends StatefulWidget {
  const IdiomasScreen({Key? key}) : super(key: key);

  @override
  _IdiomasScreenState createState() => _IdiomasScreenState();
}

class _IdiomasScreenState extends State<IdiomasScreen> {
  String idiomaSeleccionado = "Español";
  final List<String> idiomas = ["Español", "Inglés"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Idiomas", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: ListView(
        children: idiomas
            .map((idioma) => RadioListTile(
                  title:
                      Text(idioma, style: const TextStyle(color: Colors.white)),
                  value: idioma,
                  groupValue: idiomaSeleccionado,
                  onChanged: (String? value) {
                    setState(() {
                      idiomaSeleccionado = value!;
                    });
                  },
                ))
            .toList(),
      ),
    );
  }
}

/// -----------------------
/// PANTALLA DE SUSCRIPCIONES Y PAGOS
/// -----------------------
class SuscripcionesPagosScreen extends StatelessWidget {
  const SuscripcionesPagosScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Estos valores deberían provenir de la información del usuario.
    bool esPremium = false;
    String fechaExpiracion = "30/09/2023";
    return Scaffold(
      appBar: AppBar(
        title: const Text("Suscripciones y Pagos",
            style: TextStyle(color: Colors.white)),
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
                  esPremium ? "Eres usuario Premium" : "Usuario estándar",
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: esPremium
                    ? Text("Expira el: $fechaExpiracion",
                        style: const TextStyle(color: Colors.white70))
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            if (!esPremium)
              ElevatedButton(
                onPressed: () {
                  // Navega a la pantalla de compra premium.
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PremiumPurchasePage()));
                },
                child: const Text("Hazte Premium"),
              ),
            if (esPremium)
              ElevatedButton(
                onPressed: () {
                  // Acción para cancelar suscripción.
                },
                child: const Text("Cancelar suscripción"),
              ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------
/// PANTALLA DE SEGURIDAD
/// -----------------------
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
    setState(() {
      isUpdating = true;
      updateMessage = '';
    });
    // Simula una llamada a la API para cambiar la contraseña.
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      isUpdating = false;
      updateMessage = 'Contraseña actualizada exitosamente';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seguridad", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Cambiar Contraseña",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Contraseña actual",
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
                labelText: "Nueva contraseña",
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
                labelText: "Confirmar nueva contraseña",
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isUpdating ? null : _changePassword,
              child: isUpdating
                  ? const CircularProgressIndicator()
                  : const Text("Actualizar Contraseña"),
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

/// -----------------------
/// PANTALLA DE PERMISOS DE LA APLICACIÓN
/// -----------------------
class PermisosAppScreen extends StatelessWidget {
  const PermisosAppScreen({Key? key}) : super(key: key);

  void _openAppSettings() {
    // Aquí puedes utilizar el paquete permission_handler para abrir la configuración de la app.
    // Ejemplo: openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> permisos = [
      {
        "title": "Ubicación",
        "description": "Para encontrar coincidencias cercanas"
      },
      {
        "title": "Cámara",
        "description": "Para subir fotos de perfil y adicionales"
      },
      {
        "title": "Almacenamiento",
        "description": "Para guardar fotos en el dispositivo"
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Permisos de la Aplicación",
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: ListView.separated(
        itemCount: permisos.length,
        separatorBuilder: (context, index) =>
            const Divider(color: Colors.white24),
        itemBuilder: (context, index) {
          final permiso = permisos[index];
          return ListTile(
            leading: const Icon(Icons.info, color: Colors.white70),
            title: Text(permiso["title"]!,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text(permiso["description"]!,
                style: const TextStyle(color: Colors.white70)),
            trailing: ElevatedButton(
              onPressed: _openAppSettings,
              child: const Text("Modificar"),
            ),
          );
        },
      ),
    );
  }
}

/// -----------------------
/// PANTALLA ACERCA DE
/// -----------------------
class AcercaDeScreen extends StatelessWidget {
  const AcercaDeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Acerca de", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Gymder",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Versión 1.0.0",
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            SizedBox(height: 20),
            Text("Desarrollado por:",
                style: TextStyle(color: Colors.white, fontSize: 18)),
            Text("Tu Nombre o Empresa",
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            SizedBox(height: 20),
            Text("Contacto:",
                style: TextStyle(color: Colors.white, fontSize: 18)),
            Text("correo@ejemplo.com",
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            SizedBox(height: 20),
            Text("Términos y Condiciones",
                style: TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                    decoration: TextDecoration.underline)),
            SizedBox(height: 10),
            Text("Política de Privacidad",
                style: TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                    decoration: TextDecoration.underline)),
          ],
        ),
      ),
    );
  }
}

/// -----------------------
/// PLACEHOLDER PARA PREMIUM PURCHASE
/// (Este widget es un ejemplo; en tu proyecto ya cuentas con la implementación)
/// -----------------------
class PremiumPurchasePage extends StatelessWidget {
  const PremiumPurchasePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("Hazte Premium", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: const Center(
        child: Text("Pantalla de compra Premium",
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
