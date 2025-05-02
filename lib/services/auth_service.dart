// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../utils/error_handler.dart';
import 'package:easy_localization/easy_localization.dart';

class AuthService {
  final String baseUrl =
      'https://gymder-api-production.up.railway.app/api/users';
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
    int? age,
    double? height,
    double? weight,
    String? gymStage,
    double? latitude,
    double? longitude,
    double? squatWeight,
    double? benchPressWeight,
    double? deadliftWeight,
    String? promoCode, // Nuevo campo para código promocional
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
      'age': age,
      'height': height,
      'weight': weight,
      'goal': gymStage,
      'squatWeight': squatWeight,
      'benchPressWeight': benchPressWeight,
      'deadliftWeight': deadliftWeight,
      if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
    };

    if (latitude != null && longitude != null) {
      bodyData['location'] = {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      };
    }

    try {
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

      // Procesar el error usando el nuevo sistema de manejo de errores
      final apiError = ApiError.fromResponse(response);
      return {
        'success': false,
        'message': apiError.message,
        'errorType': apiError.type.toString(),
        'fieldErrors': apiError.fieldErrors,
      };
    } catch (e) {
      // Manejar errores de red o conexión
      final apiError = ApiError.network(e.toString());
      return {
        'success': false,
        'message': apiError.message,
        'errorType': apiError.type.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    final url = Uri.parse('$baseUrl/password-reset/request');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      );
      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': tr('connection_error')};
    }
  }

  /// Confirma el código y restablece la contraseña
  Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/password-reset/confirm');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'newPassword': newPassword,
        }),
      );
      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': tr('connection_error')};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');

    try {
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
        // Procesar el error usando el nuevo sistema de manejo de errores
        final apiError = ApiError.fromResponse(response);
        return {
          'success': false,
          'message': apiError.message,
          'errorType': apiError.type.toString(),
          'fieldErrors': apiError.fieldErrors,
        };
      }
    } catch (e) {
      // Manejar errores de red o conexión
      final apiError = ApiError.network(e.toString());
      return {
        'success': false,
        'message': apiError.message,
        'errorType': apiError.type.toString(),
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

    try {
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
        // En caso de error, retornamos null pero podríamos manejar errores específicos
        return null;
      }
    } catch (e) {
      print("Error fetching user data: $e");
      return null;
    }
  }
}
