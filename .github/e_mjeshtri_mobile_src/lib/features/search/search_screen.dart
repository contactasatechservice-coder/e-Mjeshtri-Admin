import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../home/home_repository.dart';
import '../marketplace/marketplace_repository.dart';
import '../providers/provider_avatar.dart';
import '../requests/request_flow.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final controller = TextEditingController();
  String query = '';
  bool verifiedOnly = false;
  double minRating = 0;
  bool mapMode = false;
  late Future<List<Map<String, dynamic>>> providersFuture;

  @override
  void initState() {
    super.initState();
    providersFuture = _loadProviders();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadProviders() => ref.read(marketplaceRepositoryProvider).searchProviders(
        query: query,
        verifiedOnly: verifiedOnly,
        minRating: minRating,
      );

  void refreshProviders() => setState(() => providersFuture = _loadProviders());

  void filters() {
    var draftVerified = verifiedOnly;
    var draftRating = minRating;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final s = AppStrings.of(context);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(s.t('filters'), style: Theme.of(context).textTheme.titleLarge)),
                      TextButton(
                        onPressed: () => setSheet(() {
                          draftVerified = false;
                          draftRating = 0;
                        }),
                        child: Text(s.t('clear')),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.t('verifiedOnly')),
                    value: draftVerified,
                    onChanged: (v) => setSheet(() => draftVerified = v),
                  ),
                  Text('${s.t('minimumRating')}: ${draftRating.toStringAsFixed(1)}'),
                  Slider(value: draftRating, min: 0, max: 5, divisions: 10, onChanged: (v) => setSheet(() => draftRating = v)),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          verifiedOnly = draftVerified;
                          minRating = draftRating;
                          providersFuture = _loadProviders();
                        });
                        Navigator.pop(context);
                      },
                      child: Text(s.t('apply')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('searchServices')),
        actions: [IconButton(onPressed: filters, icon: const Icon(Icons.tune_rounded))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (v) {
                    query = v.trim().toLowerCase();
                    setState(() => providersFuture = _loadProviders());
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.blue),
                    hintText: s.t('search'),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              controller.clear();
                              query = '';
                              refreshProviders();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, icon: const Icon(Icons.view_list_rounded), label: Text(s.t('listView'))),
                    ButtonSegment(value: true, icon: const Icon(Icons.map_outlined), label: Text(s.t('mapView'))),
                  ],
                  selected: {mapMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (values) => setState(() => mapMode = values.first),
                ),
              ],
            ),
          ),
          Expanded(child: mapMode ? _mapBody(context) : _listBody(context)),
        ],
      ),
    );
  }

  Widget _listBody(BuildContext context) {
    final s = AppStrings.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final categories = ref.watch(categoriesProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(s.t('categories'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Text(s.t('errorGeneric')),
          data: (items) {
            final filtered = items.where((e) {
              final slug = (e['slug'] ?? '').toString().toLowerCase();
              final name = translatedName(e, language).toLowerCase();
              return query.isEmpty || slug.contains(query) || name.contains(query);
            }).take(8).toList();
            if (filtered.isEmpty) return const SizedBox.shrink();
            return Column(
              children: filtered
                  .map(
                    (e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: .08), borderRadius: BorderRadius.circular(13)),
                        child: const Icon(Icons.home_repair_service_rounded, color: AppColors.blue, size: 21),
                      ),
                      title: Text(translatedName(e, language), style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/categories/${e['id']}'),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 22),
        Text(s.t('nearby'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: providersFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) return Text(s.t('errorGeneric'));
            final providers = snap.data ?? [];
            if (providers.isEmpty) {
              return Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(s.t('noProviders'), style: const TextStyle(color: AppColors.muted)));
            }
            return Column(children: providers.map((p) => _providerListCard(context, p)).toList());
          },
        ),
      ],
    );
  }

  Widget _mapBody(BuildContext context) {
    final s = AppStrings.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: providersFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(s.t('errorGeneric')));
        final providers = (snap.data ?? []).where((p) => p['latitude'] != null && p['longitude'] != null).toList();
        if (providers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: EmptyState(icon: Icons.map_outlined, title: s.t('noProviders')),
          );
        }
        final first = providers.first;
        final center = LatLng((first['latitude'] as num).toDouble(), (first['longitude'] as num).toDouble());
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 11.5),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.emjeshtri.client',
                ),
                MarkerLayer(
                  markers: providers.map((p) {
                    final point = LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble());
                    return Marker(
                      point: point,
                      width: 54,
                      height: 54,
                      child: GestureDetector(
                        onTap: () => context.push('/providers/${p['id']}'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 12, offset: const Offset(0, 5))],
                          ),
                          child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 25),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SimpleAttributionWidget(source: Text('© OpenStreetMap contributors')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _providerListCard(BuildContext context, Map<String, dynamic> p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          leading: ProviderAvatar(path: p['logo_path']?.toString(), size: 48, borderRadius: 16),
          title: Row(
            children: [
              Flexible(child: Text((p['display_name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
              if (hasActiveBlueTick(p))
                const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.verified_rounded, size: 16, color: AppColors.blue)),
            ],
          ),
          subtitle: Text('${p['city'] ?? ''} • ★ ${p['rating_avg'] ?? 0}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/providers/${p['id']}'),
        ),
      ),
    );
  }
}