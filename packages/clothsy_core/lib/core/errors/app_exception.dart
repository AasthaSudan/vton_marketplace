class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Please check your internet connection',
  ]) : super(code: 'NETWORK_ERROR');
}

class ServerException extends AppException {
  const ServerException([super.message = 'Something went wrong on our servers'])
    : super(code: 'SERVER_ERROR');
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Item not found'])
    : super(code: 'NOT_FOUND');
}
