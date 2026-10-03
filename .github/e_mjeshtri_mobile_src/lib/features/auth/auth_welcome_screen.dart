import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/feature_flags.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'auth_repository.dart';
import 'widgets/auth_scaffold.dart';

class AuthWelcomeScreen extends ConsumerWidget {
  const AuthWelcomeScreen({super.key});

  Future<void> _oauth(BuildContext context, WidgetRef ref, OAuthProvider provider) async {
    try {
      await ref.read(authRepositoryProvider).signInWithOAuth(provider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).t('errorGeneric'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final showGoogle = FeatureFlags.googleAuthEnabled;
    final showApple = FeatureFlags.appleAuthEnabled && Platform.isIOS;

    return AuthScaffold(
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('welcome'), style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            s.t('welcomeBody'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 34),
          AuthPrimaryButton(label: s.t('signIn'), onPressed: () => context.push('/login')),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: () => context.push('/register'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blue,
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(s.t('createAccount'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (showGoogle || showApple) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('•', style: TextStyle(color: Theme.of(context).hintColor)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ],
          if (showGoogle) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () => _oauth(context, ref, OAuthProvider.google),
                icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                label: Text(s.t('continueGoogle')),
              ),
            ),
          ],
          if (showApple) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () => _oauth(context, ref, OAuthProvider.apple),
                icon: const Icon(Icons.apple_rounded),
                label: Text(s.t('continueApple')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}