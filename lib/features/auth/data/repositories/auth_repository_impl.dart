import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserName = 'auth_user_name';
  static const String _keyUserEmail = 'auth_user_email';
  static const String _keyUserPhone = 'auth_user_phone';
  static const String _keyUserTier = 'auth_user_tier';

  User? _cachedUser;

  @override
  Future<User?> getCurrentUser() async {
    if (_cachedUser != null) return _cachedUser;

    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyUserId);
    if (id == null) return null;

    _cachedUser = User(
      id: id,
      name: prefs.getString(_keyUserName) ?? 'Aastha Sudan',
      email: prefs.getString(_keyUserEmail) ?? 'aastha@example.com',
      phone: prefs.getString(_keyUserPhone) ?? '+91 98765 43210',
      memberTier: prefs.getString(_keyUserTier) ?? 'Clothsy Gold Member',
    );
    return _cachedUser;
  }

  @override
  Future<bool> sendPhoneOtp(String phoneNumber) async {
    await Future.delayed(const Duration(milliseconds: 350));
    return true;
  }

  @override
  Future<User> verifyPhoneOtp(String phoneNumber, String otp) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final user = User(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Aastha Sudan',
      email: 'aastha.clothsy@gmail.com',
      phone: phoneNumber.startsWith('+91') ? phoneNumber : '+91 $phoneNumber',
      memberTier: 'Clothsy Gold Member',
    );
    await _persistUser(user);
    return user;
  }

  @override
  Future<User> signInWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final user = User(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: email.split('@').first.capitalize(),
      email: email,
      phone: '+91 98765 43210',
      memberTier: 'Clothsy Atelier Member',
    );
    await _persistUser(user);
    return user;
  }

  @override
  Future<User> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 500));
    const user = User(
      id: 'usr_google_102',
      name: 'Aastha Sudan',
      email: 'aastha.sudan@gmail.com',
      phone: '+91 98765 43210',
      memberTier: 'Clothsy Gold Member',
    );
    await _persistUser(user);
    return user;
  }

  @override
  Future<User> signInWithApple() async {
    await Future.delayed(const Duration(milliseconds: 500));
    const user = User(
      id: 'usr_apple_103',
      name: 'Aastha Sudan',
      email: 'aastha@privaterelay.appleid.com',
      phone: '+91 98765 43210',
      memberTier: 'Clothsy Atelier Member',
    );
    await _persistUser(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyUserTier);
    _cachedUser = null;
  }

  @override
  Future<User> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    final current = await getCurrentUser() ?? User.guest;
    final updated = current.copyWith(
      name: name ?? current.name,
      email: email ?? current.email,
      phone: phone ?? current.phone,
    );
    await _persistUser(updated);
    return updated;
  }

  @override
  Future<void> deleteAccount() async {
    await signOut();
  }

  Future<void> _persistUser(User user) async {
    _cachedUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, user.id);
    await prefs.setString(_keyUserName, user.name);
    await prefs.setString(_keyUserEmail, user.email);
    await prefs.setString(_keyUserPhone, user.phone);
    await prefs.setString(_keyUserTier, user.memberTier);
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
