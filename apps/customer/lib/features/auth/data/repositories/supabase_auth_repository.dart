import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:clothsy_core/data/mappers/account_mappers.dart';
import 'package:clothsy_core/features/auth/domain/entities/user.dart';
import 'package:clothsy_core/features/auth/domain/repositories/auth_repository.dart';

/// Phone OTP sign-in with Supabase Auth; the profile lives in `profiles`.
class SupabaseAuthRepository implements AuthRepository {
  final sb.SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  Future<User> _load(sb.User authUser) async {
    final profile = await _client
        .from('profiles')
        .select()
        .eq('id', authUser.id)
        .maybeSingle();
    return AccountMappers.user(
      id: authUser.id,
      profile: profile,
      phone: authUser.phone == null || authUser.phone!.isEmpty
          ? null
          : '+${authUser.phone}',
      email: authUser.email,
    );
  }

  Never _fail(Object error) {
    if (error is sb.AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('expired') || message.contains('invalid')) {
        throw const AuthFailure(
          "That code didn't match. Check it and try again.",
        );
      }
      if (message.contains('rate') || error.statusCode == '429') {
        throw const AuthFailure(
          'Too many tries. Please wait a minute and try again.',
        );
      }
      throw AuthFailure(error.message);
    }
    throw const AuthFailure(
      "We couldn't reach Clothsy. Check your connection and try again.",
    );
  }

  @override
  Future<User?> getCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    try {
      return await _load(authUser);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> sendPhoneOtp(String phoneNumber) async {
    try {
      await _client.auth.signInWithOtp(
        phone: AccountMappers.e164India(phoneNumber),
      );
      return true;
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Future<User> verifyPhoneOtp(String phoneNumber, String otp) async {
    try {
      final res = await _client.auth.verifyOTP(
        type: sb.OtpType.sms,
        phone: AccountMappers.e164India(phoneNumber),
        token: otp,
      );
      final authUser = res.user;
      if (authUser == null) throw const AuthFailure("That code didn't match.");
      return _load(authUser);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      _fail(e);
    }
  }

  @override
  Future<User> signInWithEmail(String email, String password) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return _load(res.user!);
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Future<User> signInWithGoogle() async {
    throw const AuthFailure(
      'Google sign-in is coming soon. Please use your phone number for now.',
    );
  }

  @override
  Future<User> signInWithApple() async {
    throw const AuthFailure(
      'Apple sign-in is coming soon. Please use your phone number for now.',
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<User> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw const AuthFailure('Please sign in again.');
    await _client
        .from('profiles')
        .update({'full_name': ?name, 'email': ?email})
        .eq('id', authUser.id);
    return _load(authUser);
  }

  /// Records the request and signs out; the account is erased by a support
  /// process (Phase 2) so orders and refunds stay intact.
  @override
  Future<void> deleteAccount() async {
    final authUser = _client.auth.currentUser;
    if (authUser != null) {
      await _client
          .from('profiles')
          .update({
            'deletion_requested_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', authUser.id);
    }
    await _client.auth.signOut();
  }
}
