import 'dart:convert';
import 'package:http/http.dart' as http;

class RoutineService {
  final String token;
  final String baseUrl = 'https://gymder-api-production.up.railway.app/api';

  RoutineService({required this.token});

  // Obtener todas las rutinas del usuario
  Future<Map<String, dynamic>> getUserRoutines() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/routines'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al obtener rutinas: $e',
      };
    }
  }

  // Crear una nueva rutina
  Future<Map<String, dynamic>> createRoutine(
      String name, List<Map<String, dynamic>> exercises) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/routines'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': name,
          'exercises': exercises,
        }),
      );

      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al crear rutina: $e',
      };
    }
  }

  // Obtener una rutina específica
  Future<Map<String, dynamic>> getRoutineById(String routineId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/routines/$routineId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al obtener rutina: $e',
      };
    }
  }

  // Actualizar una rutina
  Future<Map<String, dynamic>> updateRoutine(
      String routineId, String name, List<Map<String, dynamic>> exercises) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/routines/$routineId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': name,
          'exercises': exercises,
        }),
      );

      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al actualizar rutina: $e',
      };
    }
  }

  // Eliminar una rutina
  Future<Map<String, dynamic>> deleteRoutine(String routineId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/routines/$routineId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al eliminar rutina: $e',
      };
    }
  }
}
