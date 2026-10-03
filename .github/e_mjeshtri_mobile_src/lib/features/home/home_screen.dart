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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t('location'), style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 3),
                            InkWell(
                              onTap: () => context.push('/profile/addresses'),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 18, color: AppColors.blue),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      s.t('myLocation'),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => context.push('/notifications'),
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    first.isEmpty ? s.t('hello') : '${s.t('hello')}, $first',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(s.t('search'), style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 18),
                  TextField(
                    readOnly: true,
                    onTap: () => context.push('/search'),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.blue),
                      hintText: s.t('search'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    title: s.t('categories'),
                    action: s.t('seeAll'),
                    onAction: () => context.push('/categories'),
                  ),
                  const SizedBox(height: 14),
                  categories.when(
                    loading: () => const _CategorySkeleton(),
                    error: (_, __) => EmptyState(icon: Icons.cloud_off_rounded, title: s.t('errorGeneric')),
                    data: (items) => SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.take(8).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => context.push('/categories/${item['id']}'),
                            child: SizedBox(
                              width: 92,
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: AppColors.blue.withValues(alpha: .07),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(_icon(item['icon_key']?.toString()), color: AppColors.blue),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    translatedName(item, language),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _SectionHeader(title: s.t('nearby')),
                  const SizedBox(height: 14),
                  providers.when(
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (_, __) => EmptyState(icon: Icons.cloud_off_rounded, title: s.t('errorGeneric')),
                    data: (items) => items.isEmpty
                        ? EmptyState(icon: Icons.handyman_rounded, title: s.t('noProviders'))
                        : Column(children: items.map((p) => _ProviderCard(provider: p)).toList()),
                  ),
                  const SizedBox(height: 26),
                  _SectionHeader(title: s.t('rebook')),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: repo.orders(),
                    builder: (context, snap) {
                      final completed = (snap.data ?? []).where((o) => o['status'] == 'completed').take(2).toList();
                      if (completed.isEmpty) {
                        return EmptyState(
                          icon: Icons.history_rounded,
                          title: s.t('rebookEmpty'),
                        );
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
  const _ProviderCard({required this.provider});
  final Map<String, dynamic> provider;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => context.push('/providers/${provider['id']}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ProviderAvatar(path: provider['logo_path']?.toString(), size: 54, borderRadius: 18),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                (provider['display_name'] ?? '').toString(),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (hasActiveBlueTick(provider))
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.verified_rounded, size: 18, color: AppColors.blue),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text((provider['city'] ?? '').toString(), style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 18, color: AppColors.orange),
                            const SizedBox(width: 4),
                            Text(
                              '${provider['rating_avg'] ?? 0} (${provider['rating_count'] ?? 0})',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ],
              ),
            ),
          ),
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