import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config_provider.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/mock_auth_repository.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import 'package:clothsy_core/features/auth/domain/entities/user.dart';
import 'package:clothsy_core/features/auth/domain/repositories/auth_repository.dart';

class AuthState {
  final User? user;
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.status = AuthStatus.initial,
    this.errorMessage,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isGuest => status == AuthStatus.guest;

  AuthState copyWith({User? user, AuthStatus? status, String? errorMessage}) {
    return AuthState(
      user: user ?? this.user,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

String _friendly(Object error) => error is AuthFailure
    ? error.message
    : 'Something went wrong signing you in. Please try again.';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockBackend) return MockAuthRepository();
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _checkInitialAuth();
    return const AuthState(status: AuthStatus.initial);
  }

  Future<void> _checkInitialAuth() async {
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.getCurrentUser();
    if (!ref.mounted) return;
    if (user != null) {
      state = AuthState(user: user, status: AuthStatus.authenticated);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> sendPhoneOtp(String phone) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );
    try {
      final repo = ref.read(authRepositoryProvider);
      final ok = await repo.sendPhoneOtp(phone);
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return ok;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _friendly(e),
      );
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.verifyPhoneOtp(phone, otp);
      state = AuthState(user: user, status: AuthStatus.authenticated);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _friendly(e),
      );
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signInWithEmail(email, password);
      state = AuthState(user: user, status: AuthStatus.authenticated);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _friendly(e),
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signInWithGoogle();
      state = AuthState(user: user, status: AuthStatus.authenticated);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _friendly(e),
      );
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signInWithApple();
      state = AuthState(user: user, status: AuthStatus.authenticated);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _friendly(e),
      );
      return false;
    }
  }

  void continueAsGuest() {
    state = const AuthState(user: User.guest, status: AuthStatus.guest);
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final updated = await repo.updateProfile(
      name: name,
      email: email,
      phone: phone,
    );
    state = state.copyWith(user: updated);
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> deleteAccount() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.deleteAccount();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});
