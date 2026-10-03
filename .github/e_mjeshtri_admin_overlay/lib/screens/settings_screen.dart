import 'package:flutter/material.dart';

import '../data/admin_modules_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = AdminModulesRepository.instance;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  AdminModuleSnapshot? _snapshot;

  bool _maintenance = false;
  bool _providerAppEnabled = false;
  bool _onlinePaymentsEnabled = false;
  bool _googleOauthEnabled = false;
  bool _appleOauthEnabled = false;

  final _clientAndroid = TextEditingController();
  final _clientIos = TextEditingController();
  final _providerAndroid = TextEditingController();
  final _providerIos = TextEditingController();

  final _androidStore = TextEditingController();
  final _iosStore = TextEditingController();

  final _bankName = TextEditingController();
  final _accountName = TextEditingController();
  final _iban = TextEditingController();
  final _bankNote = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clientAndroid.dispose();
    _clientIos.dispose();
    _providerAndroid.dispose();
    _providerIos.dispose();
    _androidStore.dispose();
    _iosStore.dispose();
    _bankName.dispose();
    _accountName.dispose();
    _iban.dispose();
    _bankNote.dispose();
    super.dispose();
  }

  Map<String, dynamic> _value(String key) {
    final item = _item(key);
    final raw = item?.data['value'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  AdminModuleItem? _item(String key) {
    for (final item in _snapshot?.items ?? const <AdminModuleItem>[]) {
      if (item.id == key) return item;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snapshot = await _repo.load('settings');
      _snapshot = snapshot;

      final maintenance = _mapValue(snapshot, 'maintenance_mode');
      final flags = _mapValue(snapshot, 'feature_flags');
      final versions = _mapValue(snapshot, 'min_app_versions');
      final urls = _mapValue(snapshot, 'store_urls');
      final bank = _mapValue(snapshot, 'subscription_bank_details');

      _maintenance = maintenance['enabled'] == true;
      _providerAppEnabled = flags['provider_app_enabled'] == true;
      _onlinePaymentsEnabled = flags['online_payments_enabled'] == true;
      _googleOauthEnabled = flags['google_oauth_enabled'] == true;
      _appleOauthEnabled = flags['apple_oauth_enabled'] == true;

      _clientAndroid.text = (versions['client_android'] ?? '').toString();
      _clientIos.text = (versions['client_ios'] ?? '').toString();
      _providerAndroid.text = (versions['provider_android'] ?? '').toString();
      _providerIos.text = (versions['provider_ios'] ?? '').toString();

      _androidStore.text = (urls['android'] ?? '').toString();
      _iosStore.text = (urls['ios'] ?? '').toString();

      _bankName.text = (bank['bank_name'] ?? '').toString();
      _accountName.text = (bank['account_name'] ?? '').toString();
      _iban.text = (bank['iban'] ?? '').toString();
      _bankNote.text = (bank['note'] ?? '').toString();

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _mapValue(AdminModuleSnapshot snapshot, String key) {
    for (final item in snapshot.items) {
      if (item.id == key) {
        final raw = item.data['value'];
        if (raw is Map) return Map<String, dynamic>.from(raw);
      }
    }
    return <String, dynamic>{};
  }

  Future<void> _saveConfig(String key, Map<String, dynamic> value,
      {String success = 'Cilësimi u ruajt.'}) async {
    final item = _item(key);
    if (item == null) {
      _show('Konfigurimi "$key" nuk u gjet.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.action('settings', item.id, 'update', {
        'value': value,
        'is_public': item.data['is_public'] == true,
      });
      _show(success);
      final snapshot = await _repo.load('settings');
      _snapshot = snapshot;
      if (mounted) setState(() {});
    } catch (e) {
      _show(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveFeatureFlags() async {
    final current = _value('feature_flags');
    await _saveConfig('feature_flags', {
      ...current,
      'provider_app_enabled': _providerAppEnabled,
      'online_payments_enabled': _onlinePaymentsEnabled,
      'google_oauth_enabled': _googleOauthEnabled,
      'apple_oauth_enabled': _appleOauthEnabled,
    }, success: 'Funksionet e platformës u përditësuan.');
  }

  Future<void> _saveVersions() async {
    await _saveConfig('min_app_versions', {
      'client_android': _clientAndroid.text.trim(),
      'client_ios': _clientIos.text.trim(),
      'provider_android': _providerAndroid.text.trim(),
      'provider_ios': _providerIos.text.trim(),
    }, success: 'Versionet minimale u ruajtën.');
  }

  Future<void> _saveStoreUrls() async {
    await _saveConfig('store_urls', {
      'android': _androidStore.text.trim(),
      'ios': _iosStore.text.trim(),
    }, success: 'Linket e aplikacionit u ruajtën.');
  }

  Future<void> _saveBank() async {
    await _saveConfig('subscription_bank_details', {
      'bank_name': _bankName.text.trim(),
      'account_name': _accountName.text.trim(),
      'iban': _iban.text.trim(),
      'note': _bankNote.text.trim(),
    }, success: 'Të dhënat bankare u ruajtën.');
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('permission') || text.contains('not authorized')) {
      return 'Nuk ke leje për ta ndryshuar këtë cilësim.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Provo përsëri'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _Header(onRefresh: _saving ? null : _load),
        const SizedBox(height: 20),

        _SectionCard(
          title: 'Gjendja e platformës',
          subtitle:
              'Kontrollo nëse aplikacioni është aktiv apo në mirëmbajtje.',
          icon: Icons.power_settings_new_rounded,
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Modalitet mirëmbajtjeje',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Kur aktivizohet, përdoruesit shohin njoftimin e mirëmbajtjes.',
            ),
            value: _maintenance,
            onChanged: _saving
                ? null
                : (value) async {
                    setState(() => _maintenance = value);
                    await _saveConfig(
                      'maintenance_mode',
                      {'enabled': value},
                      success: value
                          ? 'Modaliteti i mirëmbajtjes u aktivizua.'
                          : 'Modaliteti i mirëmbajtjes u çaktivizua.',
                    );
                  },
          ),
        ),

        const SizedBox(height: 16),
        _SectionCard(
          title: 'Funksionet e platformës',
          subtitle:
              'Aktivizo ose çaktivizo funksione pa prekur kodin e aplikacionit.',
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              _toggle(
                'Paneli / funksionet e Mjeshtrit',
                'Lejon funksionet e dedikuara për mjeshtrat.',
                _providerAppEnabled,
                (v) => setState(() => _providerAppEnabled = v),
              ),
              _toggle(
                'Pagesa online',
                'Aktivizoje vetëm pasi sistemi i pagesave të jetë konfiguruar.',
                _onlinePaymentsEnabled,
                (v) => setState(() => _onlinePaymentsEnabled = v),
              ),
              _toggle(
                'Hyrja me Google',
                'Lejon autentikimin me Google.',
                _googleOauthEnabled,
                (v) => setState(() => _googleOauthEnabled = v),
              ),
              _toggle(
                'Hyrja me Apple',
                'Lejon autentikimin me Apple.',
                _appleOauthEnabled,
                (v) => setState(() => _appleOauthEnabled = v),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveFeatureFlags,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Ruaj funksionet'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _SectionCard(
          title: 'Versionet minimale të aplikacionit',
          subtitle:
              'Përdoruesit me version më të vjetër se këto vlera do të kërkohet të përditësojnë aplikacionin.',
          icon: Icons.system_update_alt_rounded,
          child: Column(
            children: [
              _twoColumns(
                _field(_clientAndroid, 'Qytetar • Android', 'p.sh. 1.4.3'),
                _field(_clientIos, 'Qytetar • iOS', 'p.sh. 1.4.3'),
              ),
              const SizedBox(height: 12),
              _twoColumns(
                _field(_providerAndroid, 'Mjeshtër • Android', 'p.sh. 1.4.3'),
                _field(_providerIos, 'Mjeshtër • iOS', 'p.sh. 1.4.3'),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveVersions,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Ruaj versionet'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _SectionCard(
          title: 'Linket e aplikacionit',
          subtitle:
              'Vendos linket e Google Play dhe App Store që përdoren për përditësimet.',
          icon: Icons.link_rounded,
          child: Column(
            children: [
              _field(_androidStore, 'Google Play', 'https://...'),
              const SizedBox(height: 12),
              _field(_iosStore, 'App Store', 'https://...'),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveStoreUrls,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Ruaj linket'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _SectionCard(
          title: 'Të dhënat bankare për abonimet',
          subtitle:
              'Këto të dhëna u shfaqen mjeshtrave kur zgjedhin pagesë me transfertë bankare.',
          icon: Icons.account_balance_rounded,
          child: Column(
            children: [
              _twoColumns(
                _field(_bankName, 'Banka', 'Emri i bankës'),
                _field(_accountName, 'Përfituesi', 'Emri i llogarisë'),
              ),
              const SizedBox(height: 12),
              _field(_iban, 'IBAN', 'AL...'),
              const SizedBox(height: 12),
              TextField(
                controller: _bankNote,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Shënim për pagesën',
                  hintText: 'Udhëzim i shkurtër për mjeshtrin',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveBank,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Ruaj të dhënat bankare'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: _saving ? null : onChanged,
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return TextField(
      controller: controller,
      enabled: !_saving,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _twoColumns(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              a,
              const SizedBox(height: 12),
              b,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            Icons.settings_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cilësimet',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 3),
              Text(
                'Konfigurimi i platformës e-Mjeshtri',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Rifresko',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
