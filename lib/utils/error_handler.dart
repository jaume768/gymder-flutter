// lib/utils/error_handler.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

enum ErrorType {
  validation,
  network,
  conflict,
  authentication,
  server,
  unknown
}

class ApiError {
  final ErrorType type;
  final String message;
  final Map<String, dynamic>? fieldErrors;

  ApiError({
    required this.type,
    required this.message,
    this.fieldErrors,
  });

  factory ApiError.fromResponse(http.Response response) {
    try {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final String message = data['message'] ?? tr('unknown_error');
      
      // Intentar extraer errores específicos de campos si existen
      Map<String, dynamic>? fieldErrors;
      if (data.containsKey('errors') && data['errors'] is Map) {
        fieldErrors = Map<String, dynamic>.from(data['errors']);
      }

      switch (response.statusCode) {
        case 400:
          return ApiError(
            type: ErrorType.validation,
            message: message,
            fieldErrors: fieldErrors,
          );
        case 401:
        case 403:
          return ApiError(
            type: ErrorType.authentication,
            message: message,
          );
        case 409:
          return ApiError(
            type: ErrorType.conflict,
            message: message,
            fieldErrors: fieldErrors,
          );
        case 500:
        case 502:
        case 503:
          return ApiError(
            type: ErrorType.server,
            message: tr('server_error'),
          );
        default:
          return ApiError(
            type: ErrorType.unknown,
            message: message,
          );
      }
    } catch (e) {
      return ApiError(
        type: ErrorType.unknown,
        message: tr('error_processing_response'),
      );
    }
  }

  factory ApiError.network(String error) {
    return ApiError(
      type: ErrorType.network,
      message: "${tr('network_error')}: $error",
    );
  }

  String getFieldError(String fieldName) {
    if (fieldErrors != null && fieldErrors!.containsKey(fieldName)) {
      return fieldErrors![fieldName].toString();
    }
    return '';
  }
}

// Extensión para el contexto para mostrar fácilmente errores
extension ErrorHandling on BuildContext {
  void showErrorSnackbar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  void showApiError(ApiError error) {
    showErrorSnackbar(error.message);
  }
}

// Decoración de entrada con error
InputDecoration errorInputDecoration(InputDecoration decoration, String? errorText) {
  if (errorText == null || errorText.isEmpty) {
    return decoration;
  }
  
  return decoration.copyWith(
    errorText: errorText,
    errorStyle: const TextStyle(color: Colors.redAccent),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.redAccent),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.redAccent),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
