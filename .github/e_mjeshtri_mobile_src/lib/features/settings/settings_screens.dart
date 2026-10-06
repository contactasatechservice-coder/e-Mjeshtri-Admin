import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/storage/local_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/empty_state.dart';
import '../auth/auth_repository.dart';
import '../marketplace/marketplace_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final first = TextEditingController();
  final last = TextEditingController();
  final phone = TextEditingController();
  final picker = ImagePicker();
  bool loading = true;
  bool saving = false;
  bool avatarBusy = false;
  String? error;
  String? avatarPath;
  String? avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(marketplaceRepositoryProvider);
      final p = await repo.profile();
      first.text = (p['first_name'] ?? '').toString();
      last.text = (p['last_name'] ?? '').toString();
      phone.text = (p['phone'] ?? '').toString();
      avatarPath = p['avatar_path']?.toString();
      avatarUrl = await repo.avatarSignedUrl(avatarPath);
    } catch (e) {
      error = AppStrings.of(context).t('errorGeneric');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 86, maxWidth: 1200);
    if (file == null) return;
    setState(() => avatarBusy = true);
    try {
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
      final repo = ref.read(marketplaceRepositoryProvider);
      final oldPath = avatarPath;
      final newPath = await repo.uploadAvatar(bytes: await file.readAsBytes(), extension: ext == 'jpeg' ? 'jpg' : ext);
      final url = await repo.avatarSignedUrl(newPath);
      if (oldPath != null && oldPath != newPath) {
        try { await Supabase.instance.client.storage.from('avatars').remove([oldPath]); } catch (_) {}
      }
      if (mounted) setState(() { avatarPath = newPath; avatarUrl = url; });
    } catch (e) {
      if (mounted) setState(() => error = AppStrings.of(context).t('errorGeneric'));
    } finally {
      if (mounted) setState(() => avatarBusy = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => avatarBusy = true);
    try {
      await ref.read(marketplaceRepositoryProvider).removeAvatar(avatarPath);
      if (mounted) setState(() { avatarPath = null; avatarUrl = null; });
    } finally {
      if (mounted) setState(() => avatarBusy = false);
    }
  }

  @override
  void dispose() {
    first.dispose(); last.dispose(); phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('editProfile'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: .08),
                          shape: BoxShape.circle,
                        ),
                        child: avatarUrl == null
                            ? const Icon(Icons.person_rounded, size: 48, color: AppColors.blue)
                            : Image.network(avatarUrl!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          onPressed: avatarBusy ? null : _pickAvatar,
                          icon: avatarBusy
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.photo_camera_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                if (avatarPath != null)
                  Center(child: TextButton(onPressed: avatarBusy ? null : _removeAvatar, child: Text(s.t('removePhoto')))),
                const SizedBox(height: 18),
                TextField(controller: first, decoration: InputDecoration(labelText: s.t('firstName'))),
                const SizedBox(height: 12),
                TextField(controller: last, decoration: InputDecoration(labelText: s.t('lastName'))),
                const SizedBox(height: 12),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: s.t('phone'))),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setState(() => saving = true);
                            try {
                              await ref.read(marketplaceRepositoryProvider).updateProfile(
                                firstName: first.text,
                                lastName: last.text,
                                phone: phone.text,
                              );
                              if (context.mounted) context.pop();
                            } catch (e) {
                              if (mounted) setState(() => error = AppStrings.of(context).t('errorGeneric'));
                            } finally {
                              if (mounted) setState(() => saving = false);
                            }
                          },
                    child: Text(s.t('saveChanges')),
                  ),
                ),
              ],
            ),
    );
  }
}

