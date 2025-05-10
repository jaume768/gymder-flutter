import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../providers/auth_provider.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';

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
  bool _obscurePassword = true;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId:
        '559547590565-fglo48susn9evd2607gklgti1s8eo1vb.apps.googleusercontent.com',
  );

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Usuario canceló el flujo
        setState(() => isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        setState(() {
          isLoading = false;
          errorMessage = "no_id_token".tr();
        });
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.loginWithGoogle(idToken);

      setState(() {
        isLoading = false;
      });

      if (!(result['success'] as bool)) {
        setState(() =>
            errorMessage = result['message'] ?? "error_google_signin".tr());
        return;
      }

      final bool isNewAccount = result['newAccount'] as bool;
      if (isNewAccount) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RegisterScreen(fromGoogle: true),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(fromGoogle: false),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "error_google_signin".tr(args: [e.toString()]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final brandColor =
        Theme.of(context).colorScheme.secondary; // ajuste tu color de marca

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- Logo ---
                Image.asset(
                  'assets/images/logo.png',
                  height: 230,
                  fit: BoxFit.contain,
                ),

                // --- Título ---
                Text(
                  "login_title"
                      .tr(), // traducido como "Iniciar sesión en GymSwipe"
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                // --- Formulario ---
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email / usuario
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "email_or_username".tr(),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white54),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: brandColor, width: 2),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          errorStyle: const TextStyle(color: Colors.redAccent),
                        ),
                        cursorColor: brandColor,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "please_enter_email_or_username".tr();
                          }
                          return null;
                        },
                        onSaved: (value) => email = value!.trim(),
                      ),
                      const SizedBox(height: 16),

                      // Contraseña
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "password".tr(),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white54),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: brandColor, width: 2),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          errorStyle: const TextStyle(color: Colors.redAccent),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white54,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        cursorColor: brandColor,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "please_enter_password".tr();
                          }
                          if (value.length < 6) {
                            return "password_min_length".tr();
                          }
                          return null;
                        },
                        onSaved: (value) => password = value!,
                      ),
                      const SizedBox(height: 24),

                      // --- Botón primario: Iniciar sesión ---
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
                                    if (result['success'] == true) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const HomeScreen(
                                              fromGoogle: false),
                                        ),
                                      );
                                    } else {
                                      setState(() {
                                        errorMessage = result['message'] ??
                                            "error_login".tr();
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            elevation: 4,
                          ),
                          child: isLoading
                              ? CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                )
                              : Text(
                                  "login".tr(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (!Platform.isIOS)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            icon: Image.asset(
                              'assets/images/google_logo.png',
                              height: 24,
                              width: 24,
                            ),
                            label: Text(
                              "login_with_google".tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: isLoading ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                        ),

                      // --- Mensaje de error general ---
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),

                      // --- Enlaces secundarios ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "dont_have_account".tr(),
                            style: const TextStyle(color: Colors.white),
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
                            style: TextButton.styleFrom(
                              minimumSize: const Size(50, 48),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                            ),
                            child: Text(
                              "register".tr(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(50, 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                        ),
                        child: Text(
                          'forgot_password'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
