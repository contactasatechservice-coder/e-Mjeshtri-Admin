import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../marketplace/marketplace_repository.dart';

class ProviderAvatar extends ConsumerWidget {
  const ProviderAvatar({super.key, this.path, this.size = 54, this.borderRadius = 18});
  final String? path;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (path == null || path!.trim().isEmpty) return _fallback();
    return FutureBuilder<String?>(
      future: ref.read(marketplaceRepositoryProvider).providerMediaSignedUrl(path),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) return _fallback();
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.network(
            snap.data!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        );
      },
    );
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(Icons.handyman_rounded, color: AppColors.blue, size: size * .5),
      );
}

class ProviderMediaTile extends ConsumerWidget {
  const ProviderMediaTile({super.key, required this.path, this.width = 150, this.height = 112});
  final String path;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref.read(marketplaceRepositoryProvider).providerMediaSignedUrl(path),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: .06), borderRadius: BorderRadius.circular(20)),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            snap.data!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: width,
              height: height,
              color: AppColors.blue.withValues(alpha: .06),
              child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
            ),
          ),
        );
      },
    );
  }
}