class AddressesScreen extends ConsumerStatefulWidget {const AddressesScreen({super.key});@override ConsumerState<AddressesScreen> createState()=>_AddressesScreenState();}
class _AddressesScreenState extends ConsumerState<AddressesScreen>{late Future<List<Map<String,dynamic>>> future;@override void initState(){super.initState();future=ref.read(marketplaceRepositoryProvider).addresses();}void reload()=>setState(()=>future=ref.read(marketplaceRepositoryProvider).addresses());@override Widget build(BuildContext context){final s=AppStrings.of(context);return Scaffold(appBar:AppBar(title:Text(s.t('addresses'))),floatingActionButton:FloatingActionButton.extended(onPressed:()async{await context.push('/profile/addresses/edit');reload();},icon:const Icon(Icons.add_location_alt_outlined),label:Text(s.t('addAddress'))),body:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,snap){if(snap.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(snap.hasError)return Center(child:Text(s.t('errorGeneric')));final items=snap.data??[];if(items.isEmpty)return EmptyState(icon:Icons.location_off_outlined,title:s.t('addAddress'));return ListView.separated(padding:const EdgeInsets.fromLTRB(18,12,18,100),itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(_,i){final a=items[i];return Card(child:ListTile(leading:Icon(a['is_primary']==true?Icons.home_rounded:Icons.location_on_outlined,color:AppColors.blue),title:Text('${a['street']} ${a['street_number']??''}',style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${a['city']} ${a['postal_code']??''}'),trailing:PopupMenuButton<String>(onSelected:(v)async{if(v=='edit'){await context.push('/profile/addresses/edit',extra:a);reload();}else if(v=='delete'){await ref.read(marketplaceRepositoryProvider).deleteAddress(a['id'].toString());reload();}},itemBuilder:(_)=>[PopupMenuItem(value:'edit',child:Text(s.t('edit'))),PopupMenuItem(value:'delete',child:Text(s.t('delete')))])));});}));}}

class AddressEditScreen extends ConsumerStatefulWidget {
  const AddressEditScreen({super.key, this.initial});
  final Map<String, dynamic>? initial;
  @override
  ConsumerState<AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends ConsumerState<AddressEditScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController street, number, city, postal, entrance, floor, apartment, note;
  bool primary = false, busy = false, locating = false;
  double? latitude, longitude;

  @override
  void initState() {
    super.initState();
    final a = widget.initial ?? {};
    street = TextEditingController(text: (a['street'] ?? '').toString());
    number = TextEditingController(text: (a['street_number'] ?? '').toString());
    city = TextEditingController(text: (a['city'] ?? '').toString());
    postal = TextEditingController(text: (a['postal_code'] ?? '').toString());
    entrance = TextEditingController(text: (a['entrance'] ?? '').toString());
    floor = TextEditingController(text: (a['floor'] ?? '').toString());
    apartment = TextEditingController(text: (a['apartment'] ?? '').toString());
    note = TextEditingController(text: (a['note'] ?? '').toString());
    primary = a['is_primary'] == true;
    latitude = (a['latitude'] as num?)?.toDouble();
    longitude = (a['longitude'] as num?)?.toDouble();
  }

  @override
  void dispose() {
    for (final c in [street, number, city, postal, entrance, floor, apartment, note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _currentLocation() async {
    setState(() => locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw StateError(AppStrings.of(context).t('gpsDisabled'));
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw StateError(AppStrings.of(context).t('locationDenied'));
      }
      final p = await Geolocator.getCurrentPosition();
      if (mounted) setState(() { latitude = p.latitude; longitude = p.longitude; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).t('errorGeneric'))));
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final center = LatLng(latitude ?? 41.1533, longitude ?? 20.1683);
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? s.t('addAddress') : s.t('edit'))),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(controller: street, decoration: InputDecoration(labelText: s.t('street')), validator: (v) => v == null || v.trim().isEmpty ? '*' : null),
            const SizedBox(height: 12),
            TextFormField(controller: number, decoration: InputDecoration(labelText: s.t('streetNumber'))),
            const SizedBox(height: 12),
            TextFormField(controller: city, decoration: InputDecoration(labelText: s.t('city')), validator: (v) => v == null || v.trim().isEmpty ? '*' : null),
            const SizedBox(height: 12),
            TextFormField(controller: postal, decoration: InputDecoration(labelText: s.t('postalCode'))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: entrance, decoration: InputDecoration(labelText: s.t('entrance')))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: floor, decoration: InputDecoration(labelText: s.t('floor')))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: apartment, decoration: InputDecoration(labelText: s.t('apartment')))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: note, maxLines: 3, decoration: InputDecoration(labelText: s.t('note'))),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Text(s.t('tapMapPin'), style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(
                onPressed: locating ? null : _currentLocation,
                icon: locating ? const SizedBox.square(dimension: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded),
                label: Text(s.t('useCurrentLocation')),
              ),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 230,
                child: FlutterMap(
                  key: ValueKey('${latitude ?? 0}:${longitude ?? 0}'),
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: latitude == null ? 7.2 : 16,
                    onTap: (_, point) => setState(() { latitude = point.latitude; longitude = point.longitude; }),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.emjeshtri.client'),
                    if (latitude != null && longitude != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(latitude!, longitude!),
                          width: 52,
                          height: 52,
                          child: Container(
                            decoration: BoxDecoration(color: AppColors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                            child: const Icon(Icons.location_on_rounded, color: Colors.white),
                          ),
                        ),
                      ]),
                    const SimpleAttributionWidget(source: Text('© OpenStreetMap contributors')),
                  ],
                ),
              ),
            ),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(s.t('setPrimary')), value: primary, onChanged: (v) => setState(() => primary = v)),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: busy ? null : () async {
                  if (!(form.currentState?.validate() ?? false)) return;
                  setState(() => busy = true);
                  try {
                    await ref.read(marketplaceRepositoryProvider).saveAddress({
                      'street': street.text.trim(),
                      'street_number': number.text.trim().isEmpty ? null : number.text.trim(),
                      'city': city.text.trim(),
                      'postal_code': postal.text.trim().isEmpty ? null : postal.text.trim(),
                      'entrance': entrance.text.trim().isEmpty ? null : entrance.text.trim(),
                      'floor': floor.text.trim().isEmpty ? null : floor.text.trim(),
                      'apartment': apartment.text.trim().isEmpty ? null : apartment.text.trim(),
                      'note': note.text.trim().isEmpty ? null : note.text.trim(),
                      'latitude': latitude,
                      'longitude': longitude,
                      'is_primary': primary,
                    }, id: widget.initial?['id']?.toString());
                    if (context.mounted) context.pop();
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
                child: Text(s.t('save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageScreen extends ConsumerWidget {const LanguageScreen({super.key});@override Widget build(BuildContext context,WidgetRef ref){final current=ref.watch(localeProvider).languageCode;final items={'sq':'Shqip','en':'English','fr':'Français','de':'Deutsch','it':'Italiano'};return Scaffold(appBar:AppBar(title:Text(AppStrings.of(context).t('language'))),body:ListView(padding:const EdgeInsets.all(18),children:items.entries.map((e)=>Card(child:RadioListTile<String>(value:e.key,groupValue:current,title:Text(e.value),onChanged:(v)async{if(v==null)return;final locale=Locale(v);ref.read(localeProvider.notifier).state=locale;await LocalPreferences.saveLocale(locale);final uid=Supabase.instance.client.auth.currentUser?.id;if(uid!=null)await Supabase.instance.client.from('profiles').update({'preferred_language':v}).eq('id',uid);}))).toList()));}}


class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final current = ref.watch(themeModeProvider);
    final items = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, s.t('themeSystem'), Icons.settings_suggest_outlined),
      (ThemeMode.light, s.t('themeLight'), Icons.light_mode_outlined),
      (ThemeMode.dark, s.t('themeDark'), Icons.dark_mode_outlined),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.t('appearance'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: items.map((item) => Card(
          child: RadioListTile<ThemeMode>(
            value: item.$1,
            groupValue: current,
            secondary: Icon(item.$3),
            title: Text(item.$2),
            onChanged: (value) async {
              if (value == null) return;
              ref.read(themeModeProvider.notifier).state = value;
              await LocalPreferences.saveThemeMode(value);
            },
          ),
        )).toList(),
      ),
    );
  }
}

class NotificationSettingsScreen extends ConsumerStatefulWidget {const NotificationSettingsScreen({super.key});@override ConsumerState<NotificationSettingsScreen> createState()=>_NotificationSettingsScreenState();}
class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen>{Map<String,dynamic>? prefs;@override void initState(){super.initState();ref.read(marketplaceRepositoryProvider).notificationPreferences().then((v){if(mounted)setState(()=>prefs=v);});}Future<void> set(String key,bool value)async{setState(()=>prefs={...?prefs,key:value});await ref.read(marketplaceRepositoryProvider).saveNotificationPreferences({key:value});}@override Widget build(BuildContext context){final s=AppStrings.of(context);if(prefs==null)return Scaffold(appBar:AppBar(title:Text(s.t('notificationSettings'))),body:const Center(child:CircularProgressIndicator()));final rows=[('order_updates',s.t('orderUpdates')),('chat_messages',s.t('chatMessages')),('promotions',s.t('promotions')),('reminders',s.t('reminders')),('push_enabled',s.t('pushNotifications'))];return Scaffold(appBar:AppBar(title:Text(s.t('notificationSettings'))),body:ListView(padding:const EdgeInsets.all(18),children:rows.map((x)=>Card(child:SwitchListTile(title:Text(x.$2),value:prefs![x.$1]==true,onChanged:(v)=>set(x.$1,v)))).toList()));}}

class PrivacySecurityScreen extends ConsumerStatefulWidget {
  const PrivacySecurityScreen({super.key});
  @override
  ConsumerState<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends ConsumerState<PrivacySecurityScreen> {
  final pass = TextEditingController();

  @override
  void dispose() {
    pass.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final s = AppStrings.of(context);
    pass.clear();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('changePassword')),
        content: TextField(
          controller: pass,
          obscureText: true,
          decoration: InputDecoration(labelText: s.t('newPassword')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
    if (shouldSave == true && pass.text.length >= 8) {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pass.text),
      );
    }
  }

