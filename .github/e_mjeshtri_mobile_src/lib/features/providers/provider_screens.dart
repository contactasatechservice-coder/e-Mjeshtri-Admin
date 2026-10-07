import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../marketplace/marketplace_repository.dart';
import '../requests/request_flow.dart';
import 'provider_avatar.dart';

bool hasActiveBlueTick(Map<String, dynamic> provider) {
  if (provider['is_verified'] != true) return false;
  final raw = provider['blue_tick_expires_at']?.toString();
  if (raw == null || raw.trim().isEmpty) return true;
  final expires = DateTime.tryParse(raw);
  return expires == null || expires.isAfter(DateTime.now().toUtc());
}

class OfferDetailScreen extends ConsumerStatefulWidget {
  const OfferDetailScreen({super.key, required this.offerId});
  final String offerId;
  @override ConsumerState<OfferDetailScreen> createState()=>_OfferDetailScreenState();
}
class _OfferDetailScreenState extends ConsumerState<OfferDetailScreen>{
  bool busy=false; String? error;
  @override Widget build(BuildContext context){final s=AppStrings.of(context);final repo=ref.read(marketplaceRepositoryProvider);return Scaffold(appBar:AppBar(title:Text(s.t('offer'))),body:FutureBuilder<Map<String,dynamic>>(future:repo.offer(widget.offerId),builder:(context,snap){if(snap.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(snap.hasError)return Center(child:Text(s.t('errorGeneric')));final o=snap.data!;final p=(o['providers'] as Map?)?.cast<String,dynamic>()??{};return ListView(padding:const EdgeInsets.fromLTRB(20,10,20,34),children:[Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[ProviderAvatar(path:p['logo_path']?.toString(),size:60,borderRadius:20),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Flexible(child:Text((p['display_name']??'').toString(),style:Theme.of(context).textTheme.titleLarge)),if(hasActiveBlueTick(p))const Padding(padding:EdgeInsets.only(left:6),child:Icon(Icons.verified_rounded,color:AppColors.blue,size:19))]),const SizedBox(height:5),Row(children:[const Icon(Icons.star_rounded,color:AppColors.orange,size:18),Text(' ${p['rating_avg']??0} (${p['rating_count']??0})',style:const TextStyle(fontWeight:FontWeight.w600))])])),IconButton(onPressed:()=>context.push('/providers/${p['id']}'),icon:const Icon(Icons.chevron_right_rounded))]))),const SizedBox(height:18),Text(s.t('price'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:10),Card(child:Column(children:[_moneyRow(context,s.t('labor'),o['labor_amount'],o['currency']),const Divider(height:1),_moneyRow(context,s.t('materials'),o['materials_amount'],o['currency']),const Divider(height:1),_moneyRow(context,s.t('travel'),o['travel_amount'],o['currency']),const Divider(height:1),_moneyRow(context,s.t('total'),o['total_amount'],o['currency'],strong:true)])),if(o['note']!=null&&o['note'].toString().trim().isNotEmpty)...[const SizedBox(height:18),Text(s.t('note'),style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:8),Text(o['note'].toString(),style:Theme.of(context).textTheme.bodyLarge)],const SizedBox(height:14),Row(children:[const Icon(Icons.schedule_rounded,color:AppColors.blue,size:19),const SizedBox(width:8),Text('${s.t('eta')}: ${o['eta_minutes']??'-'} ${s.t('minutes')}')]),if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:AppColors.danger))],const SizedBox(height:26),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>context.push('/providers/${p['id']}'),icon:const Icon(Icons.person_outline_rounded),label:Text(s.t('viewProfile')))),const SizedBox(width:10),Expanded(child:OutlinedButton.icon(onPressed:()async{final id=await repo.conversationForProvider(p['id'].toString(),requestId:o['request_id']?.toString());if(context.mounted)context.push('/chat/$id');},icon:const Icon(Icons.forum_outlined),label:Text(s.t('message'))))]),const SizedBox(height:12),SizedBox(height:56,child:FilledButton(onPressed:busy?null:()async{setState(()=>busy=true);try{final orderId=await repo.acceptOffer(widget.offerId);if(context.mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s.t('bookingConfirmed'))));context.go('/orders/$orderId');}}catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>busy=false);}},child:busy?const CircularProgressIndicator(color:Colors.white):Text(s.t('acceptOffer'))))]);}));}
  Widget _moneyRow(BuildContext context,String label,dynamic value,dynamic currency,{bool strong=false})=>Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:13),child:Row(children:[Expanded(child:Text(label,style:TextStyle(fontWeight:strong?FontWeight.w800:FontWeight.w500))),Text('$value $currency',style:TextStyle(fontWeight:FontWeight.w800,fontSize:strong?19:15,color:strong?AppColors.blue:null))]));
}

