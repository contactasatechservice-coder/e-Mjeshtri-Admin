import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/localization/locale_controller.dart';
import '../../core/storage/local_preferences.dart';
import '../../core/theme/app_colors.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  String _role = 'provider';

  static const _languages = <String, String>{
    'sq': 'SQ',
    'en': 'EN',
    'fr': 'FR',
    'de': 'DE',
    'it': 'IT',
  };

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/auth');
      });
    }

    final locale = ref.watch(localeProvider).languageCode;
    final isProvider = _role == 'provider';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 14, 28, 26),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                tooltip: 'Gjuha',
                onSelected: (code) async {
                  final next = Locale(code);
                  ref.read(localeProvider.notifier).state = next;
                  await LocalPreferences.saveLocale(next);
                  final uid = Supabase.instance.client.auth.currentUser?.id;
                  if (uid != null) {
                    try {
                      await Supabase.instance.client
                          .from('profiles')
                          .update({'preferred_language': code})
                          .eq('id', uid);
                    } catch (_) {}
                  }
                },
                itemBuilder: (_) => _languages.entries
                    .map(
                      (entry) => PopupMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_rounded, color: AppColors.blue),
                      const SizedBox(width: 9),
                      Text(
                        _languages[locale] ?? locale.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFFCAD0DC),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 56),
            Center(
              child: Image.asset(
                'assets/branding/e_mjeshtri_logo.png',
                height: 112,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 62),
            const Text(
              'Si do ta përdorësh e-Mjeshtri?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 27,
                height: 1.12,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Zgjidh rolin tënd. Mund ta ndryshosh më vonë nga profili.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 16.5,
                height: 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              height: 70,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _RoleTab(
                      label: 'Qytetar',
                      selected: !isProvider,
                      onTap: () => setState(() => _role = 'citizen'),
                    ),
                  ),
                  Expanded(
                    child: _RoleTab(
                      label: 'Mjeshtër',
                      selected: isProvider,
                      onTap: () => setState(() => _role = 'provider'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isProvider
                  ? const _RoleInfoCard(
                      key: ValueKey('provider'),
                      icon: Icons.handyman_rounded,
                      title: 'Mjeshtër',
                      body: 'Regjistro shërbimet e tua, merr kërkesa dhe menaxho punët.',
                      accent: AppColors.orange,
                      background: Color(0xFFFFF1E5),
                    )
                  : const _RoleInfoCard(
                      key: ValueKey('citizen'),
                      icon: Icons.home_rounded,
                      title: 'Qytetar',
                      body: 'Kërko shërbime, merr oferta dhe lidhu me mjeshtra pranë teje.',
                      accent: AppColors.blue,
                      background: Color(0xFFEFF6FF),
                    ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 62,
              child: FilledButton(
                onPressed: () {
                  if (_role == 'provider') {
                    context.go('/provider');
                  } else {
                    context.go('/home');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF71AAF4),
                  foregroundColor: const Color(0xFF173B68),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Vazhdo',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(width: 14),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: selected ? AppColors.blue : AppColors.muted,
            ),
          ),
        ),
      );
}

class _RoleInfoCard extends StatelessWidget {
  const _RoleInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    required this.background,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 34),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(icon, size: 44, color: accent),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 17,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}
