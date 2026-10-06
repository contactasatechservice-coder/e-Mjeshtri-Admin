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

  Future<String> providerLandingRoute() async {
    final user = _client.auth.currentUser;
    if (user == null) return '/login?role=provider';

    Map<String, dynamic>? membership;
    Future<Map<String, dynamic>?> loadMembership() async {
      final raw = await _client
          .from('provider_members')
          .select('provider_id')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();
      return raw == null ? null : Map<String, dynamic>.from(raw);
    }

    membership = await loadMembership();

    if (membership == null) {
      final metadata = user.userMetadata ?? const <String, dynamic>{};
      final firstName = (metadata['first_name'] ?? '').toString().trim();
      final lastName = (metadata['last_name'] ?? '').toString().trim();
      var displayName = [firstName, lastName]
          .where((part) => part.isNotEmpty)
          .join(' ')
          .trim();
      if (displayName.isEmpty) {
        displayName = (user.email ?? 'Mjeshtër').split('@').first;
      }

      final response = await _client.functions.invoke(
        'provider-onboarding',
        body: {
          'provider_type': 'individual',
          'display_name': displayName,
          'legal_name': displayName,
          'phone': (metadata['phone'] ?? '').toString().trim(),
          'email': user.email,
          'bio': null,
          'city': null,
          'default_language':
              (metadata['preferred_language'] ?? 'sq').toString(),
        },
      );

      if (response.status < 200 || response.status >= 300) {
        throw Exception('Provider onboarding failed');
      }

      membership = await loadMembership();
    }

    final providerId = membership?['provider_id']?.toString();
    if (providerId == null || providerId.isEmpty) {
      return '/profile/subscription';
    }

    final rawOverview = await _client.rpc(
      'provider_subscription_overview',
      params: {'p_provider_id': providerId},
    );
    final overview = rawOverview is Map
        ? Map<String, dynamic>.from(rawOverview)
        : <String, dynamic>{};
    final rawSubscription = overview['current_subscription'];
    final subscription = rawSubscription is Map
        ? Map<String, dynamic>.from(rawSubscription)
        : null;
    final active = subscription?['effective_active'] == true;

    return active ? '/provider' : '/profile/subscription';
  }

  Future<void> signOut() => _client.auth.signOut();
}