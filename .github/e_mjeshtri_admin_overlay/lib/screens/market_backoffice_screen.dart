import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketBackofficeScreen extends StatefulWidget {
  const MarketBackofficeScreen({super.key});

  @override
  State<MarketBackofficeScreen> createState() => _MarketBackofficeScreenState();
}

class _MarketBackofficeScreenState extends State<MarketBackofficeScreen> {
  final _client = Supabase.instance.client;
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final raw = await _client.rpc('admin_market_backoffice_snapshot');
    if (raw is! Map) throw StateError('Përgjigje e pavlefshme nga e-Market Admin API.');
    return Map<String, dynamic>.from(raw);
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> data, String key) {
    return List<Map<String, dynamic>>.from((data[key] as List?) ?? const []);
  }

  Future<void> _action(
    String entity,
    String? id,
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    setState(() => _busy = true);
    try {
      await _client.rpc(
        'admin_market_backoffice_action',
        params: {
          'p_entity': entity,
          'p_id': id,
          'p_action': action,
          'p_payload': payload,
        },
      );
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendly(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(Object error) {
    final text = error.toString();
    if (text.contains('42501')) return 'Nuk ke leje për këtë veprim.';
    if (text.contains('23505')) return 'Kjo vlerë ekziston tashmë.';
    if (text.contains('23514')) return 'Të dhënat nuk plotësojnë rregullat e sistemit.';
    return 'Veprimi dështoi. Provo përsëri.';
  }

  Future<void> _createCategory() async {
    final name = TextEditingController();
    final nameEn = TextEditingController();
    final slug = TextEditingController();
    String audience = 'both';
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Shto kategori e-Market'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Emri shqip')),
                const SizedBox(height: 10),
                TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'Emri anglisht')),
                const SizedBox(height: 10),
                TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug (opsional)')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: audience,
                  decoration: const InputDecoration(labelText: 'Audienca'),
                  items: const [
                    DropdownMenuItem(value: 'citizen', child: Text('Qytetar')),
                    DropdownMenuItem(value: 'provider', child: Text('Mjeshtër')),
                    DropdownMenuItem(value: 'both', child: Text('Të dyja')),
                  ],
                  onChanged: (v) => setLocal(() => audience = v ?? 'both'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulo')),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(context, {
                  'name_sq': name.text.trim(),
                  'name_en': nameEn.text.trim(),
                  'slug': slug.text.trim(),
                  'audience': audience,
                  'is_active': true,
                });
              },
              child: const Text('Ruaj'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    nameEn.dispose();
    slug.dispose();
    if (payload != null) await _action('category', null, 'create', payload);
  }

  Future<void> _createBrand() async {
    final name = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shto markë'),
        content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Emri i markës')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulo')),
          FilledButton(
            onPressed: () {
              final v = name.text.trim();
              if (v.isNotEmpty) Navigator.pop(context, v);
            },
            child: const Text('Ruaj'),
          ),
        ],
      ),
    );
    name.dispose();
    if (value != null) await _action('brand', null, 'create', {'name': value});
  }

  Future<void> _createPromotion(List<Map<String, dynamic>> vendors) async {
    final name = TextEditingController();
    final amount = TextEditingController();
    String type = 'percentage';
    String? vendorId;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Shto promocion'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Emri')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: vendorId,
                  decoration: const InputDecoration(labelText: 'Shitësi'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Promocion global')),
                    ...vendors.map(
                      (v) => DropdownMenuItem<String?>(
                        value: v['id']?.toString(),
                        child: Text((v['display_name'] ?? '').toString()),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => vendorId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Lloji'),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Përqindje')),
                    DropdownMenuItem(value: 'price', child: Text('Vlerë fikse')),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? 'percentage'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Vlera'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulo')),
            FilledButton(
              onPressed: () {
                final n = double.tryParse(amount.text.trim());
                if (name.text.trim().isEmpty || n == null || n <= 0) return;
                Navigator.pop(context, {
                  'name': name.text.trim(),
                  'vendor_id': vendorId ?? '',
                  'promotion_type': type,
                  'value': n,
                  'is_active': true,
                });
              },
              child: const Text('Ruaj'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    amount.dispose();
    if (payload != null) await _action('promotion', null, 'create', payload);
  }

  Future<void> _createSubscription(List<Map<String, dynamic>> vendors) async {
    String? vendorId;
    final plan = TextEditingController(text: 'standard');
    final price = TextEditingController(text: '0');
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Shto abonim shitësi'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: vendorId,
                  decoration: const InputDecoration(labelText: 'Shitësi'),
                  items: vendors
                      .map((v) => DropdownMenuItem(
                            value: v['id'].toString(),
                            child: Text((v['display_name'] ?? '').toString()),
                          ))
                      .toList(),
                  onChanged: (v) => setLocal(() => vendorId = v),
                ),
                const SizedBox(height: 10),
                TextField(controller: plan, decoration: const InputDecoration(labelText: 'Kodi i planit')),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Çmimi ALL'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulo')),
            FilledButton(
              onPressed: () {
                if (vendorId == null) return;
                Navigator.pop(context, {
                  'vendor_id': vendorId,
                  'plan_code': plan.text.trim().isEmpty ? 'standard' : plan.text.trim(),
                  'price_amount': double.tryParse(price.text.trim()) ?? 0,
                  'currency': 'ALL',
                  'status': 'pending',
                });
              },
              child: const Text('Krijo'),
            ),
          ],
        ),
      ),
    );
    plan.dispose();
    price.dispose();
    if (payload != null) await _action('subscription', null, 'create', payload);
  }

  Future<String?> _noteDialog(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Shënim'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulo')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Vazhdo')),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || snap.data == null) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Provo përsëri'),
            ),
          );
        }
        final data = snap.data!;
        final vendors = _rows(data, 'vendors');
        return DefaultTabController(
          length: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('e-Market • Menaxhim i plotë', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Kategori, marka, promocione, kthime, komisione dhe abonime.', style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rifresko',
                    onPressed: _busy ? null : () => setState(_reload),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Kategori'),
                  Tab(text: 'Marka'),
                  Tab(text: 'Promocione'),
                  Tab(text: 'Kthime'),
                  Tab(text: 'Komisione'),
                  Tab(text: 'Abonime'),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: TabBarView(
                  children: [
                    _simpleCrudTab(
                      context,
                      rows: _rows(data, 'categories'),
                      addLabel: 'Shto kategori',
                      onAdd: _createCategory,
                      title: (r) => (r['name_sq'] ?? '').toString(),
                      subtitle: (r) => (r['audience'] ?? '').toString() + ' • ' + (r['product_count'] ?? 0).toString() + ' produkte',
                      trailing: (r) => Switch(
                        value: r['is_active'] == true,
                        onChanged: _busy ? null : (_) => _action('category', r['id'].toString(), 'toggle'),
                      ),
                    ),
                    _simpleCrudTab(
                      context,
                      rows: _rows(data, 'brands'),
                      addLabel: 'Shto markë',
                      onAdd: _createBrand,
                      title: (r) => (r['name'] ?? '').toString(),
                      subtitle: (r) => (r['product_count'] ?? 0).toString() + ' produkte',
                      trailing: (r) => Switch(
                        value: r['is_active'] == true,
                        onChanged: _busy ? null : (_) => _action('brand', r['id'].toString(), 'toggle'),
                      ),
                    ),
                    _simpleCrudTab(
                      context,
                      rows: _rows(data, 'promotions'),
                      addLabel: 'Shto promocion',
                      onAdd: () => _createPromotion(vendors),
                      title: (r) => (r['name'] ?? '').toString(),
                      subtitle: (r) => ((r['vendor_name'] ?? 'Global').toString()) + ' • ' + (r['value'] ?? 0).toString(),
                      trailing: (r) => Switch(
                        value: r['is_active'] == true,
                        onChanged: _busy ? null : (_) => _action('promotion', r['id'].toString(), 'toggle'),
                      ),
                    ),
                    _returnsTab(_rows(data, 'returns')),
                    _commissionsTab(_rows(data, 'commissions')),
                    _subscriptionsTab(_rows(data, 'subscriptions'), vendors),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _simpleCrudTab(
    BuildContext context, {
    required List<Map<String, dynamic>> rows,
    required String addLabel,
    required VoidCallback onAdd,
    required String Function(Map<String, dynamic>) title,
    required String Function(Map<String, dynamic>) subtitle,
    required Widget Function(Map<String, dynamic>) trailing,
  }) {
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 36),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(addLabel),
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const _EmptyBackoffice('Nuk ka ende të dhëna.')
        else
          ...rows.map(
            (r) => Card(
              elevation: 0,
              child: ListTile(
                title: Text(title(r), style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(subtitle(r)),
                trailing: trailing(r),
              ),
            ),
          ),
      ],
    );
  }

  Widget _returnsTab(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const _EmptyBackoffice('Nuk ka kërkesa kthimi.');
    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: rows.map((r) {
        final status = (r['status'] ?? '').toString();
        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (r['vendor_order_number'] ?? '').toString() + ' • ' + (r['vendor_name'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Chip(label: Text(status)),
                  ],
                ),
                Text('Klienti: ' + (r['buyer_name'] ?? '').toString()),
                Text('Arsyeja: ' + (r['reason'] ?? '').toString()),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!{'admin_approved','received','refunded','closed'}.contains(status))
                      FilledButton(
                        onPressed: _busy ? null : () async {
                          final note = await _noteDialog('Aprovo kthimin');
                          if (note != null) await _action('return', r['id'].toString(), 'approve', {'note': note});
                        },
                        child: const Text('Aprovo'),
                      ),
                    if (!{'admin_rejected','refunded','closed'}.contains(status))
                      OutlinedButton(
                        onPressed: _busy ? null : () async {
                          final note = await _noteDialog('Refuzo kthimin');
                          if (note != null) await _action('return', r['id'].toString(), 'reject', {'note': note});
                        },
                        child: const Text('Refuzo'),
                      ),
                    if (status == 'admin_approved' || status == 'vendor_approved')
                      OutlinedButton(
                        onPressed: _busy ? null : () => _action('return', r['id'].toString(), 'received'),
                        child: const Text('Shëno të marrë'),
                      ),
                    if (status == 'received' || status == 'admin_approved' || status == 'vendor_approved')
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _action('return', r['id'].toString(), 'refund'),
                        icon: const Icon(Icons.undo_rounded),
                        label: const Text('Rimburso'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _commissionsTab(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const _EmptyBackoffice('Nuk ka komisione.');
    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: rows.map((r) => Card(
        elevation: 0,
        child: ListTile(
          title: Text((r['vendor_name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text((r['vendor_order_number'] ?? '').toString() + ' • ' + (r['status'] ?? '').toString()),
          leading: const Icon(Icons.percent_rounded),
          trailing: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text((r['commission_amount'] ?? 0).toString() + ' ' + (r['currency'] ?? 'ALL').toString()),
              if (!{'paid','waived'}.contains((r['status'] ?? '').toString()))
                IconButton(
                  tooltip: 'Shëno të paguar',
                  onPressed: _busy ? null : () => _action('commission', r['id'].toString(), 'paid'),
                  icon: const Icon(Icons.paid_outlined),
                ),
              if (!{'paid','waived'}.contains((r['status'] ?? '').toString()))
                IconButton(
                  tooltip: 'Hiq komisionin',
                  onPressed: _busy ? null : () => _action('commission', r['id'].toString(), 'waive'),
                  icon: const Icon(Icons.money_off_csred_outlined),
                ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _subscriptionsTab(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> vendors,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _createSubscription(vendors),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Shto abonim'),
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const _EmptyBackoffice('Nuk ka abonime shitësish.')
        else
          ...rows.map((r) {
            final status = (r['status'] ?? '').toString();
            return Card(
              elevation: 0,
              child: ListTile(
                title: Text(
                  (r['vendor_name'] ?? '').toString() + ' • ' + (r['plan_code'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  status + ' • ' + (r['price_amount'] ?? 0).toString() + ' ' + (r['currency'] ?? 'ALL').toString(),
                ),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    if (status != 'active')
                      IconButton(
                        tooltip: 'Aktivizo',
                        onPressed: _busy ? null : () => _action('subscription', r['id'].toString(), 'activate'),
                        icon: const Icon(Icons.play_circle_outline_rounded),
                      ),
                    if (!{'cancelled','expired'}.contains(status))
                      IconButton(
                        tooltip: 'Anulo',
                        onPressed: _busy ? null : () => _action('subscription', r['id'].toString(), 'cancel'),
                        icon: const Icon(Icons.cancel_outlined),
                      ),
                    if (status != 'expired')
                      IconButton(
                        tooltip: 'Skado',
                        onPressed: _busy ? null : () => _action('subscription', r['id'].toString(), 'expire'),
                        icon: const Icon(Icons.timer_off_outlined),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _EmptyBackoffice extends StatelessWidget {
  const _EmptyBackoffice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }
}
