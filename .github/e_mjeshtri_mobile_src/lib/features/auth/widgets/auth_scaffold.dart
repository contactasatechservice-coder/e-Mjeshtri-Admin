import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/storage/local_preferences.dart';
import '../../../core/theme/app_colors.dart';

class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({super.key, required this.child, this.showBack = true});
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).languageCode;
    return Scaffold(
      
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Language',
                    onSelected: (code) async {
                      final value = Locale(code);
                      ref.read(localeProvider.notifier).state = value;
                      await LocalPreferences.saveLocale(value);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'sq', child: Text('🇦🇱  Shqip')),
                      PopupMenuItem(value: 'en', child: Text('🇬🇧  English')),
                      PopupMenuItem(value: 'fr', child: Text('🇫🇷  Français')),
                      PopupMenuItem(value: 'de', child: Text('🇩🇪  Deutsch')),
                      PopupMenuItem(value: 'it', child: Text('🇮🇹  Italiano')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 18, color: AppColors.blue),
                          const SizedBox(width: 6),
                          Text(locale.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.blue)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: Image.asset('assets/branding/e_mjeshtri_logo.png', height: 92)),
                        const SizedBox(height: 28),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 21,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      );
}