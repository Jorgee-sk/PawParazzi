import 'package:dio/dio.dart';

/// Error normalizado de la API. `code` coincide con los códigos estables del backend
/// (p. ej. `already_participated`, `email_taken`).
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  bool get isNetwork => code == 'network';
  bool get isUnauthorized => statusCode == 401;

  static const _fallback = 'Algo ha fallado. Inténtalo de nuevo.';

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final inner = error.error;
      if (inner is ApiException) return inner;
      final response = error.response;
      final data = response?.data;
      if (response != null && data is Map) {
        final fields = <String, String>{};
        final rawFields = data['fieldErrors'];
        if (rawFields is Map) {
          rawFields.forEach((k, v) => fields['$k'] = '$v');
        }
        return ApiException(
          code: '${data['code'] ?? 'http_${response.statusCode}'}',
          message: '${data['message'] ?? _fallback}',
          statusCode: response.statusCode,
          fieldErrors: fields,
        );
      }
      if (response != null) {
        return ApiException(code: 'http_${response.statusCode}', message: _fallback, statusCode: response.statusCode);
      }
      return const ApiException(
        code: 'network',
        message: 'No hay conexión con PawParazzi. Revisa tu red e inténtalo de nuevo.',
      );
    }
    return const ApiException(code: 'unknown', message: _fallback);
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
