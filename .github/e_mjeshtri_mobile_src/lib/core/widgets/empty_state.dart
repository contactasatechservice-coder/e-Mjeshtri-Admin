import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(22), border: Border.all(color: Theme.of(context).dividerColor)),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: .08), shape: BoxShape.circle), child: const Icon(Icons.handyman_rounded, color: AppColors.blue)),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[const SizedBox(height: 6), Text(subtitle!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium)],
      ]),
    );
  }
}