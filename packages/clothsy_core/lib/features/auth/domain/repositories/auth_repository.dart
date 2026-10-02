import '../entities/user.dart';

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
