// lib/providers/auth_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'package:http/http.dart' as http;

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = true;

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    String? token = await _authService.getToken();
    if (token != null) {
      _user = await _authService.fetchUserData(token);
      if (_user != null) {
        _isAuthenticated = true;
      } else {
        _isAuthenticated = false;
        await _authService.logout();
      }
    } else {
      _isAuthenticated = false;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = await _authService.login(email: email, password: password);
    if (result['success']) {
      _user = result['user'];
      _isAuthenticated = true;
      notifyListeners();
      await refreshUser();
    }
    return result;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
    required String gender,
    required List<String> seeking,
    required String relationshipGoal,
  }) async {
    try {
      // Delegar a authService:
      final result = await _authService.register(
        email: email,
        password: password,
        username: username,
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        seeking: seeking,
        relationshipGoal: relationshipGoal,
      );

      if (result['success'] == true) {
        final token = result['token'];
        if (token != null) {
          // Podrías actualizar _token en AuthProvider
          _token = token;

          // Intentar obtener datos del usuario
          final userData = await _authService.fetchUserData(token);
          if (userData != null) {
            _user = userData;
            _isAuthenticated = true;
            notifyListeners();
          } else {
            // Si falló la carga de datos de usuario
            _isAuthenticated = false;
            _token = null;
            // O borras el token en storage si quieres
            await _authService.logout();
            notifyListeners();
            return {
              'success': false,
              'message':
                  'Error: token inválido o usuario no encontrado. Por favor, inicia sesión.'
            };
          }
        }
        return result; // devuelves { success: true, message, token, user }
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Error al registrar',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle(String googleIdToken) async {
    try {
      final url = Uri.parse('http://10.0.2.2:5000/api/users/auth/google');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': googleIdToken}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Guardamos token en SecureStorage
        await _authService.storage.write(key: 'token', value: data['token']);

        // Actualizamos user en Provider
        _user = User.fromJson(data['user']);
        _isAuthenticated = true;
        notifyListeners();

        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<void> logoutUser() async {
    await _authService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<String?> getToken() async {
    return await _authService.getToken();
  }

  Future<void> refreshUser() async {
    String? token = await _authService.getToken();
    if (token != null) {
      _user = await _authService.fetchUserData(token);
      notifyListeners();
    }
  }
}