  Widget _privacyCard({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon),
        title: Text(title),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('privacySecurity'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _privacyCard(
            icon: Icons.password_rounded,
            title: s.t('changePassword'),
            onTap: _changePassword,
          ),
          const SizedBox(height: 10),
          _privacyCard(
            icon: Icons.devices_rounded,
            title: s.t('signOutAll'),
            onTap: () async {
              await Supabase.instance.client.auth.signOut(
                scope: SignOutScope.global,
              );
              if (context.mounted) context.go('/auth');
            },
          ),
          const SizedBox(height: 10),
          _privacyCard(
            icon: Icons.file_download_outlined,
            title: s.t('exportData'),
            onTap: () async {
              await ref
                  .read(marketplaceRepositoryProvider)
                  .requestDataExport();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.t('dataExportRequested'))),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          _privacyCard(
            icon: Icons.block_rounded,
            title: s.t('blockedUsers'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/profile/blocked'),
          ),
        ],
      ),
    );
  }
}

class BlockedProvidersScreen extends ConsumerStatefulWidget {const BlockedProvidersScreen({super.key});@override ConsumerState<BlockedProvidersScreen> createState()=>_BlockedProvidersScreenState();}
class _BlockedProvidersScreenState extends ConsumerState<BlockedProvidersScreen>{late Future<List<Map<String,dynamic>>> future;@override void initState(){super.initState();future=ref.read(marketplaceRepositoryProvider).blockedProviders();}void reload()=>setState(()=>future=ref.read(marketplaceRepositoryProvider).blockedProviders());@override Widget build(BuildContext context){final s=AppStrings.of(context);return Scaffold(appBar:AppBar(title:Text(s.t('blockedUsers'))),body:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,snap){if(snap.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());final items=snap.data??[];if(items.isEmpty)return EmptyState(icon:Icons.block_rounded,title:s.t('noBlocked'));return ListView(padding:const EdgeInsets.all(18),children:items.map((x){final p=(x['providers'] as Map?)?.cast<String,dynamic>()??{};return Card(child:ListTile(title:Text((p['display_name']??'').toString()),trailing:TextButton(onPressed:()async{await ref.read(marketplaceRepositoryProvider).unblockProvider(p['id'].toString());reload();},child:Text(s.t('unblock')))));}).toList());}));}}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final faqs = [
      (s.t('faqHowTitle'), s.t('faqHowBody')),
      (s.t('faqAddressTitle'), s.t('faqAddressBody')),
      (s.t('faqReportTitle'), s.t('faqReportBody')),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.t('helpCenter'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          for (var i = 0; i < faqs.length; i++) ...[
            Card(
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                title: Text(
                  faqs[i].$1,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(faqs[i].$2),
                  ),
                ],
              ),
            ),
            if (i < faqs.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => context.push('/support/new'),
              icon: const Icon(Icons.support_agent_rounded),
              label: Text(s.t('createTicket')),
            ),
          ),
        ],
      ),
    );
  }
}

