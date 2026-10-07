import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/blue_tick.dart';
import '../../core/widgets/empty_state.dart';
import '../home/home_repository.dart';
import '../marketplace/marketplace_repository.dart';

String translatedName(Map<String, dynamic> item, String language) {
  final translations = (item['service_category_translations'] as List? ?? const []).cast<Map>();
  for (final t in translations) {
    if (t['language_code'] == language) return (t['name'] ?? item['slug'] ?? '').toString();
  }
  return (item['slug'] ?? '').toString();
}

IconData _serviceCategoryIcon(String? key) => switch (key) {
  'plumbing' => Icons.plumbing_rounded,
  'electrical' => Icons.electrical_services_rounded,
  'ac_unit' => Icons.ac_unit_rounded,
  'format_paint' => Icons.format_paint_rounded,
  'construction' => Icons.construction_rounded,
  'grid_view' => Icons.grid_view_rounded,
  'carpenter' => Icons.carpenter_rounded,
  'door_front' => Icons.door_front_door_rounded,
  'home_repair_service' => Icons.home_repair_service_rounded,
  'cleaning_services' => Icons.cleaning_services_rounded,
  'yard' => Icons.yard_rounded,
  'roofing' => Icons.roofing_rounded,
  'window' => Icons.window_rounded,
  'local_shipping' => Icons.local_shipping_rounded,
  'videocam' => Icons.videocam_rounded,
  'router' => Icons.router_rounded,
  'solar_power' => Icons.solar_power_rounded,
  _ => Icons.handyman_rounded,
};

Color _serviceCategoryColor(String? key) => switch (key) {
  'plumbing' => const Color(0xFF1686D9),
  'electrical' => const Color(0xFFF0A500),
  'ac_unit' => const Color(0xFF5B8DEF),
  'format_paint' => const Color(0xFFE76AA3),
  'construction' => const Color(0xFFE08435),
  'grid_view' => const Color(0xFF7B61D1),
  'carpenter' => const Color(0xFFA86A32),
  'door_front' => const Color(0xFF8B6C4A),
  'home_repair_service' => const Color(0xFF2563EB),
  'cleaning_services' => const Color(0xFF2DB7A3),
  'yard' => const Color(0xFF2FA568),
  'roofing' => const Color(0xFF7250E8),
  'window' => const Color(0xFF16A871),
  'local_shipping' => const Color(0xFFB06B1C),
  'videocam' => const Color(0xFFF05B55),
  'router' => const Color(0xFFF0A500),
  'solar_power' => const Color(0xFF1672D4),
  _ => AppColors.blue,
};

class AllCategoriesScreen extends ConsumerWidget {
  const AllCategoriesScreen({
    super.key,
    this.requestMode = false,
  });

