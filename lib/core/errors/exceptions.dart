class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() =>
      'AppException: $message${code != null ? ' (code: $code)' : ''}';
}

class CacheException extends AppException {
  CacheException(super.message, [super.code]);
}

class ValidationException extends AppException {
  ValidationException(super.message, [super.code]);
}

class MacroExecutionException extends AppException {
  MacroExecutionException(super.message, [super.code]);
}

class PenaltyExecutionException extends AppException {
  PenaltyExecutionException(super.message, [super.code]);
}

class PermissionException extends AppException {
  PermissionException(super.message, [super.code]);
}

class PlatformChannelException extends AppException {
  PlatformChannelException(super.message, [super.code]);
}
