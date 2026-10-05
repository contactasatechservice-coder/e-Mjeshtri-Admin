import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_repository.dart';
import '../marketplace/marketplace_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? profile;
  String? avatarUrl;
  String? providerId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(marketplaceRepositoryProvider);
      final p = await repo.profile();
      final url = await repo.avatarSignedUrl(p['avatar_path']?.toString());
      final user = Supabase.instance.client.auth.currentUser;
      Map<String, dynamic>? membership;
      if (user != null) {
        final rawMembership = await Supabase.instance.client
            .from('provider_members')
            .select('provider_id')
            .eq('user_id', user.id)
            .eq('is_active', true)
            .limit(1)
            .maybeSingle();
        if (rawMembership != null) {
          membership = Map<String, dynamic>.from(rawMembership);
        }
      }
      if (mounted) {
        setState(() {
          profile = p;
          avatarUrl = url;
          providerId = membership?['provider_id']?.toString();
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    final first = (profile?['first_name'] ?? user?.userMetadata?['first_name'] ?? '').toString();
    final last = (profile?['last_name'] ?? user?.userMetadata?['last_name'] ?? '').toString();
    final name = ('$first $last').trim().isEmpty ? 'e-Mjeshtri' : ('$first $last').trim();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Text(s.t('profile'), style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 22),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () async {
                  await context.push('/profile/edit');
                  await _load();
                },
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: .08),
                          shape: BoxShape.circle,
                        ),
                        child: loading
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : avatarUrl == null
                                ? const Icon(Icons.person_rounded, color: AppColors.blue, size: 30)
                                : Image.network(
                                    avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: AppColors.blue, size: 30),
                                  ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(user?.email ?? '', style: const TextStyle(color: AppColors.muted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(s.t('settings'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            _SettingsCard(children: [
              _tile(Icons.person_outline_rounded, s.t('editProfile'), () async {
                await context.push('/profile/edit');
                await _load();
              }),
              if (providerId != null)
                _tile(
                  Icons.workspace_premium_rounded,
                  'Abonimi i Mjeshtrit',
                  () => context.push('/profile/subscription'),
                ),
              _tile(Icons.location_on_outlined, s.t('addresses'), () => context.push('/profile/addresses')),
              _tile(Icons.language_rounded, s.t('language'), () => context.push('/profile/language')),
              _tile(Icons.notifications_none_rounded, s.t('notificationSettings'), () => context.push('/profile/notifications')),
              _tile(Icons.shield_outlined, s.t('privacySecurity'), () => context.push('/profile/privacy')),
            ]),
            const SizedBox(height: 16),
            _SettingsCard(children: [
              _tile(Icons.help_outline_rounded, s.t('helpCenter'), () => context.push('/help')),
              _tile(Icons.support_agent_rounded, s.t('support'), () => context.push('/support')),
              _tile(Icons.gavel_outlined, s.t('termsPrivacy'), () => context.push('/terms')),
              _tile(Icons.info_outline_rounded, s.t('about'), () => context.push('/about')),
            ]),
            const SizedBox(height: 16),
            _SettingsCard(children: [
              _tile(Icons.delete_outline_rounded, s.t('deleteAccount'), () => context.push('/profile/delete'), danger: true),
            ]),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(s.t('logout')),
                    content: Text(s.t('accountLogoutWarning')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('logout'))),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/auth');
                }
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
              label: Text(s.t('logout'), style: const TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFF0C8CC)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap, {bool danger = false}) => ListTile(
        leading: Icon(icon, color: danger ? AppColors.danger : null),
        title: Text(title, style: TextStyle(color: danger ? AppColors.danger : null, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: List.generate(
            children.length,
            (i) => Column(children: [children[i], if (i < children.length - 1) const Divider(height: 1)]),
          ),
        ),
      );
}