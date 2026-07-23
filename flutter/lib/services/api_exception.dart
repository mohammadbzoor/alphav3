/// Custom exception that carries the backend error code
/// so UI layers can react to specific business errors.
class ApiException implements Exception {
  final int? statusCode;
  final String? code;
  final String message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? details;

  const ApiException({
    this.statusCode,
    this.code,
    required this.message,
    this.data,
    this.details,
  });

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, code: $code, message: $message)';
  }
}