  final bool requestMode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(requestMode ? s.t('chooseService') : s.t('allCategories')),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: FilledButton(onPressed: () => ref.invalidate(categoriesProvider), child: Text(s.t('retry')))),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final item = items[i];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Builder(
                  builder: (context) {
                    final key = item['icon_key']?.toString();
                    final color = _serviceCategoryColor(key);
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _serviceCategoryIcon(key),
                        color: color,
                        size: 25,
                      ),
                    );
                  },
                ),
                title: Text(
                  translatedName(item, language),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => requestMode
                    ? context.push('/request/new?categoryId=${item['id']}')
                    : context.push('/categories/${item['id']}'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({super.key, required this.categoryId});
  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(marketplaceRepositoryProvider);
    final s = AppStrings.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([repo.category(categoryId), repo.childCategories(categoryId)]),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(s.t('errorGeneric')));
          final category = snap.data![0] as Map<String, dynamic>;
          final children = snap.data![1] as List<Map<String, dynamic>>;
          final title = translatedName(category, language);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: [
              Builder(
                builder: (context) {
                  final key = category['icon_key']?.toString();
                  final color = _serviceCategoryColor(key);
                  return Container(
                    height: 112,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      _serviceCategoryIcon(key),
                      size: 54,
                      color: color,
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(s.t('describeProblem'), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 24),
              if (children.isNotEmpty) ...[
                ...children.map((child) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(child: ListTile(title: Text(translatedName(child, language), style: const TextStyle(fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => context.push('/request/new?categoryId=${child['id']}'))),
                    )),
                const SizedBox(height: 6),
              ],
              SizedBox(height: 56, child: FilledButton.icon(onPressed: () => context.push('/request/new?categoryId=$categoryId'), icon: const Icon(Icons.add_rounded), label: Text(children.isEmpty ? s.t('newRequest') : s.t('customProblem')))),
            ],
          );
        },
      ),
    );
  }
}

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key, required this.categoryId});
  final String categoryId;
  @override
  ConsumerState<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _page = PageController();
  final description = TextEditingController();
  final customProblem = TextEditingController();
  final budgetMin = TextEditingController();
  final budgetMax = TextEditingController();
  final ImagePicker picker = ImagePicker();
  final List<XFile> media = [];
  int step = 0;
  String urgency = 'asap';
  DateTime? scheduledFor;
  Map<String, dynamic>? selectedAddress;
  double radius = 10;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    _page.dispose();
    description.dispose();
    customProblem.dispose();
    budgetMin.dispose();
    budgetMax.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await picker.pickMultiImage(imageQuality: 82, limit: 5);
    if (files.isNotEmpty) setState(() => media.addAll(files.where((f) => !media.any((m) => m.path == f.path)).take(5 - media.length)));
  }

  Future<void> _pickCamera() async {
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 82);
    if (file != null && media.length < 5) setState(() => media.add(file));
  }


  Future<void> _pickVideo() async {
    if (media.length >= 5) return;
    final file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (file != null) setState(() => media.add(file));
  }

  Future<void> _chooseSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 180)), initialDate: scheduledFor ?? now);
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime((scheduledFor ?? now).add(const Duration(hours: 1))));
    if (time == null) return;
    setState(() => scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _loadAddress() async {
    final repo = ref.read(marketplaceRepositoryProvider);
    final addresses = await repo.addresses();
    if (!mounted) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [Expanded(child: Text(AppStrings.of(context).t('chooseAddress'), style: Theme.of(context).textTheme.titleLarge)), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))]),
            const SizedBox(height: 10),
            if (addresses.isEmpty) EmptyState(icon: Icons.location_off_outlined, title: AppStrings.of(context).t('noSavedAddress')),
            ...addresses.map((a) => ListTile(leading: const Icon(Icons.location_on_outlined), title: Text('${a['street']} ${a['street_number'] ?? ''}'), subtitle: Text('${a['city']} ${a['postal_code'] ?? ''}'), trailing: a['is_primary'] == true ? const Icon(Icons.star_rounded, color: AppColors.orange) : null, onTap: () => Navigator.pop(context, a))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () async { Navigator.pop(context); await context.push('/profile/addresses'); }, icon: const Icon(Icons.add_location_alt_outlined), label: Text(AppStrings.of(context).t('addAddress')))),
          ]),
        ),
      ),
    );
    if (picked != null) setState(() => selectedAddress = picked);
  }

  bool _validateStep() {
    setState(() => error = null);
    if (step == 0 && description.text.trim().length < 10) {
      setState(() => error = AppStrings.of(context).t('descriptionMin'));
      return false;
    }
    if (step == 2 && selectedAddress == null) {
      setState(() => error = AppStrings.of(context).t('chooseAddressError'));
      return false;
    }
    if (step == 3 && urgency == 'scheduled' && scheduledFor == null) {
      setState(() => error = AppStrings.of(context).t('chooseScheduleError'));
      return false;
    }
    return true;
  }

  void _next() {
    if (!_validateStep()) return;
    if (step < 4) {
      setState(() => step++);
      _page.animateToPage(step, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
    }
  }

  void _back() {
    if (step == 0) {
      context.pop();
      return;
    }
    setState(() => step--);
    _page.animateToPage(step, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
  }

  double? _number(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _submit({required bool publish}) async {
    if (!_validateStep() || selectedAddress == null) return;
    setState(() { busy = true; error = null; });
    try {
      final repo = ref.read(marketplaceRepositoryProvider);
      final a = selectedAddress!;
      final request = await repo.createRequest(
        categoryId: widget.categoryId,
        description: description.text,
        customProblem: customProblem.text,
        urgency: urgency,
        scheduledFor: urgency == 'scheduled' ? scheduledFor : null,
        city: (a['city'] ?? '').toString(),
        lat: (a['latitude'] as num?)?.toDouble(),
        lng: (a['longitude'] as num?)?.toDouble(),
        budgetMin: _number(budgetMin),
        budgetMax: _number(budgetMax),
        searchRadiusKm: radius,
        publish: publish,
        privateLocation: {
          'source_address_id': a['id'], 'street': a['street'], 'street_number': a['street_number'], 'city': a['city'], 'postal_code': a['postal_code'],
          'entrance': a['entrance'], 'floor': a['floor'], 'apartment': a['apartment'], 'note': a['note'], 'latitude': a['latitude'], 'longitude': a['longitude'],
        },
      );
      final requestId = request['id'].toString();
      for (final file in media) {
        final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
        final normalizedExt = ext == 'jpeg' ? 'jpg' : ext;
        final isVideo = const {'mp4', 'mov', 'm4v'}.contains(normalizedExt);
        await repo.uploadRequestMedia(
          requestId: requestId,
          bytes: await file.readAsBytes(),
          extension: normalizedExt,
          mediaType: isVideo ? 'video' : 'image',
        );
      }
      if (!mounted) return;
      if (publish) {
        context.go('/request/$requestId/searching');
      } else {
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).t('saveDraft'))));
      }
    } catch (e) {
      if (mounted) setState(() => error = AppStrings.of(context).t('errorGeneric'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back_rounded)), title: Text(s.t('newRequest'))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 2, 20, 10), child: Row(children: List.generate(5, (i) => Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 180), height: 4, margin: EdgeInsets.only(right: i == 4 ? 0 : 6), decoration: BoxDecoration(color: i <= step ? AppColors.blue : AppColors.divider, borderRadius: BorderRadius.circular(4))))))),
        Expanded(
          child: PageView(
            controller: _page,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _ProblemStep(description: description, customProblem: customProblem),
              _MediaStep(media: media, onGallery: _pickImages, onCamera: _pickCamera, onVideo: _pickVideo, onRemove: (i) => setState(() => media.removeAt(i))),
              _AddressStep(address: selectedAddress, onChoose: _loadAddress),
              _ScheduleStep(urgency: urgency, onUrgency: (v) => setState(() => urgency = v), scheduledFor: scheduledFor, onSchedule: _chooseSchedule, budgetMin: budgetMin, budgetMax: budgetMax, radius: radius, onRadius: (v) => setState(() => radius = v)),
              _SummaryStep(description: description.text, mediaCount: media.length, address: selectedAddress, urgency: urgency, scheduledFor: scheduledFor, min: _number(budgetMin), max: _number(budgetMax), radius: radius),
            ],
          ),
        ),
        if (error != null) Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Text(error!, style: const TextStyle(color: AppColors.danger))),
        SafeArea(top: false, minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: step == 4
            ? Row(children: [Expanded(child: OutlinedButton(onPressed: busy ? null : () => _submit(publish: false), child: Text(s.t('saveDraft')))), const SizedBox(width: 12), Expanded(child: FilledButton(onPressed: busy ? null : () => _submit(publish: true), child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(s.t('publishRequest'))))])
            : SizedBox(width: double.infinity, height: 54, child: FilledButton(onPressed: _next, child: Text(s.t('continue'))))),
      ]),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.title, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [Text(title, style: Theme.of(context).textTheme.headlineMedium), if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted))], const SizedBox(height: 24), ...children]);
}

