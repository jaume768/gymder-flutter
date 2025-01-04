// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isAuthenticated = false;
  bool _isLoading = true;

  User? get user => _user;
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
      // Opcional: Puedes llamar a refreshUser aquí para obtener datos completos
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
    return result;
  }

  Future<void> logoutUser() async {
    await _authService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  // Método público para obtener el token
  Future<String?> getToken() async {
    return await _authService.getToken();
  }

  // Método para refrescar los datos del usuario
  Future<void> refreshUser() async {
    String? token = await _authService.getToken();
    if (token != null) {
      _user = await _authService.fetchUserData(token);
      notifyListeners();
    }
  }
}
