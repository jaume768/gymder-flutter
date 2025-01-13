import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  bool isLoading = false;
  String errorMessage = '';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
    ],
    serverClientId:
        '559547590565-fglo48susn9evd2607gklgti1s8eo1vb.apps.googleusercontent.com',
  );

  Future<void> _handleGoogleSignIn() async {
    // 1) Arrancas la animación de carga
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          errorMessage = 'No se recibió idToken.';
        });
        return;
      }

      final result = await Provider.of<AuthProvider>(context, listen: false)
          .loginWithGoogle(idToken);

      if (!mounted) return;
      if (!result['success']) {
        setState(() {
          isLoading = false;
          errorMessage =
              result['message'] ?? 'Error al iniciar sesión con Google';
        });
        return;
      }

      final isNewAccount = result['newAccount'] ?? false;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshUser();

      if (!mounted) return;

      if (isNewAccount) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const RegisterScreen(fromGoogle: true)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Error al iniciar sesión con Google: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(64, 65, 65, 1), // Fondo gris
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/logo.png',
                  height: 220,
                ),
                const SizedBox(height: 40),
                // Título
                const Text(
                  'Iniciar Sesión',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Formulario
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Correo Electrónico
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Correo o Nombre de usuario',
                          labelStyle: const TextStyle(color: Colors.white),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white54),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          errorStyle: const TextStyle(color: Colors.redAccent),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresa tu correo o nombre de usuario';
                          }
                          return null;
                        },
                        onSaved: (value) => email = value!,
                        cursorColor: Colors.white,
                      ),
                      const SizedBox(height: 20),
                      // Contraseña
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: const TextStyle(color: Colors.white),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white54),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          errorStyle: const TextStyle(color: Colors.redAccent),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresa tu contraseña';
                          }
                          if (value.length < 6) {
                            return 'La contraseña debe tener al menos 6 caracteres';
                          }
                          return null;
                        },
                        onSaved: (value) => password = value!,
                        cursorColor: Colors.white,
                      ),
                      const SizedBox(height: 30),
                      // Botón de Iniciar Sesión
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    _formKey.currentState!.save();
                                    setState(() {
                                      isLoading = true;
                                      errorMessage = '';
                                    });
                                    final result = await authProvider.login(
                                      email: email,
                                      password: password,
                                    );
                                    setState(() {
                                      isLoading = false;
                                    });
                                    if (result['success']) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const HomeScreen(),
                                        ),
                                      );
                                    } else {
                                      setState(() {
                                        errorMessage = result['message'] ??
                                            'Error al iniciar sesión';
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white, // Fondo blanco
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black),
                                )
                              : const Text(
                                  'Iniciar Sesión',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Botón Iniciar Sesión con Google
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: Image.asset(
                            'assets/images/google_logo.png', // O un icon de Google
                            height: 24,
                            width: 24,
                          ),
                          label: const Text(
                            'Inicia Sesión con Google',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  await _handleGoogleSignIn();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white, // Botón blanco
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),
                      // Mensaje de Error
                      if (errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Opción para Registrarse
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '¿No tienes una cuenta?',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Regístrate',
                              style: TextStyle(
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
