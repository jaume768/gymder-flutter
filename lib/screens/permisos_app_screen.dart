// lib/screens/permisos_app_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:easy_localization/easy_localization.dart';

class PermisosAppScreen extends StatelessWidget {
  const PermisosAppScreen({Key? key}) : super(key: key);

  Future<void> _openAppSettings() async {
    // Abre la configuración de la aplicación en el dispositivo.
    bool opened = await openAppSettings();
    if (!opened) {
      // Si no se pudo abrir, muestra un mensaje en el log
      debugPrint(tr("cannot_open_app_settings"));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> permisos = [
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
        title: Text(
          tr("app_permissions"),
          style: const TextStyle(color: Colors.white),
        ),
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
            title: Text(
              permiso["title"]!,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              permiso["description"]!,
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: ElevatedButton(
              onPressed: _openAppSettings,
              child: Text(tr("modify")),
            ),
          );
        },
      ),
    );
  }
}
