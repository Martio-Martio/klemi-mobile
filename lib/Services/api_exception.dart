/// Erreur HTTP remontée par l'API Klemi. Parse le format NestJS standard
/// `{ statusCode, message, error }` et expose un `code` métier optionnel
/// (ex. `USER_NOT_FOUND`, `UNSUPPORTED_LANGUAGE`).
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Object? raw;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.raw,
  });

  /// Construit à partir d'un payload JSON décodé. Supporte :
  ///   - `{ statusCode, message, error }` — format NestJS par défaut.
  ///   - `message` en string **ou** en liste (class-validator) — joint par ", ".
  ///   - `code` optionnel pour les codes métiers mobiles.
  factory ApiException.depuisJson(int statusCode, Object? body) {
    String message = 'Erreur inconnue';
    String? code;
    if (body is Map<String, dynamic>) {
      final brut = body['message'];
      if (brut is String) {
        message = brut;
      } else if (brut is List) {
        message = brut.join(', ');
      } else if (body['error'] is String) {
        message = body['error'] as String;
      }
      if (body['code'] is String) code = body['code'] as String;
    } else if (body is String && body.isNotEmpty) {
      message = body;
    }
    return ApiException(statusCode: statusCode, message: message, code: code, raw: body);
  }

  bool get estAuth => statusCode == 401 || statusCode == 403;
  bool get estReseau => statusCode == 0;

  @override
  String toString() => 'ApiException($statusCode${code != null ? ' $code' : ''}): $message';
}
