// lib/services/user_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart'; // Importa el paquete mime
import 'package:http_parser/http_parser.dart'; // Para MediaType
import '../models/user.dart';

class UserService {
  final String baseUrl = 'https://gymder-api-production.up.railway.app/api';
  final String token;

  UserService({required this.token});

  Future<Map<String, dynamic>> getNotificationSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/notifications'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final url = Uri.parse('$baseUrl/send-verification-email');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    final data = jsonDecode(resp.body);
    if (resp.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {'success': false, 'message': data['message'] ?? tr('error')};
    }
  }

  /// 2) Confirmar código + nueva contraseña
  Future<Map<String, dynamic>> confirmPasswordReset(
      String email, String code, String newPassword) async {
    // Primero comprobamos el código
    final verifyUrl = Uri.parse('$baseUrl/reset-password');
    final verifyResp = await http.post(
      verifyUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (verifyResp.statusCode != 200) {
      final err = jsonDecode(verifyResp.body);
      return {'success': false, 'message': err['message'] ?? tr('error')};
    }
    // Si OK, actualizamos la contraseña (aquí reutilizamos change-password o creamos endpoint nuevo)
    final resetUrl = Uri.parse('$baseUrl/change-password');
    final resetResp = await http.patch(
      resetUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'currentPassword': code, // backend ignora currentPassword en reset
        'newPassword': newPassword,
      }),
    );
    final resetData = jsonDecode(resetResp.body);
    if (resetResp.statusCode == 200) {
      return {'success': true, 'message': resetData['message']};
    } else {
      return {'success': false, 'message': resetData['message'] ?? tr('error')};
    }
  }

  Future<Map<String, dynamic>> getLikeLimitStatus() async {
    final url = Uri.parse('$baseUrl/users/like/status');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {
        'success': true,
        'limitActive': data['limitActive'],
        'likeCount': data['likeCount'],
        'likeLimit': data['limitInfo']?['likeLimit'],
        'resetAt': data['limitInfo']?['resetAt'],
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Error obteniendo estado de likes'
      };
    }
  }

  Future<Map<String, dynamic>> setNotificationSetting(
      String key, bool value) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/notification'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({key: value}),
    );
    return jsonDecode(response.body);
  }

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

  Future<Map<String, dynamic>> purchaseTopLike() async {
    final url = Uri.parse('$baseUrl/users/top_like/purchase');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final data = jsonDecode(resp.body);
    return data;
  }

  Future<Map<String, dynamic>> superLikeUser(String targetUserId) async {
    final url = Uri.parse('$baseUrl/users/top_like/$targetUserId');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final data = jsonDecode(resp.body);
    return data;
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

  Future<Map<String, dynamic>> cancelPremium() async {
    final url = Uri.parse('$baseUrl/users/cancel');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'user': User.fromJson(data['user'])};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Error al cancelar Premium'
      };
    }
  }

  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    // Apunta a /api/users/change-password
    final url = Uri.parse('$baseUrl/users/change-password');
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {
        'success': false,
        // el backend devuelve siempre un 'message'
        'message': data['message'] ?? tr('error_changing_password'),
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
  Future<Map<String, dynamic>> deletePhoto(String photoId) async {
    final url = Uri.parse('$baseUrl/users/delete/photo/$photoId/photo');
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
    final response = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        'success': true,
        'matchedUser': data['matchedUser'] != null
            ? User.fromJson(data['matchedUser'])
            : null,
      };
    }
    // 403 → límite alcanzado
    if (response.statusCode == 403 && data['limitReached'] == true) {
      return {
        'success': false,
        'limitReached': true,
        'likeLimit': data['limitInfo']['likeLimit'],
        'resetAt': data['limitInfo']['resetAt'],
      };
    }
    return {
      'success': false,
      'message': data['message'] ?? 'Error al dar like',
    };
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

  Future<Map<String, dynamic>> updateUsername(String newUsername) async {
    final url = Uri.parse('$baseUrl/users/username');
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'newUsername': newUsername}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': 'Username actualizado correctamente'};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Error al cambiar el username'
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

  // Método para obtener el perfil de un usuario por su ID
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final url = Uri.parse('$baseUrl/users/profile/$userId');
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
        'user': data['user'],
      };
    } else {
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Error al obtener el perfil del usuario'
      };
    }
  }

  Future<Map<String, dynamic>> reportUser(
    String reportedUserId, {
    required String reason,
    String? details,
  }) async {
    final url = Uri.parse('$baseUrl/users/report/$reportedUserId');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'reason': reason, 'details': details}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Error al reportar'
      };
    }
  }

  // Método para validar imágenes sin subir (verificar contenido explícito)
  Future<Map<String, dynamic>> validateImages(List<File> photos) async {
    if (photos.isEmpty) {
      return {
        'success': true,
        'message': 'No hay imágenes para validar',
      };
    }

    final url = Uri.parse('$baseUrl/users/validate/images');
    final request = http.MultipartRequest('POST', url);

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
        'message': data['message'] ?? 'Imágenes validadas correctamente',
      };
    } else {
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Error al validar imágenes',
        'explicitImages': data['explicitImages'] ?? [],
      };
    }
  }

  // Método para aplicar código promocional
  Future<Map<String, dynamic>> applyPromoCode(String code) async {
    final url = Uri.parse('$baseUrl/users/promo-code/apply');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'code': code}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {
        'success': true,
        'message':
            data['message'] ?? 'Código promocional aplicado correctamente',
        'topLikesGranted': data['topLikesGranted'],
        'promoCode': data['promoCode'],
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Error al aplicar código promocional',
        'usedCode': data['usedCode'], // Si ya se aplicó un código anteriormente
      };
    }
  }
}