class ProviderProfileScreen extends ConsumerStatefulWidget {
  const ProviderProfileScreen({
    super.key,
    required this.providerId,
  });

  final String providerId;

  @override
  ConsumerState<ProviderProfileScreen> createState() =>
      _ProviderProfileScreenState();
}

class _ProviderProfileScreenState
    extends ConsumerState<ProviderProfileScreen> {
  bool? favorite;
  String _selectedTab = 'services';
  late Future<Map<String, dynamic>> _profileFuture;
  late Future<List<Map<String, dynamic>>> _credentialsFuture;
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<Map<String, dynamic>>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _loadFutures();
    ref
        .read(marketplaceRepositoryProvider)
        .isFavorite(widget.providerId)
        .then((value) {
      if (mounted) setState(() => favorite = value);
    });
  }

  void _loadFutures() {
    final repo = ref.read(marketplaceRepositoryProvider);
    _profileFuture = repo.provider(widget.providerId);
    _credentialsFuture = repo.verifiedCredentials(widget.providerId);
    _statsFuture = repo.providerPublicProfileStats(widget.providerId);
    _reviewsFuture = repo.providerReviews(widget.providerId);
  }

  Future<void> _refresh() async {
    setState(_loadFutures);
    await Future.wait<dynamic>([
      _profileFuture,
      _credentialsFuture,
      _statsFuture,
      _reviewsFuture,
    ]);
  }

  Future<void> _toggleFavorite() async {
    if (favorite == null) return;
    final repo = ref.read(marketplaceRepositoryProvider);
    final next = !favorite!;
    setState(() => favorite = next);
    try {
      await repo.setFavorite(widget.providerId, next);
    } catch (_) {
      if (mounted) setState(() => favorite = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final repo = ref.read(marketplaceRepositoryProvider);
    final language = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(child: Text(strings.t('errorGeneric')));
          }

          final provider = snap.data!;
          final categories =
              (provider['provider_categories'] as List? ?? const []).cast<Map>();
          final allMedia =
              (provider['provider_media'] as List? ?? const []).cast<Map>();
          final media = allMedia
              .where(
                (item) =>
                    (item['caption'] ?? '').toString().trim().toLowerCase() !=
                    'banner',
              )
              .toList();
          final bannerPath = provider['banner_path']?.toString();
          final hasBanner =
              bannerPath != null && bannerPath.trim().isNotEmpty;
          final displayName = (provider['display_name'] ?? 'Mjeshtër').toString();
          final city = (provider['city'] ?? '').toString();
          final bio = (provider['bio'] ?? '').toString().trim();
          final rating = (provider['rating_avg'] ?? 0).toString();
          final ratingCount = provider['rating_count'] ?? 0;
          final yearsExperience = provider['years_experience'];
          final acceptsAsap = provider['accepts_asap'] == true;

          String primaryProfession = 'Mjeshtër';
          if (categories.isNotEmpty) {
            final firstCategory =
                (categories.first['service_categories'] as Map?)
                        ?.cast<String, dynamic>() ??
                    {};
            final translated = translatedName(firstCategory, language).trim();
            if (translated.isNotEmpty) primaryProfession = translated;
          }

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 118),
                  children: [
                    _ProfileHero(
                      provider: provider,
                      hasBanner: hasBanner,
                      bannerPath: bannerPath,
                      displayName: displayName,
                      city: city,
                      profession: primaryProfession,
                      rating: rating,
                      ratingCount: ratingCount,
                      favorite: favorite == true,
                      favoriteEnabled: favorite != null,
                      onBack: () => context.pop(),
                      onFavorite: _toggleFavorite,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _credentialsFuture,
                            builder: (context, credentialSnap) {
                              final credentials = credentialSnap.data ??
                                  const <Map<String, dynamic>>[];
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (provider['is_verified'] == true)
                                    const _VerifiedBadge(
                                      icon: Icons.verified_user_rounded,
                                      label: 'Identitet i verifikuar',
                                      color: AppColors.blue,
                                    ),
                                  if (credentials.isNotEmpty)
                                    const _VerifiedBadge(
                                      icon: Icons.school_rounded,
                                      label: 'Kualifikim i verifikuar',
                                      color: AppColors.success,
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          FutureBuilder<Map<String, dynamic>>(
                            future: _statsFuture,
                            builder: (context, statSnap) {
                              final stats = statSnap.data ??
                                  const <String, dynamic>{};
                              final completedJobs =
                                  stats['completed_jobs'] ?? 0;
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final width =
                                      (constraints.maxWidth - 8) / 2;
                                  final cards = <Widget>[
                                    SizedBox(
                                      width: width,
                                      child: _MetricCard(
                                        icon: Icons.star_rounded,
                                        iconColor: AppColors.orange,
                                        value: rating,
                                        label: '$ratingCount vlerësim',
                                      ),
                                    ),
                                    SizedBox(
                                      width: width,
                                      child: _MetricCard(
                                        icon: Icons.work_rounded,
                                        iconColor: AppColors.success,
                                        value: '$completedJobs',
                                        label: 'Punë të kryera',
                                      ),
                                    ),
                                    if (yearsExperience != null)
                                      SizedBox(
                                        width: width,
                                        child: _MetricCard(
                                          icon: Icons.workspace_premium_rounded,
                                          iconColor: AppColors.blue,
                                          value: '$yearsExperience',
                                          label: 'Vite përvojë',
                                        ),
                                      )
                                    else if (acceptsAsap)
                                      SizedBox(
                                        width: width,
                                        child: const _MetricCard(
                                          icon: Icons.bolt_rounded,
                                          iconColor: AppColors.blue,
                                          value: 'Aktiv',
                                          label: 'Kërkesa të shpejta',
                                        ),
                                      ),
                                    if (city.isNotEmpty)
                                      SizedBox(
                                        width: width,
                                        child: _MetricCard(
                                          icon: Icons.location_on_rounded,
                                          iconColor: AppColors.danger,
                                          value: city,
                                          label: 'Zona e shërbimit',
                                        ),
                                      ),
                                  ];
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: cards,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          _ProfileTabMenu(
                            selected: _selectedTab,
                            onSelected: (value) {
                              setState(() => _selectedTab = value);
                            },
                          ),
                          const SizedBox(height: 10),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: KeyedSubtree(
                              key: ValueKey(_selectedTab),
                              child: _buildSelectedTab(
                                context: context,
                                language: language,
                                strings: strings,
                                categories: categories,
                                media: media,
                                bio: bio,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ProfileActionBar(
                  onMessage: () async {
                    final id = await repo.conversationForProvider(
                      widget.providerId,
                    );
                    if (context.mounted) {
                      context.push('/chat/$id');
                    }
                  },
                  onRequest: categories.isEmpty
                      ? null
                      : () => context.push(
                            '/request/new?categoryId=${categories.first['category_id'] ?? ''}',
                          ),
                  messageLabel: strings.t('message'),
                  requestLabel: strings.t('requestService'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSelectedTab({
    required BuildContext context,
    required String language,
    required AppStrings strings,
    required List<Map> categories,
    required List<Map> media,
    required String bio,
  }) {
    switch (_selectedTab) {
      case 'about':
        return _MiniTabPanel(
          child: bio.isEmpty
              ? const _CompactEmptyState(
                  icon: Icons.person_outline_rounded,
                  text: 'Mjeshtri nuk ka shtuar ende një përshkrim.',
                )
              : Text(
                  bio,
                  style: const TextStyle(
                    color: AppColors.ink,
                    height: 1.45,
                    fontSize: 15,
                  ),
                ),
        );

      case 'education':
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _credentialsFuture,
          builder: (context, credentialSnap) {
            final credentials =
                credentialSnap.data ?? const <Map<String, dynamic>>[];
            return _MiniTabPanel(
              padding: const EdgeInsets.all(12),
              child: credentials.isEmpty
                  ? const _CompactEmptyState(
                      icon: Icons.school_outlined,
                      text: 'Nuk ka kualifikime të verifikuara.',
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < credentials.length; i++) ...[
                          _CredentialCard(credential: credentials[i]),
                          if (i != credentials.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
            );
          },
        );

      case 'portfolio':
        return _MiniTabPanel(
          child: media.isEmpty
              ? const _CompactEmptyState(
                  icon: Icons.photo_library_outlined,
                  text: 'Nuk ka publikuar ende punime.',
                )
              : SizedBox(
                  height: 138,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: media.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final item = media[i];
                      final type = (item['media_type'] ?? 'image').toString();
                      final path = (item['storage_path'] ?? '').toString();
                      return type == 'image' && path.isNotEmpty
                          ? ProviderMediaTile(
                              path: path,
                              width: 176,
                              height: 138,
                            )
                          : Container(
                              width: 176,
                              height: 138,
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: .06),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.play_circle_outline_rounded,
                                color: AppColors.blue,
                                size: 42,
                              ),
                            );
                    },
                  ),
                ),
        );

      case 'reviews':
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _reviewsFuture,
          builder: (context, reviewSnap) {
            final reviews =
                reviewSnap.data ?? const <Map<String, dynamic>>[];
            final visible = reviews.take(3).toList();
            return _MiniTabPanel(
              child: reviews.isEmpty
                  ? const _CompactEmptyState(
                      icon: Icons.reviews_outlined,
                      text: 'Nuk ka ende vlerësime.',
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < visible.length; i++) ...[
                          _ReviewCard(review: visible[i]),
                          if (i != visible.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
            );
          },
        );

      case 'services':
      default:
        return _MiniTabPanel(
          child: categories.isEmpty
              ? const _CompactEmptyState(
                  icon: Icons.home_repair_service_outlined,
                  text: 'Nuk ka shtuar ende shërbime.',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: categories.map((pc) {
                        final category =
                            (pc['service_categories'] as Map?)
                                    ?.cast<String, dynamic>() ??
                                {};
                        final name = translatedName(category, language);
                        final description =
                            _translatedDescription(category, language);
                        return SizedBox(
                          width: cardWidth,
                          child: _ServiceCard(
                            name: name,
                            description: description,
                            icon: _serviceIcon(
                              (category['slug'] ?? '').toString(),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
        );
    }
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.provider,
    required this.hasBanner,
    required this.bannerPath,
    required this.displayName,
    required this.city,
    required this.profession,
    required this.rating,
    required this.ratingCount,
    required this.favorite,
    required this.favoriteEnabled,
    required this.onBack,
    required this.onFavorite,
  });

  final Map<String, dynamic> provider;
  final bool hasBanner;
  final String? bannerPath;
  final String displayName;
  final String city;
  final String profession;
  final String rating;
  final dynamic ratingCount;
  final bool favorite;
  final bool favoriteEnabled;
  final VoidCallback onBack;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final topGap = MediaQuery.of(context).padding.top + 12;
    const bannerHeight = 218.0;
    final heroHeight = topGap + bannerHeight + 120.0;
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 18,
            right: 18,
            top: topGap,
            child: SizedBox(
              height: bannerHeight,
              child: hasBanner
                  ? ProviderMediaTile(
                      path: bannerPath!,
                      width: screenWidth - 36,
                      height: bannerHeight,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.blue.withValues(alpha: .16),
                            AppColors.blue.withValues(alpha: .045),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 30,
            top: topGap + 14,
            child: _BannerActionButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
          ),
          Positioned(
            right: 30,
            top: topGap + 14,
            child: _BannerActionButton(
              icon: favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: favorite ? AppColors.danger : AppColors.ink,
              onTap: favoriteEnabled ? onFavorite : null,
            ),
          ),
          Positioned(
            left: 30,
            top: topGap + bannerHeight - 54,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A172033),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: ProviderAvatar(
                  path: provider['logo_path']?.toString(),
                  size: 108,
                  borderRadius: 999,
                ),
              ),
            ),
          ),
          Positioned(
            left: 154,
            right: 24,
            top: topGap + bannerHeight - 38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.4,
                        ),
                      ),
                    ),
                    if (hasActiveBlueTick(provider))
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.verified_rounded,
                          color: AppColors.blue,
                          size: 24,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [profession, city]
                      .where((x) => x.trim().isNotEmpty)
                      .join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.orange,
                      size: 19,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$rating ($ratingCount vlerësim)',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerActionButton extends StatelessWidget {
  const _BannerActionButton({
    required this.icon,
    required this.onTap,
    this.color = AppColors.ink,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: .92),
        elevation: 2,
        shadowColor: const Color(0x24172033),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: .72),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      );
}

class _ProfileTabMenu extends StatelessWidget {
  const _ProfileTabMenu({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static const items = <(String, String, IconData)>[
    ('services', 'Shërbimet', Icons.build_rounded),
    ('portfolio', 'Punimet', Icons.photo_library_rounded),
    ('reviews', 'Vlerësimet', Icons.star_rounded),
    ('about', 'Rreth meje', Icons.person_rounded),
    ('education', 'Arsim & Kualifikime', Icons.school_rounded),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final active = item.$1 == selected;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelected(item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? AppColors.blue : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active ? AppColors.blue : AppColors.divider,
                  ),
                  boxShadow: active
                      ? const [
                          BoxShadow(
                            color: Color(0x1A0B4A95),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.$3,
                      size: 17,
                      color: active ? Colors.white : AppColors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.$2,
                      style: TextStyle(
                        color: active ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
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

class _MiniTabPanel extends StatelessWidget {
  const _MiniTabPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A172033),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({
    required this.icon,
    required this.onTap,
    this.color = AppColors.ink,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: .94),
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: color, size: 21),
          ),
        ),
      );
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D172033),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A172033),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.blue, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
        ],
      );
}

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({required this.credential});
  final Map<String, dynamic> credential;

  @override
  Widget build(BuildContext context) {
    final program = (credential['program_name'] ?? '').toString();
    final school = (credential['school_name'] ?? '').toString();
    final city = (credential['city'] ?? '').toString();
    final type =
        (credential['credential_type'] ?? 'Kualifikim profesional').toString();
    final year = credential['graduation_year'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.success.withValues(alpha: .22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppColors.blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.success,
                      size: 17,
                    ),
                    const SizedBox(width: 5),
                    const Expanded(
                      child: Text(
                        'Kualifikim profesional i verifikuar',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (program.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    program,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                ],
                if (school.isNotEmpty || city.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [school, city].where((x) => x.isNotEmpty).join(' • '),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  year == null ? type : '$type • $year',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: AppColors.success,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'VERIFIKUAR NGA e-Mjeshtri',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.name,
    required this.description,
    required this.icon,
  });

  final String name;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFE),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.blue, size: 22),
            ),
            const SizedBox(height: 9),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  height: 1.15,
                ),
              ),
            ],
          ],
        ),
      );
}