class _ProblemStep extends StatelessWidget {
  const _ProblemStep({required this.description, required this.customProblem});
  final TextEditingController description, customProblem;
  @override Widget build(BuildContext context) { final s = AppStrings.of(context); return _StepBody(title: s.t('describeProblem'), children: [TextField(controller: customProblem, decoration: InputDecoration(labelText: s.t('customProblem'))), const SizedBox(height: 14), TextField(controller: description, minLines: 5, maxLines: 9, maxLength: 1200, decoration: InputDecoration(hintText: s.t('problemHint'), alignLabelWithHint: true))]); }
}

class _MediaStep extends StatelessWidget {
  const _MediaStep({
    required this.media,
    required this.onGallery,
    required this.onCamera,
    required this.onVideo,
    required this.onRemove,
  });
  final List<XFile> media;
  final VoidCallback onGallery, onCamera, onVideo;
  final ValueChanged<int> onRemove;

  bool _isVideo(XFile file) {
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    return const {'mp4', 'mov', 'm4v'}.contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return _StepBody(
      title: s.t('media'),
      subtitle: s.t('mediaHelp'),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(s.t('camera')),
            ),
            OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(s.t('addPhotos')),
            ),
            OutlinedButton.icon(
              onPressed: onVideo,
              icon: const Icon(Icons.videocam_outlined),
              label: Text(s.t('video')),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (media.isEmpty)
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: .04),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Center(
              child: Icon(Icons.add_photo_alternate_outlined, size: 52, color: AppColors.muted),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(media.length, (i) {
              final file = media[i];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _isVideo(file)
                        ? Container(
                            width: 96,
                            height: 96,
                            color: AppColors.blue.withValues(alpha: .08),
                            child: const Icon(Icons.play_circle_fill_rounded, size: 42, color: AppColors.blue),
                          )
                        : Image.file(File(file.path), width: 96, height: 96, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => onRemove(i),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
      ],
    );
  }
}

class _AddressStep extends StatelessWidget {
  const _AddressStep({required this.address, required this.onChoose});
  final Map<String,dynamic>? address;
  final VoidCallback onChoose;
  @override Widget build(BuildContext context){final s=AppStrings.of(context);return _StepBody(title:s.t('address'),subtitle:s.t('exactAddressPrivacy'),children:[Card(child:address==null?ListTile(leading:const Icon(Icons.add_location_alt_outlined,color:AppColors.blue),title:Text(s.t('chooseAddress')),trailing:const Icon(Icons.chevron_right_rounded),onTap:onChoose):ListTile(leading:const Icon(Icons.location_on_rounded,color:AppColors.blue),title:Text('${address!['street']} ${address!['street_number']??''}'),subtitle:Text('${address!['city']} ${address!['postal_code']??''}'),trailing:TextButton(onPressed:onChoose,child:Text(s.t('edit')))))]);}
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({required this.urgency,required this.onUrgency,required this.scheduledFor,required this.onSchedule,required this.budgetMin,required this.budgetMax,required this.radius,required this.onRadius});
  final String urgency; final ValueChanged<String> onUrgency; final DateTime? scheduledFor; final VoidCallback onSchedule; final TextEditingController budgetMin,budgetMax; final double radius; final ValueChanged<double> onRadius;
  @override Widget build(BuildContext context){final s=AppStrings.of(context);final df=DateFormat('dd/MM/yyyy HH:mm');return _StepBody(title:s.t('schedule'),children:[Wrap(spacing:8,children:[ChoiceChip(label:Text(s.t('asap')),selected:urgency=='asap',onSelected:(_)=>onUrgency('asap')),ChoiceChip(label:Text(s.t('scheduled')),selected:urgency=='scheduled',onSelected:(_)=>onUrgency('scheduled')),ChoiceChip(label:Text(s.t('urgent')),selected:urgency=='urgent',onSelected:(_)=>onUrgency('urgent'))]),if(urgency=='scheduled')...[const SizedBox(height:16),Card(child:ListTile(leading:const Icon(Icons.event_rounded,color:AppColors.blue),title:Text(scheduledFor==null?s.t('chooseDate'):df.format(scheduledFor!)),trailing:const Icon(Icons.chevron_right_rounded),onTap:onSchedule))],const SizedBox(height:24),Text(s.t('budget'),style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:10),Row(children:[Expanded(child:TextField(controller:budgetMin,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:s.t('minPrice'),suffixText:'ALL'))),const SizedBox(width:10),Expanded(child:TextField(controller:budgetMax,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:s.t('maxPrice'),suffixText:'ALL')))]),const SizedBox(height:24),Row(children:[Expanded(child:Text(s.t('radius'),style:Theme.of(context).textTheme.titleMedium)),Text('${(radius ?? 10).round()} km',style:const TextStyle(fontWeight:FontWeight.w700,color:AppColors.blue))]),Slider(value:radius,min:5,max:50,divisions:9,onChanged:onRadius)]);}
}

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({required this.description,required this.mediaCount,required this.address,required this.urgency,required this.scheduledFor,required this.min,required this.max,required this.radius});
  final String description; final int mediaCount; final Map<String,dynamic>? address; final String urgency; final DateTime? scheduledFor; final double? min,max,radius;
  @override Widget build(BuildContext context){final s=AppStrings.of(context);return _StepBody(title:s.t('summary'),children:[_summaryCard(Icons.description_outlined,s.t('describeProblem'),description),_summaryCard(Icons.photo_library_outlined,s.t('media'),'$mediaCount'),_summaryCard(Icons.location_on_outlined,s.t('address'),address==null?'-':'${address!['street']} ${address!['street_number']??''}, ${address!['city']}'),_summaryCard(Icons.schedule_rounded,s.t('schedule'),urgency=='scheduled'&&scheduledFor!=null?DateFormat('dd/MM/yyyy HH:mm').format(scheduledFor!):urgency),_summaryCard(Icons.payments_outlined,s.t('budget'),min==null&&max==null?'-':'${min?.toStringAsFixed(0)??'0'} - ${max?.toStringAsFixed(0)??'∞'} ALL'),_summaryCard(Icons.radar_rounded,s.t('radius'),'${(radius ?? 10).round()} km')]);}
  Widget _summaryCard(IconData icon,String title,String value)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:AppColors.blue),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:4),Text(value,maxLines:4,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppColors.muted))]))]))));
}

