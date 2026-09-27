import 'package:dio/dio.dart';
import '../errors/app_exception.dart';

class ApiClient {
  final Dio dio;

  ApiClient({Dio? customDio})
    : dio =
          customDio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Can attach auth token from secure storage here
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          final customException = _handleDioError(error);
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: customException,
              message: customException.message,
            ),
          );
        },
      ),
    );
  }

  AppException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 404) return const NotFoundException();
        return ServerException('Server error (${statusCode ?? "unknown"})');
      default:
        return AppException(error.message ?? 'Unexpected error occurred');
    }
  }
}
