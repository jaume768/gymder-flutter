// lib/services/match_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class MatchService {
  final String baseUrl = 'http://10.0.2.2:5000/api/matches';
  final String token;

  MatchService({required this.token});

  Future<Map<String, dynamic>> getSuggestedMatches() async {
    final url = Uri.parse('$baseUrl/suggested');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<User> matches = List<User>.from(data['matches'].map((x) => User.fromJson(x)));
      return {'success': true, 'matches': data['matches']};
    } else {
      final data = jsonDecode(response.body);
      return {'success': false, 'message': data['message'] ?? 'Error al obtener matches'};
    }
  }
}
