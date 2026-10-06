import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/localization/app_strings.dart';
import '../../core/storage/local_preferences.dart';
import '../../core/theme/app_colors.dart';
import 'auth_repository.dart';

enum _SplashGate { loading, maintenance, update }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  _SplashGate gate = _SplashGate.loading;
  String? updateUrl;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (mounted) setState(() => gate = _SplashGate.loading);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    try {
      final rows = List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('app_config')
            .select('key,value')
            .eq('is_public', true),
      );
      final values = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final value = row['value'];
        if (value is Map) {
          values[row['key'].toString()] = Map<String, dynamic>.from(value);
        }
      }

      if (values['maintenance_mode']?['enabled'] == true) {
        if (mounted) setState(() => gate = _SplashGate.maintenance);
        return;
      }

      final versionKey = Platform.isIOS ? 'client_ios' : 'client_android';
      final minimum = values['min_app_versions']?[versionKey]?.toString();
      if (minimum != null &&
          _compareVersions(AppConfig.currentVersion, minimum) < 0) {
        final storeKey = Platform.isIOS ? 'ios' : 'android';
        final rawUrl = values['store_urls']?[storeKey]?.toString().trim();
        if (mounted) {
          setState(() {
            updateUrl = rawUrl == null || rawUrl.isEmpty ? null : rawUrl;
            gate = _SplashGate.update;
          });
        }
        return;
      }
    } catch (_) {
      // Remote config must not block normal startup.
    }

    // First install / signed-out state must ALWAYS start at the
    // Qytetar / Mjeshtër role selector.
    final session = Supabase.instance.client.auth.currentSession;
    if (!mounted) return;
    if (session == null) {
      context.go('/role');
      return;
    }

    final appRole =
        (session.user.userMetadata?['app_role'] ?? '').toString();
    if (appRole == 'provider') {
      final route = await AuthRepository().providerLandingRoute();
      if (mounted) context.go(route);
      return;
    }

    // Preserve the existing onboarding only for signed-in citizen accounts.
    final onboarded = await LocalPreferences.isOnboardingCompleted();
    if (!mounted) return;
    if (!onboarded) {
      context.go('/onboarding');
      return;
    }

    context.go('/home');
  }

  int _compareVersions(String a, String b) {
    final av = a.split('.').map((v) => int.tryParse(v) ?? 0).toList();
    final bv = b.split('.').map((v) => int.tryParse(v) ?? 0).toList();
    final length = av.length > bv.length ? av.length : bv.length;
    for (var i = 0; i < length; i++) {
      final left = i < av.length ? av[i] : 0;
      final right = i < bv.length ? bv[i] : 0;
      if (left != right) return left.compareTo(right);
    }
    return 0;
  }

  Future<void> _openUpdate() async {
    final raw = updateUrl;
    if (raw == null) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    if (gate == _SplashGate.loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/branding/e_mjeshtri_logo.png', width: 190),
              const SizedBox(height: 22),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isMaintenance = gate == _SplashGate.maintenance;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/branding/e_mjeshtri_logo.png', width: 180),
              const SizedBox(height: 38),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  isMaintenance
                      ? Icons.handyman_rounded
                      : Icons.system_update_alt_rounded,
                  color: AppColors.blue,
                  size: 34,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                s.t(isMaintenance ? 'maintenanceTitle' : 'updateRequired'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                s.t(
                  isMaintenance
                      ? 'maintenanceBody'
                      : 'updateRequiredBody',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              if (!isMaintenance && updateUrl != null)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _openUpdate,
                    child: Text(s.t('updateApp')),
                  ),
                ),
              if (!isMaintenance && updateUrl != null)
                const SizedBox(height: 8),
              TextButton(
                onPressed: _bootstrap,
                child: Text(s.t('retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
