// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class AuthService {
  final String baseUrl = 'http://10.0.2.2:5000/api/users';
  final FlutterSecureStorage storage = FlutterSecureStorage();

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
    final url = Uri.parse('$baseUrl/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'seeking': seeking,
        'relationshipGoal': relationshipGoal,
      }),
    );

    if (response.statusCode == 201) {
      return {'success': true, 'message': 'Usuario registrado con éxito'};
    }

    final data = jsonDecode(response.body);
    return {
      'success': false,
      'message': data['message'] ?? 'Error al registrar usuario',
    };
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await storage.write(key: 'token', value: data['token']);
      return {
        'success': true,
        'user': User.fromJson(data['user']),
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Error al iniciar sesión',
      };
    }
  }

  Future<void> logout() async {
    await storage.delete(key: 'token');
  }

  Future<String?> getToken() async {
    return await storage.read(key: 'token');
  }

  // Método para obtener datos del usuario usando el token
  Future<User?> fetchUserData(String token) async {
    final url = Uri.parse('$baseUrl/profile');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data['user']);
    } else {
      return null;
    }
  }
}
