import 'dart:convert';
import 'package:http/http.dart' as http;

class MatchService {
  final String token;
  final String baseUrl = 'https://gymder-api-production.up.railway.app/api';
  MatchService({required this.token});

  Future<Map<String, dynamic>> getSuggestedMatchesWithFilters(
      Map<String, String> filters) async {
    final uri = Uri.parse('$baseUrl/matches/suggested')
        .replace(queryParameters: filters);
    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    });
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateSeenProfiles(List<String> seenIds) async {
    final url = Uri.parse('$baseUrl/matches/seen');
    final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({'seen': seenIds}));
    return jsonDecode(response.body);
  }
  
  // Método para actualizar el contador de scroll y obtener el estado del límite
  Future<Map<String, dynamic>> updateScrollCount(String? scrollLimitProfileId) async {
    final url = Uri.parse('$baseUrl/users/scroll/update');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        'scrollLimitProfileId': scrollLimitProfileId,
      }),
    );
    return jsonDecode(response.body);
  }
  
  // Método para obtener el estado actual del límite de scroll
  Future<Map<String, dynamic>> getScrollLimitStatus() async {
    final url = Uri.parse('$baseUrl/users/scroll/limit-status');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );
    return jsonDecode(response.body);
  }
}