class SupportTicketCreateScreen extends ConsumerStatefulWidget {const SupportTicketCreateScreen({super.key,this.orderId});final String? orderId;@override ConsumerState<SupportTicketCreateScreen> createState()=>_SupportTicketCreateScreenState();}
class _SupportTicketCreateScreenState extends ConsumerState<SupportTicketCreateScreen>{final subject=TextEditingController(),message=TextEditingController();String category='general';bool busy=false;@override void dispose(){subject.dispose();message.dispose();super.dispose();}@override Widget build(BuildContext context){final s=AppStrings.of(context);return Scaffold(appBar:AppBar(title:Text(s.t('supportTicket'))),body:ListView(padding:const EdgeInsets.all(20),children:[DropdownButtonFormField<String>(value:category,decoration:InputDecoration(labelText:s.t('support')),items:[DropdownMenuItem(value:'general',child:Text(s.t('general'))),DropdownMenuItem(value:'order',child:Text(s.t('order'))),DropdownMenuItem(value:'payment',child:Text(s.t('payment'))),DropdownMenuItem(value:'safety',child:Text(s.t('safety')))],onChanged:(v)=>setState(()=>category=v??'general')),const SizedBox(height:12),TextField(controller:subject,decoration:InputDecoration(labelText:s.t('subject'))),const SizedBox(height:12),TextField(controller:message,minLines:5,maxLines:8,decoration:InputDecoration(labelText:s.t('supportMessage'))),const SizedBox(height:22),SizedBox(height:54,child:FilledButton(onPressed:busy?null:()async{if(subject.text.trim().isEmpty||message.text.trim().isEmpty)return;setState(()=>busy=true);try{await ref.read(marketplaceRepositoryProvider).createSupportTicket(category:category,subject:subject.text,message:message.text,orderId:widget.orderId);if(context.mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s.t('ticketSent'))));context.pop();}}finally{if(mounted)setState(()=>busy=false);}},child:Text(s.t('send'))))]));}}

