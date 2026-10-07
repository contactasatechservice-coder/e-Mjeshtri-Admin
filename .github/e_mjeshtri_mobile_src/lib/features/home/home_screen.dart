import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../marketplace/marketplace_repository.dart';
import '../providers/provider_avatar.dart';
import '../requests/request_flow.dart';
import 'home_repository.dart';

bool hasActiveBlueTick(Map<String, dynamic> provider) {
  if (provider['is_verified'] != true) return false;
  final raw = provider['blue_tick_expires_at']?.toString();
  if (raw == null || raw.trim().isEmpty) return true;
  final expires = DateTime.tryParse(raw);
  return expires == null || expires.isAfter(DateTime.now().toUtc());
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _homeCategorySlugs = <String>[
    'plumbing',
    'electrical',
    'heating_ac',
    'appliance_repair',
    'internet_tv_smart_home',
    'painting',
  ];

  IconData _icon(String? key) => switch (key) {
        'plumbing' => Icons.plumbing_rounded,
        'electrical' => Icons.electrical_services_rounded,
        'ac_unit' => Icons.ac_unit_rounded,
        'format_paint' => Icons.format_paint_rounded,
        'construction' => Icons.construction_rounded,
        'grid_view' => Icons.grid_view_rounded,
        'carpenter' => Icons.carpenter_rounded,
        'door_front' => Icons.door_front_door_rounded,
        'cleaning_services' => Icons.cleaning_services_rounded,
        'yard' => Icons.yard_rounded,
        'roofing' => Icons.roofing_rounded,
        'local_shipping' => Icons.local_shipping_rounded,
        'videocam' => Icons.videocam_rounded,
        'router' => Icons.router_rounded,
        'solar_power' => Icons.solar_power_rounded,
        _ => Icons.home_repair_service_rounded,
      };

  String? _categoryPhoto(Map<String, dynamic> item, String language) {
    final slug = (item['slug'] ?? '').toString().toLowerCase();
    return switch (slug) {
      'plumbing' =>
        'https://images.pexels.com/photos/29226620/pexels-photo-29226620/free-photo-of-professional-plumber-installing-a-radiator-pipe.jpeg?auto=compress&dpr=1&h=750&w=1260',
      'electrical' =>
        'https://images.pexels.com/photos/5691590/pexels-photo-5691590.jpeg?auto=compress&dpr=1&h=750&w=1260',
      'heating_ac' =>
        'https://images.pexels.com/photos/16592625/pexels-photo-16592625/free-photo-of-air-conditioner-in-a-house.jpeg?auto=compress&dpr=1&h=750&w=1260',
      'appliance_repair' =>
        'https://images.pexels.com/photos/34734504/pexels-photo-34734504/free-photo-of-technician-repairing-home-appliance-indoors.jpeg?auto=compress&dpr=1&h=750&w=1260',
      'internet_tv_smart_home' =>
        'https://images.pexels.com/photos/4218546/pexels-photo-4218546.jpeg?auto=compress&dpr=1&h=750&w=1260',
      'painting' =>
        'https://images.pexels.com/photos/5493655/pexels-photo-5493655.jpeg?auto=compress&dpr=1&h=750&w=1260',
      _ => null,
    };
  }

  Color _categoryAccent(Map<String, dynamic> item, String language) {
    final slug = (item['slug'] ?? '').toString().toLowerCase();
    return switch (slug) {
      'plumbing' => const Color(0xFF1687D9),
      'electrical' => const Color(0xFFF4A300),
      'heating_ac' => const Color(0xFF24A6C8),
      'appliance_repair' => const Color(0xFF6C5CE7),
      'internet_tv_smart_home' => const Color(0xFFF0A500),
      'painting' => const Color(0xFFE86E49),
      _ => AppColors.blue,
    };
  }

  Widget _categoryPhotoCard(
    BuildContext context,
    Map<String, dynamic> item,
    String language,
  ) {
    final photo = _categoryPhoto(item, language);
    final accent = _categoryAccent(item, language);
    final radius = BorderRadius.circular(22);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: () => context.push('/categories/${item['id']}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: accent.withValues(alpha: .08),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo != null)
                  Image.network(
                    photo,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: accent.withValues(alpha: .10),
                    ),
                  )
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          accent.withValues(alpha: .12),
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: const Alignment(.72, -.25),
                      child: Icon(
                        _icon(item['icon_key']?.toString()),
                        size: 88,
                        color: accent.withValues(alpha: .14),
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        Colors.white.withValues(alpha: .97),
                        Colors.white.withValues(alpha: .72),
                        accent.withValues(alpha: .07),
                        Colors.transparent,
                      ],
                      stops: const [0, .42, .66, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _icon(item['icon_key']?.toString()),
                      color: accent,
                      size: 22,
                    ),
                  ),
                ),
                Positioned(
                  left: 15,
                  right: 50,
                  bottom: 16,
                  child: Text(
                    translatedName(item, language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 14.5,
                      height: 1.10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Positioned(
                  right: 11,
                  bottom: 11,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x16000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: accent,
                      size: 23,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _homeCategories(
    List<Map<String, dynamic>> items,
  ) {
    final bySlug = <String, Map<String, dynamic>>{
      for (final item in items) (item['slug'] ?? '').toString(): item,
    };
    return [
      for (final slug in _homeCategorySlugs)
        if (bySlug[slug] != null) bySlug[slug]!,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final categories = ref.watch(categoriesProvider);
    final providers = ref.watch(activeProvidersProvider);
    final repo = ref.read(marketplaceRepositoryProvider);
    final user = repo.client.auth.currentUser;
    final first = (user?.userMetadata?['first_name'] ?? '').toString();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(activeProvidersProvider);
          await Future.wait([
            ref.read(categoriesProvider.future),
            ref.read(activeProvidersProvider.future),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              sliver: SliverList.list(
                children: [
                  Center(
                    child: Image.asset(
                      'assets/branding/e_mjeshtri_logo.png',
                      height: 52,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.push('/profile/addresses'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 18,
                                  color: AppColors.blue,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    s.t('myLocation'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => context.push('/notifications'),
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    first.isEmpty ? s.t('hello') : '${s.t('hello')}, $first',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(s.t('search'), style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 14),
                  TextField(
                    readOnly: true,
                    onTap: () => context.push('/search'),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.blue),
                      hintText: s.t('homeSearchHint'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () => context.push('/categories?request=1'),
                      icon: const Icon(Icons.add_task_rounded),
                      label: Text(
                        s.t('createRequest'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: s.t('categories'),
                    action: s.t('seeAll'),
                    onAction: () => context.push('/categories'),
                  ),
                  const SizedBox(height: 14),
                  categories.when(
                    loading: () => const _CategorySkeleton(),
                    error: (_, __) => EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: s.t('errorGeneric'),
                    ),
                    data: (items) {
                      final visible = _homeCategories(items);

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 12.0;
                          final cardWidth =
                              (constraints.maxWidth - spacing) / 2;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: 10,
                            children: [
                              for (final item in visible)
                                SizedBox(
                                  width: cardWidth,
                                  child: AspectRatio(
                                    aspectRatio: 1.42,
                                    child: _categoryPhotoCard(
                                      context,
                                      item,
                                      language,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: s.t('nearby'),
                    action: s.t('seeAll'),
                    onAction: () => context.push('/search'),
                  ),
                  const SizedBox(height: 14),
                  providers.when(
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (_, __) => EmptyState(icon: Icons.cloud_off_rounded, title: s.t('errorGeneric')),
                    data: (items) => items.isEmpty
                        ? EmptyState(icon: Icons.handyman_rounded, title: s.t('noProviders'))
                        : Column(
                            children: items
                                .take(4)
                                .map(
                                  (p) => _ProviderCard(
                                    provider: p,
                                    language: language,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 26),
                  _SectionHeader(title: s.t('rebook')),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: repo.orders(),
                    builder: (context, snap) {
                      final completed = (snap.data ?? []).where((o) => o['status'] == 'completed').take(2).toList();
                      if (completed.isEmpty) {
                        return const _CompactEmptyRebook();
                      }
                      return Column(
                        children: completed.map((o) {
                          final p = (o['providers'] as Map?)?.cast<String, dynamic>() ?? {};
                          final r = (o['service_requests'] as Map?)?.cast<String, dynamic>() ?? {};
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                leading: const Icon(Icons.replay_rounded, color: AppColors.blue),
                                title: Text((p['display_name'] ?? '').toString()),
                                subtitle: Text(
                                  (r['description'] ?? '').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => context.push('/request/new?categoryId=${r['category_id'] ?? ''}'),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (action != null && onAction != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      );
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.language,
  });

  final Map<String, dynamic> provider;
  final String language;

  String _specialty() {
    final rows = provider['provider_categories'];
    if (rows is! List) return '';
    for (final raw in rows) {
      if (raw is! Map || raw['is_active'] != true) continue;
      final category = raw['service_categories'];
      if (category is Map) {
        return translatedName(
          Map<String, dynamic>.from(category),
          language,
        );
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final ratingCount = (provider['rating_count'] as num?)?.toInt() ?? 0;
    final ratingAvg = (provider['rating_avg'] as num?)?.toDouble() ?? 0;
    final specialty = _specialty();
    final available =
        provider['accepts_asap'] == true && provider['vacation_mode'] != true;
    final distance = (provider['distance_km'] as num?)?.toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.push('/providers/${provider['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProviderAvatar(
                      path: provider['logo_path']?.toString(),
                      size: 58,
                      borderRadius: 20,
                    ),
                    if (available)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              (provider['display_name'] ?? '').toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (hasActiveBlueTick(provider))
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(
                                Icons.verified_rounded,
                                size: 17,
                                color: AppColors.blue,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _MiniMeta(
                            icon: Icons.location_on_outlined,
                            text: (provider['city'] ?? '').toString(),
                          ),
                          if (distance != null)
                            _MiniMeta(
                              icon: Icons.near_me_outlined,
                              text: distance < 1
                                  ? '${(distance * 1000).round()} m'
                                  : '${distance.toStringAsFixed(1)} km',
                            ),
                        ],
                      ),
                      if (specialty.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        _MiniMeta(
                          icon: Icons.handyman_outlined,
                          text: specialty,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (available)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success
                                    .withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                AppStrings.of(context).t('availableNow'),
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          if (available) const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(
                                  ratingCount == 0
                                      ? Icons.star_border_rounded
                                      : Icons.star_rounded,
                                  size: 17,
                                  color: ratingCount == 0
                                      ? AppColors.muted
                                      : AppColors.orange,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    ratingCount == 0
                                        ? AppStrings.of(context).t('noRatingsYet')
                                        : '${ratingAvg.toStringAsFixed(1)} ($ratingCount)',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: ratingCount == 0
                                          ? AppColors.muted
                                          : null,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  const _MiniMeta({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

class _CompactEmptyRebook extends StatelessWidget {
  const _CompactEmptyRebook();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.blue.withValues(alpha: .08),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: AppColors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppStrings.of(context).t('rebookEmpty'),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}