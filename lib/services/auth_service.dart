// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class AuthService {
  final String baseUrl = 'https://gymder-api-production.up.railway.app/api/users';
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
    double? height,
    double? weight,
    String? gymStage,
    double? latitude,
    double? longitude,
  }) async {
    final url = Uri.parse('$baseUrl/register');

    final bodyData = {
      'email': email,
      'password': password,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'seeking': seeking,
      'relationshipGoal': relationshipGoal,
      'height': height,
      'weight': weight,
      'goal': gymStage,
    };

    if (latitude != null && longitude != null) {
      bodyData['location'] = {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      };
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyData),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      final token = data['token'];
      if (token != null) {
        // Guardar en secure storage
        await storage.write(key: 'token', value: token);
      }
      return {
        'success': true,
        'message': data['message'],
        'token': token,
        'user': data['user'], // si devuelves user
      };
    }

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