class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('termsPrivacy'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('e-Mjeshtri', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(s.t('legalSummary1')),
          const SizedBox(height: 14),
          Text(s.t('legalSummary2')),
          const SizedBox(height: 14),
          Text(s.t('legalReviewNote'), style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('about'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Image.asset('assets/branding/e_mjeshtri_logo.png', height: 120),
            const SizedBox(height: 20),
            Text('e-Mjeshtri', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(s.t('versionLabel'), style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 22),
            Text(s.t('aboutBody'), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class DeleteAccountScreen extends ConsumerStatefulWidget {const DeleteAccountScreen({super.key});@override ConsumerState<DeleteAccountScreen> createState()=>_DeleteAccountScreenState();}
class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen>{final reason=TextEditingController();bool confirm=false,busy=false;@override void dispose(){reason.dispose();super.dispose();}@override Widget build(BuildContext context){final s=AppStrings.of(context);return Scaffold(appBar:AppBar(title:Text(s.t('deleteAccount'))),body:ListView(padding:const EdgeInsets.all(20),children:[Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:AppColors.danger.withValues(alpha:.06),borderRadius:BorderRadius.circular(22)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.warning_amber_rounded,color:AppColors.danger),const SizedBox(width:12),Expanded(child:Text(s.t('accountDeletionWarning')))])),const SizedBox(height:18),TextField(controller:reason,maxLines:4,decoration:InputDecoration(labelText:s.t('reason'))),CheckboxListTile(contentPadding:EdgeInsets.zero,value:confirm,onChanged:(v)=>setState(()=>confirm=v==true),title:Text(s.t('deleteConfirm'))),const SizedBox(height:18),SizedBox(height:54,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:AppColors.danger),onPressed:!confirm||busy?null:()async{setState(()=>busy=true);try{await ref.read(marketplaceRepositoryProvider).requestAccountDeletion(reason.text);await ref.read(authRepositoryProvider).signOut();if(context.mounted)context.go('/auth');}finally{if(mounted)setState(()=>busy=false);}},child:Text(s.t('requestDeletion'))))]));}}


