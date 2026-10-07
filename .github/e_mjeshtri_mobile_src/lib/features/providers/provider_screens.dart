import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../marketplace/marketplace_repository.dart';
import '../requests/request_flow.dart';
import 'provider_avatar.dart';

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

  @override
  void initState() {
    super.initState();
    ref
        .read(marketplaceRepositoryProvider)
        .isFavorite(widget.providerId)
        .then((value) {
      if (mounted) setState(() => favorite = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final repo = ref.read(marketplaceRepositoryProvider);
    final language = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: favorite == null
                ? null
                : () async {
                    final next = !favorite!;
                    setState(() => favorite = next);
                    await repo.setFavorite(widget.providerId, next);
                  },
            icon: Icon(
              favorite == true
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: favorite == true ? AppColors.danger : null,
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: repo.provider(widget.providerId),
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
          final screenWidth = MediaQuery.of(context).size.width;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
            children: [
              if (bannerPath != null && bannerPath.trim().isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  height: 176,
                  child: ProviderMediaTile(
                    path: bannerPath,
                    width: screenWidth - 40,
                    height: 176,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Center(
                child: ProviderAvatar(
                  path: provider['logo_path']?.toString(),
                  size: 94,
                  borderRadius: 30,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      (provider['display_name'] ?? '').toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  if (hasActiveBlueTick(provider))
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.verified_rounded,
                        color: AppColors.blue,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: AppColors.orange,
                    size: 19,
                  ),
                  Text(
                    ' ${provider['rating_avg'] ?? 0} '
                    '(${provider['rating_count'] ?? 0})'
                    '  •  ${provider['city'] ?? ''}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if ((provider['bio'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  provider['bio'].toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 24),
              Text(
                strings.t('services'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (categories.isEmpty)
                const EmptyState(
                  icon: Icons.home_repair_service_outlined,
                  title: '—',
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((pc) {
                    final category =
                        (pc['service_categories'] as Map?)
                                ?.cast<String, dynamic>() ??
                            {};
                    return Chip(
                      label: Text(translatedName(category, language)),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),
              Text(
                strings.t('portfolio'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (media.isEmpty)
                const EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: '—',
                )
              else
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: media.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final item = media[i];
                      final type =
                          (item['media_type'] ?? 'image').toString();
                      final path =
                          (item['storage_path'] ?? '').toString();
                      return type == 'image' && path.isNotEmpty
                          ? ProviderMediaTile(
                              path: path,
                              width: 150,
                              height: 112,
                            )
                          : Container(
                              width: 150,
                              height: 112,
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: .06),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.play_circle_outline_rounded,
                                color: AppColors.blue,
                                size: 40,
                              ),
                            );
                    },
                  ),
                ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final id = await repo.conversationForProvider(
                          widget.providerId,
                        );
                        if (context.mounted) {
                          context.push('/chat/$id');
                        }
                      },
                      icon: const Icon(Icons.forum_outlined),
                      label: Text(strings.t('message')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: categories.isEmpty
                          ? null
                          : () => context.push(
                                '/request/new?categoryId=${categories.first['category_id'] ?? ''}',
                              ),
                      icon: const Icon(Icons.add_task_rounded),
                      label: Text(strings.t('requestService')),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
