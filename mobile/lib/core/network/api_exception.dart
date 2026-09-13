/// The two failure shapes from docs/03-api-specification.md's cross-cutting
/// standards, as typed exceptions so screens never hand-parse `response.data`.
library;

/// A deliberate business-rule failure — `{"error": {"code", "message"}}`.
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  final String code;
  final String message;
  final int statusCode;

  @override
  String toString() => 'ApiException($code): $message';
}

/// A Form Request validation failure — `{"message", "errors": {field: [msg]}}`.
class ValidationException implements Exception {
  ValidationException(this.errors);

  final Map<String, List<String>> errors;

  String? firstError(String field) => errors[field]?.first;

  @override
  String toString() => 'ValidationException($errors)';
}
