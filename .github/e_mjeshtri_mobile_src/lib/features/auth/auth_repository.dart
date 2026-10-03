import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String languageCode,
    required String role,
  }) async {
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim(),
        'preferred_language': languageCode,
        'app_role': role == 'provider' ? 'provider' : 'citizen',
      },
    );
  }

  Future<void> sendEmailOtp(String email) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: false,
    );
  }

  Future<void> verifyEmailOtp({required String email, required String token}) async {
    await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }


  Future<void> signInWithOAuth(OAuthProvider provider) async {
    await _client.auth.signInWithOAuth(
      provider,
      redirectTo: AppConfig.authRedirectUrl,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}