class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});
  @override
  ConsumerState<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    future = ref.read(marketplaceRepositoryProvider).supportTickets();
  }
  void reload() => setState(() => future = ref.read(marketplaceRepositoryProvider).supportTickets());

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('supportHistory'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await context.push('/support/new'); reload(); },
        icon: const Icon(Icons.add_rounded),
        label: Text(s.t('createTicket')),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: FilledButton(onPressed: reload, child: Text(s.t('retry'))));
          final items = snap.data ?? [];
          if (items.isEmpty) return EmptyState(icon: Icons.support_agent_rounded, title: s.t('noTickets'));
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final x = items[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: .08), borderRadius: BorderRadius.circular(15)),
                      child: const Icon(Icons.support_agent_rounded, color: AppColors.blue),
                    ),
                    title: Text((x['subject'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text((x['status'] ?? '').toString()),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/support/${x['id']}?subject=${Uri.encodeComponent((x['subject'] ?? '').toString())}'),
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

class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  const SupportTicketDetailScreen({
    super.key,
    required this.ticketId,
    this.subject,
  });

  final String ticketId;
  final String? subject;

  @override
  ConsumerState<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState
    extends ConsumerState<SupportTicketDetailScreen> {
  final input = TextEditingController();
  final scrollController = ScrollController();
  bool sending = false;

  @override
  void dispose() {
    input.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (input.text.trim().isEmpty || sending) return;
    final body = input.text;
    input.clear();
    setState(() => sending = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .sendSupportMessage(widget.ticketId, body);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(marketplaceRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subject?.isNotEmpty == true
                  ? widget.subject!
                  : 'Suport Live',
            ),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: AppColors.success),
                SizedBox(width: 5),
                Text(
                  'Chat live me suportin',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: repo.supportMessagesStream(widget.ticketId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nuk mund të lidhemi me chat-in e suportit. Provo përsëri.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  );
                }

                final items = snap.data ?? const <Map<String, dynamic>>[];
                _scrollToBottom();

                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Shkruaj mesazhin tënd. Suporti do të përgjigjet këtu në kohë reale.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[i];
                    final mine = m['sender_type'] == 'user';
                    final body = (m['body'] ?? '').toString();
                    final createdAt =
                        DateTime.tryParse((m['created_at'] ?? '').toString())
                            ?.toLocal();

                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .80,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? AppColors.blue
                              : AppColors.blue.withValues(alpha: .055),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(mine ? 18 : 5),
                            bottomRight: Radius.circular(mine ? 5 : 18),
                          ),
                          border: mine
                              ? null
                              : Border.all(
                                  color:
                                      AppColors.blue.withValues(alpha: .12),
                                ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!mine) ...[
                              const Text(
                                'Suporti e-Mjeshtri',
                                style: TextStyle(
                                  color: AppColors.blue,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              body,
                              style: TextStyle(
                                color: mine ? Colors.white : AppColors.blueDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (createdAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: mine
                                      ? Colors.white70
                                      : AppColors.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.blue.withValues(alpha: .08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Shkruaj mesazhin...',
                        filled: true,
                        fillColor: AppColors.blue.withValues(alpha: .035),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : send,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportCreateScreen extends ConsumerStatefulWidget {
  const ReportCreateScreen({super.key, this.providerId, this.orderId, this.conversationId});
  final String? providerId, orderId, conversationId;
  @override
  ConsumerState<ReportCreateScreen> createState() => _ReportCreateScreenState();
}

class _ReportCreateScreenState extends ConsumerState<ReportCreateScreen> {
  String type = 'quality';
  final description = TextEditingController();
  bool busy = false;
  @override
  void dispose() { description.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('reportUser'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            value: type,
            decoration: InputDecoration(labelText: s.t('reportType')),
            items: [
              DropdownMenuItem(value: 'quality', child: Text(s.t('quality'))),
              DropdownMenuItem(value: 'safety', child: Text(s.t('safety'))),
              DropdownMenuItem(value: 'fraud', child: Text(s.t('fraud'))),
              DropdownMenuItem(value: 'abuse', child: Text(s.t('abuse'))),
              DropdownMenuItem(value: 'other', child: Text(s.t('other'))),
            ],
            onChanged: (v) => setState(() => type = v ?? 'quality'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: description,
            minLines: 5,
            maxLines: 9,
            maxLength: 1500,
            decoration: InputDecoration(labelText: s.t('reason')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: busy || description.text.trim().isEmpty
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        await ref.read(marketplaceRepositoryProvider).createReport(
                          providerId: widget.providerId,
                          orderId: widget.orderId,
                          conversationId: widget.conversationId,
                          type: type,
                          description: description.text,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('reportSent'))));
                          context.pop();
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(s.t('send')),
            ),
          ),
        ],
      ),
    );
  }
}