class RequestSearchingScreen extends ConsumerWidget {
  const RequestSearchingScreen({super.key, required this.requestId});
  final String requestId;
  @override Widget build(BuildContext context,WidgetRef ref){final s=AppStrings.of(context);return Scaffold(appBar:AppBar(),body:SafeArea(child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[const Spacer(),Container(width:150,height:150,decoration:BoxDecoration(color:AppColors.blue.withValues(alpha:.07),shape:BoxShape.circle),child:const Center(child:SizedBox(width:72,height:72,child:CircularProgressIndicator(strokeWidth:5)))),const SizedBox(height:28),Text(s.t('searchingPros'),textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:12),Text(s.t('offersWaiting'),textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodyLarge?.copyWith(color:AppColors.muted)),const Spacer(),SizedBox(width:double.infinity,height:54,child:FilledButton(onPressed:()=>context.go('/request/$requestId/offers'),child:Text(s.t('offers')))),const SizedBox(height:8),TextButton(onPressed:()=>context.go('/home'),child:Text(s.t('home')))]))));}
}

class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  late Future<List<Map<String, dynamic>>> future;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    future = ref.read(marketplaceRepositoryProvider).offers(widget.requestId);
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) reload();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void reload() {
    setState(() {
      future = ref.read(marketplaceRepositoryProvider).offers(widget.requestId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: s.t('home'),
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(s.t('offers')),
        actions: [
          IconButton(
            tooltip: s.t('home'),
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
            return Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Expanded(child: EmptyState(icon: Icons.hourglass_empty_rounded, title: s.t('noOffers'))),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(marketplaceRepositoryProvider).expandRequestRadius(widget.requestId, 25);
                        if (context.mounted) {
                          reload();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('expandRadius'))));
                        }
                      },
                      icon: const Icon(Icons.radar_rounded),
                      label: Text(s.t('expandRadius')),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final o = items[i];
                final p = (o['providers'] as Map?)?.cast<String, dynamic>() ?? {};
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => context.push('/offers/${o['id']}'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Icon(Icons.handyman_rounded, color: AppColors.blue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        (p['display_name'] ?? '').toString(),
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                    ),
                                    if (hasActiveBlueTick(p))
                                      const Padding(
                                        padding: EdgeInsets.only(left: 5),
                                        child: Icon(Icons.verified_rounded, size: 17, color: AppColors.blue),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${o['total_amount']} ${o['currency']}',
                                  style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 17, color: AppColors.orange),
                                    Text(
                                      ' ${p['rating_avg'] ?? 0}  •  ${o['eta_minutes'] ?? '-'} ${s.t('minutes')}',
                                      style: const TextStyle(color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class RequestSummaryScreen extends ConsumerStatefulWidget {
  const RequestSummaryScreen({super.key,required this.requestId});final String requestId;
  @override ConsumerState<RequestSummaryScreen> createState()=>_RequestSummaryScreenState();
}
class _RequestSummaryScreenState extends ConsumerState<RequestSummaryScreen>{bool busy=false;@override Widget build(BuildContext context){final s=AppStrings.of(context);final repo=ref.read(marketplaceRepositoryProvider);return Scaffold(appBar:AppBar(title:Text(s.t('viewRequest'))),body:FutureBuilder<Map<String,dynamic>>(future:repo.request(widget.requestId),builder:(context,snap){if(snap.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(snap.hasError)return Center(child:Text(s.t('errorGeneric')));final r=snap.data!;final c=(r['service_categories'] as Map?)?.cast<String,dynamic>()??{};final loc=(r['request_private_locations'] as List? ?? const []).cast<Map>();return ListView(padding:const EdgeInsets.all(20),children:[Text(translatedName(c,Localizations.localeOf(context).languageCode),style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:14),Card(child:Padding(padding:const EdgeInsets.all(16),child:Text((r['description']??'').toString(),style:Theme.of(context).textTheme.bodyLarge))),const SizedBox(height:10),if(loc.isNotEmpty)Card(child:ListTile(leading:const Icon(Icons.location_on_outlined,color:AppColors.blue),title:Text('${loc.first['street']} ${loc.first['street_number']??''}'),subtitle:Text((loc.first['city']??'').toString()))),const SizedBox(height:10),Card(child:ListTile(leading:const Icon(Icons.radar_rounded,color:AppColors.blue),title:Text('${s.t('radius')}: ${r['search_radius_km']} km'),subtitle:Text('${s.t('status')}: ${r['status']}'))),const SizedBox(height:22),if(r['status']=='draft')SizedBox(height:54,child:FilledButton(onPressed:busy?null:()async{setState(()=>busy=true);try{await repo.publishRequest(widget.requestId);if(context.mounted)context.go('/request/${widget.requestId}/searching');}finally{if(mounted)setState(()=>busy=false);}},child:Text(s.t('publishRequest'))))else SizedBox(height:54,child:FilledButton(onPressed:()=>context.go('/request/${widget.requestId}/offers'),child:Text(s.t('offers'))))]);}));}}