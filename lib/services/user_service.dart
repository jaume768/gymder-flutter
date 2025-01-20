// lib/services/user_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart'; // Importa el paquete mime
import 'package:http_parser/http_parser.dart'; // Para MediaType
import '../models/user.dart';

class UserService {
  final String baseUrl = 'https://gymder-api-production.up.railway.app/api';
  final String token;

  UserService({required this.token});

  Future<Map<String, dynamic>> updatePhotoOrder(List<String> photoIds) async {
    final url = Uri.parse('$baseUrl/users/order/photos');
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'photoIds': photoIds}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'success': data['success'] ?? true,
        'message': data['message'],
        'photos': data['photos'], // si quieres devolver las fotos actualizadas
      };
    } else {
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Error al actualizar el orden de fotos',
      };
    }
  }

  Future<Map<String, dynamic>> getUserLikes() async {
    final url = Uri.parse('$baseUrl/users/likes');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'success': true,
        'usersWhoLiked': data['usersWhoLiked'],
      };
    } else {
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Error al obtener likes'
      };
    }
  }

  Future<Map<String, dynamic>> subscribePremium() async {
    final url = Uri.parse('$baseUrl/users/subscribe');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'user': User.fromJson(data['user'])};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Error al suscribirse'
      };
    }
  }

  // En user_service.dart
  Future<Map<String, dynamic>> getMatches() async {
    final url = Uri.parse('$baseUrl/matches');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'success': true,
        'matches': data['matches'],
      };
    } else {
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Error al obtener matches'
      };
    }
  }

  Future<List<User>> getBlockedUsers() async {
    final url = Uri.parse('$baseUrl/users/blocked');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final blockedList = data['blockedUsers'] as List;
      return blockedList.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener usuarios bloqueados');
    }
  }

  Future<Map<String, dynamic>> unblockUser(String targetUserId) async {
    final url = Uri.parse('$baseUrl/users/unblock/$targetUserId');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {'success': false, 'message': data['message']};
    }
  }

  Future<Map<String, dynamic>> blockUser(String targetUserId) async {
    final url = Uri.parse('$baseUrl/users/block/$targetUserId');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Error al bloquear usuario'
      };
    }
  }

  Future<Map<String, dynamic>> uploadPhotos(List<File> photos) async {
    final url = Uri.parse('$baseUrl/users/upload/photos');
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    // Añadir cada foto al request con el tipo MIME correcto
    for (var photo in photos) {
      final mimeType = lookupMimeType(photo.path) ?? 'application/octet-stream';
      final mimeTypeData = mimeType.split('/');

      if (mimeTypeData.length != 2) {
        return {
          'success': false,
          'message':
              'Tipo de archivo desconocido para el archivo: ${photo.path}',
        };
      }

      request.files.add(await http.MultipartFile.fromPath(
        'photos',
        photo.path,
        contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'success': true,
        'photos':
            List<Photo>.from(data['photos'].map((x) => Photo.fromJson(x))),
      };
    } else {
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Error al subir fotos',
      };
    }
  }

  // Método para eliminar una foto adicional
  Future<Map<String, dynamic>> deletePhoto(String publicId) async {
    final url = Uri.parse(
        '$baseUrl/users/delete/photo/$publicId/photo'); // Asumiendo que el tipo es 'photo'
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Foto eliminada correctamente'};
    } else {
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Error al eliminar la foto'
      };
    }
  }

  // Método para obtener matches sugeridos (Asegúrate de que esta ruta exista en el backend)
  Future<Map<String, dynamic>> getSuggestedMatches() async {
    final url =
        Uri.parse('$baseUrl/matches/suggested'); // Actualiza según tu backend
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'success': true, 'matches': data['matches']};
    } else {
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Error al obtener matches'
      };
    }
  }

  // Método para dar like a otro usuario
  Future<Map<String, dynamic>> likeUser(String likedUserId) async {
    final url = Uri.parse('$baseUrl/users/like/$likedUserId');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {
        'success': true,
        'message': data['message'],
        'matchedUser': data['matchedUser'] != null
            ? User.fromJson(data['matchedUser'])
            : null,
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Error al dar like',
      };
    }
  }

  // Método para subir foto de perfil
  Future<Map<String, dynamic>> uploadProfilePicture(File photo) async {
    final url = Uri.parse('$baseUrl/users/upload/profile-picture');
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    final mimeType = lookupMimeType(photo.path) ?? 'application/octet-stream';
    final mimeTypeData = mimeType.split('/');

    if (mimeTypeData.length != 2) {
      return {
        'success': false,
        'message': 'Tipo de archivo desconocido para el archivo: ${photo.path}',
      };
    }

    request.files.add(await http.MultipartFile.fromPath(
      'profilePicture',
      photo.path,
      contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'success': true,
        'profilePicture': Photo.fromJson(data['profilePicture']),
      };
    } else {
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Error al subir la foto de perfil',
      };
    }
  }

  // Método para actualizar el perfil
  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> profileData) async {
    final url = Uri.parse('$baseUrl/users/profile');
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(profileData),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'success': true, 'user': User.fromJson(data['user'])};
    } else {
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Error al actualizar el perfil'
      };
    }
  }
}
