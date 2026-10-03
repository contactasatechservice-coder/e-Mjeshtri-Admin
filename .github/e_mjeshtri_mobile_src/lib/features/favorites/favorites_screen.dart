import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../marketplace/marketplace_repository.dart';
import '../providers/provider_avatar.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = ref.read(marketplaceRepositoryProvider).favorites();
  }

  void reload() {
    setState(() {
      future = ref.read(marketplaceRepositoryProvider).favorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Text(s.t('favorites'), style: Theme.of(context).textTheme.headlineMedium),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: FilledButton(onPressed: reload, child: Text(s.t('retry'))));
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return EmptyState(icon: Icons.favorite_border_rounded, title: s.t('noFavorites'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final f = items[i];
                    final p = (f['providers'] as Map?)?.cast<String, dynamic>() ?? {};
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        leading: ProviderAvatar(path: p['logo_path']?.toString(), size: 50, borderRadius: 17),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                (p['display_name'] ?? '').toString(),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (hasActiveBlueTick(p))
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.verified_rounded, size: 16, color: AppColors.blue),
                              ),
                          ],
                        ),
                        subtitle: Text('${p['city'] ?? ''} • ★ ${p['rating_avg'] ?? 0}'),
                        trailing: IconButton(
                          onPressed: () async {
                            await ref.read(marketplaceRepositoryProvider).setFavorite(p['id'].toString(), false);
                            reload();
                          },
                          icon: const Icon(Icons.favorite_rounded, color: AppColors.danger),
                        ),
                        onTap: () => context.push('/providers/${p['id']}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}