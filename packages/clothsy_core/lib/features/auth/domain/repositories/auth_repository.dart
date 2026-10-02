import '../entities/user.dart';

/// A sign-in problem the shopper can act on ("That code doesn't match").
/// Repositories throw it with a ready-to-show message; anything else is
/// reported as a generic failure.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}

abstract class AuthRepository {
  Future<User?> getCurrentUser();
  Future<bool> sendPhoneOtp(String phoneNumber);
  Future<User> verifyPhoneOtp(String phoneNumber, String otp);
  Future<User> signInWithEmail(String email, String password);
  Future<User> signInWithGoogle();
  Future<User> signInWithApple();
  Future<void> signOut();
  Future<User> updateProfile({String? name, String? email, String? phone});
  Future<void> deleteAccount();
}
