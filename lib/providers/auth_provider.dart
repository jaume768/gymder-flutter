// lib/providers/auth_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import '../services/auth_service.dart';

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

  // Verifica si hay token en storage y obtiene datos de usuario
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

  // Iniciar sesión normal (email + password)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = await _authService.login(email: email, password: password);

    if (result['success'] == true) {
      _user = result['user'];
      _isAuthenticated = true;
      notifyListeners();
      // Vuelve a cargar datos de usuario (por si hay info extra)
      await refreshUser();
    }
    return result;
  }

  // Registrar usuario
  // Agregamos latitude/longitude opcionales para mandar ubicación
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
    required String gender,
    required List<String> seeking,
    required String relationshipGoal,
    double? height,
    double? weight,
    String? gymStage,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // Llamamos a AuthService.register y le pasamos la ubicación
      final result = await _authService.register(
        email: email,
        password: password,
        username: username,
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        seeking: seeking,
        relationshipGoal: relationshipGoal,
        height: height,
        weight: weight,
        gymStage: gymStage,
        latitude: latitude,
        longitude: longitude,
      );

      if (result['success'] == true) {
        final token = result['token'];
        if (token != null) {
          _token = token;

          // Obtenemos datos de usuario con el token guardado
          final userData = await _authService.fetchUserData(token);
          if (userData != null) {
            _user = userData;
            _isAuthenticated = true;
            notifyListeners();
          } else {
            // Si no se pudo obtener la info del usuario, forzamos logout
            _isAuthenticated = false;
            _token = null;
            await _authService.logout();
            notifyListeners();
            return {
              'success': false,
              'message':
              'Error: token inválido o usuario no encontrado. Por favor, inicia sesión.'
            };
          }
        }
        return result; // { success: true, message, token, user }
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

  // Login con Google
  Future<Map<String, dynamic>> loginWithGoogle(String googleIdToken) async {
    try {
      final url = Uri.parse(
          'https://gymder-api-production.up.railway.app/api/users/auth/google');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': googleIdToken}),
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Guardar el token en SecureStorage
        await _authService.storage.write(key: 'token', value: data['token']);

        // Actualizar usuario en el AuthProvider
        _user = User.fromJson(data['user']);
        _isAuthenticated = true;
        notifyListeners();

        // Retornamos también si es newAccount
        return {
          'success': true,
          'message': data['message'],
          'newAccount': data['newAccount'] ?? false,
        };
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // Cerrar sesión
  Future<void> logoutUser() async {
    await _authService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  // Obtener token directamente desde el storage
  Future<String?> getToken() async {
    return await _authService.getToken();
  }

  // Refrescar datos de usuario (cuando cambian)
  Future<void> refreshUser() async {
    String? token = await _authService.getToken();
    if (token != null) {
      _user = await _authService.fetchUserData(token);
      notifyListeners();
    }
  }
}
