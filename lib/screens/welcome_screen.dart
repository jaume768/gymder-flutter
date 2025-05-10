// lib/screens/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lista de idiomas soportados
    const locales = [
      Locale('es'),
      Locale('en'),
      Locale('fr'),
      Locale('de'),
      Locale('it'),
    ];

    // Nombre para cada locale
    String localeName(Locale l) {
      switch (l.languageCode) {
        case 'es':
          return 'Español';
        case 'en':
          return 'English';
        case 'fr':
          return 'Français';
        case 'de':
          return 'Deutsch';
        case 'it':
          return 'Italiano';
        default:
          return l.languageCode;
      }
    }

    final current = context.locale;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Fondo con imagen ---
          Image.asset(
            'assets/images/welcome_bg.jpg',
            fit: BoxFit.cover,
          ),

          // --- Overlay semitransparente con degradado ---
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // --- Logo en la esquina superior izquierda ---
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0,top: 10.0),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 48,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // --- Selector de idioma en la esquina superior derecha ---
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0,top: 10.0),
                child: PopupMenuButton<Locale>(
                  icon: const Icon(Icons.public, color: Colors.white, size: 24),
                  tooltip: tr('select_language'),
                  onSelected: (locale) {
                    HapticFeedback.lightImpact();
                    context.setLocale(locale);
                  },
                  color: const Color(0xFF1E1E28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (_) => locales.map((locale) {
                    final selected = locale == current;
                    return PopupMenuItem<Locale>(
                      value: locale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        decoration: BoxDecoration(
                          color: selected ? Colors.blue : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          localeName(locale),
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // --- Contenido principal (título, tagline, CTAs) ---
          Column(
            children: [
              const Spacer(),

              // Título
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    tr('GymSwipe'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tagline
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    tr('banner_text'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Botón primario: Crear cuenta
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      tr('create_account').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botón secundario: Iniciar sesión
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                ),
                child: Text(
                  tr('log_in').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }
}