class _CompactEmptyState extends StatelessWidget {
  const _CompactEmptyState({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.muted, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = (review['comment'] ?? '').toString().trim();
    final clientName =
        (review['client_name'] ?? 'Klient').toString().trim().isEmpty
            ? 'Klient'
            : (review['client_name'] ?? 'Klient').toString().trim();
    final rawDate = (review['created_at'] ?? '').toString();
    final date = DateTime.tryParse(rawDate)?.toLocal();
    final dateLabel = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              clientName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppColors.orange,
                      size: 17,
                    ),
                  ),
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    comment,
                    style: const TextStyle(
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  [
                    'Klient i verifikuar',
                    if (dateLabel.isNotEmpty) dateLabel,
                  ].join(' • '),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionBar extends StatelessWidget {
  const _ProfileActionBar({
    required this.onMessage,
    required this.onRequest,
    required this.messageLabel,
    required this.requestLabel,
  });

  final VoidCallback onMessage;
  final VoidCallback? onRequest;
  final String messageLabel;
  final String requestLabel;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          10 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.divider),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x14172033),
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onMessage,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(messageLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blue,
                    side: const BorderSide(color: AppColors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: onRequest,
                  icon: const Icon(Icons.add_task_rounded),
                  label: Text(requestLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

String _translatedDescription(
  Map<String, dynamic> category,
  String language,
) {
  final translations = category['service_category_translations'];
  if (translations is! List) return '';
  for (final raw in translations) {
    if (raw is Map &&
        (raw['language_code'] ?? '').toString() == language &&
        (raw['description'] ?? '').toString().trim().isNotEmpty) {
      return raw['description'].toString().trim();
    }
  }
  for (final raw in translations) {
    if (raw is Map &&
        (raw['language_code'] ?? '').toString() == 'sq' &&
        (raw['description'] ?? '').toString().trim().isNotEmpty) {
      return raw['description'].toString().trim();
    }
  }
  return '';
}

IconData _serviceIcon(String slug) {
  final s = slug.toLowerCase();
  if (s.contains('electric')) return Icons.electrical_services_rounded;
  if (s.contains('plumb') || s.contains('hidraul')) return Icons.plumbing_rounded;
  if (s.contains('paint') || s.contains('boj')) return Icons.format_paint_rounded;
  if (s.contains('clean')) return Icons.cleaning_services_rounded;
  if (s.contains('appliance')) return Icons.home_repair_service_rounded;
  if (s.contains('solar')) return Icons.solar_power_rounded;
  if (s.contains('camera') || s.contains('security')) {
    return Icons.videocam_rounded;
  }
  if (s.contains('internet') || s.contains('smart')) return Icons.router_rounded;
  if (s.contains('transport')) return Icons.local_shipping_rounded;
  if (s.contains('roof') || s.contains('cati')) return Icons.roofing_rounded;
  if (s.contains('wood') || s.contains('carp')) return Icons.carpenter_rounded;
  return Icons.handyman_rounded;
}
