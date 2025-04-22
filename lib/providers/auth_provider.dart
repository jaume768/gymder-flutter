// lib/providers/auth_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  Map<String, String> _fieldErrors = {};

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  Map<String, String> get fieldErrors => _fieldErrors;

  void clearFieldErrors() {
    _fieldErrors = {};
    notifyListeners();
  }

  String? getFieldError(String fieldName) {
    return _fieldErrors[fieldName];
  }

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
    _fieldErrors = {};
    final result = await _authService.login(email: email, password: password);

    if (result['success'] == true) {
      _user = result['user'];
      _isAuthenticated = true;
      notifyListeners();
      // Vuelve a cargar datos de usuario (por si hay info extra)
      await refreshUser();
    } else {
      // Procesar errores específicos de campos
      _processFieldErrors(result);
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
    int? age,
    double? height,
    double? weight,
    String? gymStage,
    double? squatWeight,
    double? benchPressWeight,
    double? deadliftWeight,
    double? latitude,
    double? longitude,
  }) async {
    _fieldErrors = {};
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
        age: age,
        height: height,
        weight: weight,
        gymStage: gymStage,
        squatWeight: squatWeight,
        benchPressWeight: benchPressWeight,
        deadliftWeight: deadliftWeight,
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
              'message': tr('error_invalid_token_or_user'),
            };
          }
        }
        return result; // { success: true, message, token, user }
      } else {
        // Procesar errores específicos de campos
        _processFieldErrors(result);
        
        return {
          'success': false,
          'message': result['message'] ?? tr('error_register'),
          'fieldErrors': _fieldErrors,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '${tr('connection_error')}: $e',
      };
    }
  }

  // Procesa errores específicos de campos que vienen del backend
  void _processFieldErrors(Map<String, dynamic> result) {
    if (result.containsKey('fieldErrors') && result['fieldErrors'] != null) {
      Map<String, dynamic> fieldErrors = result['fieldErrors'];
      
      fieldErrors.forEach((key, value) {
        _fieldErrors[key] = value.toString();
      });
      
      notifyListeners();
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
      
      if (response.statusCode != 200) {
        final apiError = ApiError.fromResponse(response);
        return {'success': false, 'message': apiError.message};
      }
      
      final data = jsonDecode(response.body);
      
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
    } catch (e) {
      final apiError = ApiError.network(e.toString());
      return {'success': false, 'message': apiError.message};
    }
  }

  // Cerrar sesión
  Future<void> logoutUser() async {
    await _authService.logout();
    _user = null;
    _isAuthenticated = false;
    _fieldErrors = {};
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
