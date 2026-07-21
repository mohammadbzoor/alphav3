/// Custom exception that carries the backend error code
/// so UI layers can react to specific business errors.
class ApiException implements Exception {
  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  const ApiException({
    required this.message,
    this.code,
    this.details,
  });

  @override
  String toString() => message;
}