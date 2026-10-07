import 'dart:html' as html;
import 'dart:typed_data';

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
  String _productFilter = 'all';

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

  Future<html.File?> _pickBannerFile() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/jpeg,image/png,image/webp'
      ..multiple = false;
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return null;
    return input.files!.first;
  }

  Future<Uint8List> _readBannerFile(html.File file) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final result = reader.result;
    if (result is ByteBuffer) return result.asUint8List();
    if (result is Uint8List) return result;
    throw StateError('Fotoja nuk mund të lexohet.');
  }

  Future<String> _uploadBannerFile(html.File file) async {
    if (file.size > 12 * 1024 * 1024) {
      throw StateError('Reklama nuk mund të jetë më e madhe se 12 MB.');
    }
    final bytes = await _readBannerFile(file);
    final parts = file.name.split('.');
    final ext = parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
    final safeExt = {'jpg','jpeg','png','webp'}.contains(ext) ? ext : 'jpg';
    final path = 'admin/' +
        DateTime.now().microsecondsSinceEpoch.toString() +
        '.' +
        safeExt;
    await _client.storage.from('market-banners').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: file.type.isEmpty ? 'image/jpeg' : file.type,
            upsert: false,
          ),
        );
    return path;
  }

  Future<void> _createBanner() async {
    final title = TextEditingController();
    final subtitle = TextEditingController();
    final target = TextEditingController();
    final sort = TextEditingController(text: '0');
    String audience = 'both';
    html.File? image;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Shto reklamë e-Market'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8FC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4EAF2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          size: 34,
                          color: Color(0xFF125C9E),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          image?.name ?? 'Zgjidh foton e reklamës',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await _pickBannerFile();
                            if (picked != null) setLocal(() => image = picked);
                          },
                          icon: const Icon(Icons.upload_rounded),
                          label: const Text('Ngarko foto'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Titulli (opsional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitle,
                    decoration: const InputDecoration(
                      labelText: 'Nën-titulli (opsional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: audience,
                    decoration: const InputDecoration(
                      labelText: 'Kujt i shfaqet',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'citizen',
                        child: Text('Qytetarëve'),
                      ),
                      DropdownMenuItem(
                        value: 'provider',
                        child: Text('Mjeshtrave'),
                      ),
                      DropdownMenuItem(
                        value: 'both',
                        child: Text('Të dyve'),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => audience = v ?? 'both'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: target,
                    decoration: const InputDecoration(
                      labelText: 'Linku kur klikohet (opsional)',
                      hintText: 'https://...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sort,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Renditja',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Nëse ka më shumë se një reklamë aktive, aplikacioni i kalon automatikisht njëra pas tjetrës.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anulo'),
            ),
            FilledButton(
              onPressed: image == null
                  ? null
                  : () => Navigator.pop(context, {
                        'file': image,
                        'title': title.text.trim(),
                        'subtitle': subtitle.text.trim(),
                        'audience': audience,
                        'target_url': target.text.trim(),
                        'sort_order': int.tryParse(sort.text.trim()) ?? 0,
                      }),
              child: const Text('Shto reklamën'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    subtitle.dispose();
    target.dispose();
    sort.dispose();
    if (payload == null) return;

    setState(() => _busy = true);
    String? uploadedPath;
    try {
      uploadedPath = await _uploadBannerFile(payload['file'] as html.File);
      await _client.rpc(
        'admin_market_backoffice_action',
        params: {
          'p_entity': 'banner',
          'p_id': null,
          'p_action': 'create',
          'p_payload': {
            'image_path': uploadedPath,
            'title': payload['title'],
            'subtitle': payload['subtitle'],
            'audience': payload['audience'],
            'target_url': payload['target_url'],
            'sort_order': payload['sort_order'],
            'is_active': true,
          },
        },
      );
      if (mounted) setState(_reload);
    } catch (e) {
      if (uploadedPath != null) {
        try {
          await _client.storage
              .from('market-banners')
              .remove([uploadedPath]);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendly(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBanner(Map<String, dynamic> banner) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hiq reklamën?'),
        content: const Text(
          'Reklama do të hiqet nga e-Market dhe nuk do t’u shfaqet më përdoruesve.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hiq'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final path = banner['image_path']?.toString();
      if (path != null && path.isNotEmpty) {
        await _client.storage.from('market-banners').remove([path]);
      }
      await _client.rpc(
        'admin_market_backoffice_action',
        params: {
          'p_entity': 'banner',
          'p_id': banner['id'],
          'p_action': 'delete',
          'p_payload': <String, dynamic>{},
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

  Widget _bannersTab(List<Map<String, dynamic>> rows) {
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 36),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _createBanner,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Shto reklamë'),
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const _EmptyBackoffice('Nuk ka ende reklama e-Market.')
        else
          ...rows.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE4EAF2)),
                ),
                child: Row(
                  children: [
                    FutureBuilder<String>(
                      future: _client.storage
                          .from('market-banners')
                          .createSignedUrl(
                            r['image_path'].toString(),
                            900,
                          ),
                      builder: (context, snap) => Container(
                        width: 150,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: snap.hasData
                            ? Image.network(
                                snap.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_not_supported_outlined,
                                ),
                              )
                            : const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (r['title'] ?? 'Reklamë e-Market').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Audienca: ' +
                                (r['audience'] ?? 'both').toString() +
                                ' • Renditja: ' +
                                (r['sort_order'] ?? 0).toString(),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: r['is_active'] == true,
                      onChanged: _busy
                          ? null
                          : (_) => _action(
                                'banner',
                                r['id'].toString(),
                                'toggle',
                              ),
                    ),
                    IconButton(
                      tooltip: 'Hiq reklamën',
                      onPressed: _busy ? null : () => _deleteBanner(r),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
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

  Future<void> _adminAction(
    String entity,
    String id,
    String action, {
    String? note,
  }) async {
    setState(() => _busy = true);
    try {
      await _client.rpc(
        'admin_market_action',
        params: {
          'p_entity': entity,
          'p_id': id,
          'p_action': action,
          'p_note': note,
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

  Future<void> _requestProductCorrection(
    Map<String, dynamic> product,
  ) async {
    final note = await _noteDialog(
      'Kërko korrigjim • ' + (product['name'] ?? '').toString(),
    );
    if (note == null || note.trim().isEmpty) return;
    await _adminAction(
      'product',
      product['id'].toString(),
      'request_correction',
      note: note,
    );
  }

  Future<void> _rejectManagedProduct(
    Map<String, dynamic> product,
  ) async {
    final note = await _noteDialog(
      'Refuzo produktin • ' + (product['name'] ?? '').toString(),
    );
    if (note == null || note.trim().isEmpty) return;
    await _adminAction(
      'product',
      product['id'].toString(),
      'reject',
      note: note,
    );
  }

  Widget _productsManagementTab(
    List<Map<String, dynamic>> rows,
  ) {
    final filtered = rows.where((p) {
      final status = (p['status'] ?? '').toString();
      if (_productFilter == 'all') return true;
      if (_productFilter == 'featured') return p['is_featured'] == true;
      if (_productFilter == 'low_stock') {
        final stock = (p['stock_quantity'] as num?)?.toInt() ?? 0;
        final reserved = (p['reserved_quantity'] as num?)?.toInt() ?? 0;
        final threshold =
            (p['low_stock_threshold'] as num?)?.toInt() ?? 0;
        return stock - reserved <= threshold;
      }
      return status == _productFilter;
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ManagementFilterChip(
              label: 'Të gjitha',
              selected: _productFilter == 'all',
              onTap: () => setState(() => _productFilter = 'all'),
            ),
            _ManagementFilterChip(
              label: 'Në pritje',
              selected: _productFilter == 'pending_review',
              onTap: () =>
                  setState(() => _productFilter = 'pending_review'),
            ),
            _ManagementFilterChip(
              label: 'Kërkon korrigjim',
              selected: _productFilter == 'needs_correction',
              onTap: () =>
                  setState(() => _productFilter = 'needs_correction'),
            ),
            _ManagementFilterChip(
              label: 'Aktive',
              selected: _productFilter == 'active',
              onTap: () => setState(() => _productFilter = 'active'),
            ),
            _ManagementFilterChip(
              label: 'Rekomanduara',
              selected: _productFilter == 'featured',
              onTap: () => setState(() => _productFilter = 'featured'),
            ),
            _ManagementFilterChip(
              label: 'Stok i ulët',
              selected: _productFilter == 'low_stock',
              onTap: () =>
                  setState(() => _productFilter = 'low_stock'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          const _EmptyBackoffice('Nuk ka produkte në këtë filtër.')
        else
          ...filtered.map((p) {
            final status = (p['status'] ?? '').toString();
            final audience = (p['audience'] ?? 'both').toString();
            final stock = (p['stock_quantity'] as num?)?.toInt() ?? 0;
            final reserved =
                (p['reserved_quantity'] as num?)?.toInt() ?? 0;
            final available = stock - reserved;
            final threshold =
                (p['low_stock_threshold'] as num?)?.toInt() ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE4EAF2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF125C9E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (p['name'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (p['is_featured'] == true)
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF125C9E),
                                size: 18,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (p['vendor_name'] ?? '').toString() +
                              ' • ' +
                              (p['category_name'] ?? '').toString(),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _ManagementTag(
                              icon: Icons.info_outline_rounded,
                              label: _marketManagementStatusLabel(status),
                              color: _marketManagementStatusColor(status),
                            ),
                            _ManagementTag(
                              icon: audience == 'citizen'
                                  ? Icons.person_outline_rounded
                                  : audience == 'provider'
                                      ? Icons.handyman_outlined
                                      : Icons.groups_2_outlined,
                              label: audience == 'citizen'
                                  ? 'Qytetar'
                                  : audience == 'provider'
                                      ? 'Mjeshtër'
                                      : 'Të dy',
                              color: const Color(0xFF125C9E),
                            ),
                            _ManagementTag(
                              icon: Icons.payments_outlined,
                              label:
                                  (p['retail_price'] ?? 0).toString() +
                                      ' ' +
                                      (p['currency'] ?? 'ALL').toString(),
                              color: const Color(0xFF168C5A),
                            ),
                            _ManagementTag(
                              icon: Icons.inventory_outlined,
                              label: 'Stok: ' + available.toString(),
                              color: available <= threshold
                                  ? const Color(0xFFC2410C)
                                  : const Color(0xFF667085),
                            ),
                          ],
                        ),
                        if ((p['rejection_reason'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            (p['rejection_reason'] ?? '').toString(),
                            style: const TextStyle(
                              color: Color(0xFF9A3412),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (status == 'pending_review')
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _adminAction(
                                    'product',
                                    p['id'].toString(),
                                    'approve',
                                  ),
                          child: const Text('Aprovo'),
                        ),
                      if (status == 'pending_review')
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _requestProductCorrection(p),
                          child: const Text('Kërko korrigjim'),
                        ),
                      if (status == 'pending_review')
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _rejectManagedProduct(p),
                          child: const Text('Refuzo'),
                        ),
                      if (status == 'active')
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _adminAction(
                                    'product',
                                    p['id'].toString(),
                                    p['is_featured'] == true
                                        ? 'unfeature'
                                        : 'feature',
                                  ),
                          icon: Icon(
                            p['is_featured'] == true
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 17,
                          ),
                          label: Text(
                            p['is_featured'] == true
                                ? 'Hiq rekomandimin'
                                : 'Rekomando',
                          ),
                        ),
                      if (status == 'active')
                        IconButton(
                          tooltip: 'Çaktivizo',
                          onPressed: _busy
                              ? null
                              : () => _adminAction(
                                    'product',
                                    p['id'].toString(),
                                    'deactivate',
                                  ),
                          icon: const Icon(
                            Icons.pause_circle_outline_rounded,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Future<void> _rejectManagedVendor(
    Map<String, dynamic> vendor,
  ) async {
    final note = await _noteDialog(
      'Refuzo biznesin • ' + (vendor['display_name'] ?? '').toString(),
    );
    if (note == null || note.trim().isEmpty) return;
    await _adminAction(
      'vendor',
      vendor['id'].toString(),
      'reject',
      note: note,
    );
  }

  Future<void> _suspendManagedVendor(
    Map<String, dynamic> vendor,
  ) async {
    final note = await _noteDialog(
      'Pezullo biznesin • ' + (vendor['display_name'] ?? '').toString(),
    );
    if (note == null || note.trim().isEmpty) return;
    await _adminAction(
      'vendor',
      vendor['id'].toString(),
      'suspend',
      note: note,
    );
  }

  Widget _vendorsManagementTab(
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) {
      return const _EmptyBackoffice('Nuk ka biznese e-Market.');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: rows.map((v) {
        final status = (v['status'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4EAF2)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFF125C9E),
                ),
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
                            (v['display_name'] ?? '').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (v['is_verified'] == true) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF125C9E),
                            size: 17,
                          ),
                        ],
                        if (v['is_featured'] == true) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFF125C9E),
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (v['city'] ?? '—').toString() +
                          ' • ' +
                          (v['product_count'] ?? 0).toString() +
                          ' produkte • ' +
                          (v['order_count'] ?? 0).toString() +
                          ' porosi',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _ManagementTag(
                          icon: Icons.info_outline_rounded,
                          label: _marketManagementStatusLabel(status),
                          color: _marketManagementStatusColor(status),
                        ),
                        _ManagementTag(
                          icon: Icons.payments_outlined,
                          label: (v['revenue'] ?? 0).toString() +
                              ' ALL xhiro',
                          color: const Color(0xFF168C5A),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (status == 'pending')
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _adminAction(
                                'vendor',
                                v['id'].toString(),
                                'approve',
                              ),
                      child: const Text('Aprovo'),
                    ),
                  if (status == 'pending')
                    OutlinedButton(
                      onPressed:
                          _busy ? null : () => _rejectManagedVendor(v),
                      child: const Text('Refuzo'),
                    ),
                  if (status == 'approved')
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _adminAction(
                                'vendor',
                                v['id'].toString(),
                                v['is_featured'] == true
                                    ? 'unfeature'
                                    : 'feature',
                              ),
                      icon: Icon(
                        v['is_featured'] == true
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 17,
                      ),
                      label: Text(
                        v['is_featured'] == true
                            ? 'Hiq nga kryesoret'
                            : 'Shfaq te dyqanet',
                      ),
                    ),
                  if (status == 'approved')
                    IconButton(
                      tooltip: 'Pezullo',
                      onPressed: _busy
                          ? null
                          : () => _suspendManagedVendor(v),
                      icon: const Icon(Icons.block_rounded),
                    ),
                  if (status == 'suspended' || status == 'rejected')
                    FilledButton.tonal(
                      onPressed: _busy
                          ? null
                          : () => _adminAction(
                                'vendor',
                                v['id'].toString(),
                                'reactivate',
                              ),
                      child: const Text('Riaktivizo'),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _ordersManagementTab(
    List<Map<String, dynamic>> orders,
    List<Map<String, dynamic>> returns,
  ) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                icon: Icon(Icons.receipt_long_outlined),
                text: 'Porositë',
              ),
              Tab(
                icon: Icon(Icons.assignment_return_outlined),
                text: 'Kthimet',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: [
                orders.isEmpty
                    ? const _EmptyBackoffice('Nuk ka porosi e-Market.')
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 36),
                        children: orders.map((o) {
                          final status =
                              (o['status'] ?? '').toString();
                          return Container(
                            margin:
                                const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(17),
                              border: Border.all(
                                color: const Color(0xFFE4EAF2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Color(0xFF125C9E),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (o['order_number'] ?? '')
                                            .toString(),
                                        style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        (o['buyer_name'] ?? '')
                                                .toString() +
                                            ' • ' +
                                            (o['delivery_city'] ?? '')
                                                .toString() +
                                            ' • ' +
                                            (o['vendor_count'] ?? 0)
                                                .toString() +
                                            ' biznes(e)',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _ManagementTag(
                                  icon:
                                      Icons.info_outline_rounded,
                                  label:
                                      _marketManagementStatusLabel(
                                    status,
                                  ),
                                  color:
                                      _marketManagementStatusColor(
                                    status,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  (o['grand_total'] ?? 0)
                                          .toString() +
                                      ' ' +
                                      (o['currency'] ?? 'ALL')
                                          .toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                _returnsTab(returns),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewModerationList(
    List<Map<String, dynamic>> rows,
    String entity,
  ) {
    if (rows.isEmpty) {
      return const _EmptyBackoffice('Nuk ka vlerësime.');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: rows.map((r) {
        final status = (r['status'] ?? '').toString();
        final target = entity == 'product_review'
            ? (r['product_name'] ?? '').toString()
            : (r['vendor_name'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EAF2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target +
                          ' • ' +
                          (r['rating'] ?? 0).toString() +
                          '/5',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (r['buyer_name'] ?? 'Klient').toString() +
                          ' • ' +
                          _marketManagementStatusLabel(status),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    if ((r['comment'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text((r['comment'] ?? '').toString()),
                    ],
                  ],
                ),
              ),
              Wrap(
                spacing: 4,
                children: [
                  if (status != 'published')
                    IconButton(
                      tooltip: 'Publiko',
                      onPressed: _busy
                          ? null
                          : () => _adminAction(
                                entity,
                                r['id'].toString(),
                                'publish',
                              ),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                  if (status == 'published')
                    IconButton(
                      tooltip: 'Fshih',
                      onPressed: _busy
                          ? null
                          : () => _adminAction(
                                entity,
                                r['id'].toString(),
                                'hide',
                              ),
                      icon:
                          const Icon(Icons.visibility_off_outlined),
                    ),
                  if (status != 'removed')
                    IconButton(
                      tooltip: 'Hiq',
                      onPressed: _busy
                          ? null
                          : () => _adminAction(
                                entity,
                                r['id'].toString(),
                                'remove',
                              ),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _reportsManagementList(
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) {
      return const _EmptyBackoffice('Nuk ka raportime e-Market.');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: rows.map((r) {
        final status = (r['status'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EAF2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (r['entity_type'] ?? '').toString() +
                          ' • ' +
                          (r['reason'] ?? '').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (r['reporter_name'] ?? 'Përdorues')
                              .toString() +
                          ' • ' +
                          _marketManagementStatusLabel(status),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    if ((r['details'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text((r['details'] ?? '').toString()),
                    ],
                  ],
                ),
              ),
              Wrap(
                spacing: 4,
                children: [
                  if (status == 'open')
                    IconButton(
                      tooltip: 'Në shqyrtim',
                      onPressed: _busy
                          ? null
                          : () => _adminAction(
                                'report',
                                r['id'].toString(),
                                'reviewing',
                              ),
                      icon: const Icon(
                        Icons.manage_search_rounded,
                      ),
                    ),
                  if (status != 'resolved')
                    IconButton(
                      tooltip: 'Zgjidh',
                      onPressed: _busy
                          ? null
                          : () => _adminAction(
                                'report',
                                r['id'].toString(),
                                'resolve',
                              ),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF168C5A),
                      ),
                    ),
                  if (status != 'resolved' &&
                      status != 'dismissed')
                    IconButton(
                      tooltip: 'Mbyll pa veprim',
                      onPressed: _busy
                          ? null
                          : () => _adminAction(
                                'report',
                                r['id'].toString(),
                                'dismiss',
                              ),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _moderationManagementTab(
    Map<String, dynamic> data,
  ) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: 'Vlerësime produktesh',
              ),
              Tab(
                icon: Icon(Icons.storefront_outlined),
                text: 'Vlerësime dyqanesh',
              ),
              Tab(
                icon: Icon(Icons.flag_outlined),
                text: 'Raportime',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: [
                _reviewModerationList(
                  _rows(data, 'product_reviews'),
                  'product_review',
                ),
                _reviewModerationList(
                  _rows(data, 'vendor_reviews'),
                  'vendor_review',
                ),
                _reportsManagementList(
                  _rows(data, 'reports'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsManagementTab(
    Map<String, dynamic> data,
  ) {
    final analytics = Map<String, dynamic>.from(
      (data['analytics'] as Map?) ?? const {},
    );
    final topProducts = List<Map<String, dynamic>>.from(
      (analytics['top_products'] as List?) ?? const [],
    );
    final topCategories = List<Map<String, dynamic>>.from(
      (analytics['top_categories'] as List?) ?? const [],
    );
    final audit = _rows(data, 'audit');

    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 720
                ? (constraints.maxWidth - 10) / 2
                : (constraints.maxWidth - 30) / 4;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ManagementKpi(
                  width: width,
                  label: 'Produkte aktive',
                  value: analytics['products_active'],
                  icon: Icons.inventory_2_rounded,
                ),
                _ManagementKpi(
                  width: width,
                  label: 'Në aprovim',
                  value: analytics['products_pending'],
                  icon: Icons.hourglass_top_rounded,
                ),
                _ManagementKpi(
                  width: width,
                  label: 'Korrigjime',
                  value: analytics['products_correction'],
                  icon: Icons.edit_note_rounded,
                ),
                _ManagementKpi(
                  width: width,
                  label: 'Biznese aktive',
                  value: analytics['vendors_approved'],
                  icon: Icons.storefront_rounded,
                ),
                _ManagementKpi(
                  width: width,
                  label: 'Porosi',
                  value: analytics['orders_total'],
                  icon: Icons.shopping_bag_rounded,
                ),
                _ManagementKpi(
                  width: width,
                  label: 'Xhiro bruto',
                  value:
                      (analytics['gross_sales'] ?? 0).toString() +
                          ' ALL',
                  icon: Icons.payments_outlined,
                ),
                _ManagementKpi(
                  width: width,
                  label: 'Raportime hapur',
                  value: analytics['reports_open'],
                  icon: Icons.flag_rounded,
                ),
                _ManagementKpi(
                  width: width,
                  label: 'Stok i ulët',
                  value: analytics['products_low_stock'],
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _ManagementPanel(
          title: 'Produktet më të shitura',
          child: topProducts.isEmpty
              ? const Text('Nuk ka ende të dhëna shitjesh.')
              : Column(
                  children: topProducts.map((p) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.trending_up_rounded,
                      ),
                      title: Text(
                        (p['product_name'] ?? '').toString(),
                      ),
                      trailing: Text(
                        (p['units'] ?? 0).toString() + ' copë',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 12),
        _ManagementPanel(
          title: 'Kategoritë më të shitura',
          child: topCategories.isEmpty
              ? const Text('Nuk ka ende të dhëna shitjesh.')
              : Column(
                  children: topCategories.map((p) {
                    return ListTile(
                      dense: true,
                      leading:
                          const Icon(Icons.category_outlined),
                      title:
                          Text((p['name_sq'] ?? '').toString()),
                      trailing: Text(
                        (p['units'] ?? 0).toString() + ' copë',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 12),
        _ManagementPanel(
          title: 'Regjistri i veprimeve e-Market',
          child: audit.isEmpty
              ? const Text(
                  'Nuk ka ende veprime të regjistruara.',
                )
              : Column(
                  children: audit.take(40).map((a) {
                    return ListTile(
                      dense: true,
                      leading:
                          const Icon(Icons.history_rounded),
                      title: Text(
                        (a['action'] ?? '').toString() +
                            ' • ' +
                            (a['entity_type'] ?? '').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        (a['actor_name'] ??
                                'Administrator')
                            .toString(),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
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
        final products = _rows(data, 'products');
        final orders = _rows(data, 'orders');
        final promotions = _rows(data, 'promotions');
        final subscriptions = _rows(data, 'subscriptions');
        final commissions = _rows(data, 'commissions');

        return DefaultTabController(
          length: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'e-Market • Menaxhim i Plotë',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Kontrolli qendror i përmbajtjes, produkteve, bizneseve, porosive, marketingut, financave dhe moderimit.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Rifresko',
                      onPressed: _busy ? null : () => setState(_reload),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(
                    icon: Icon(Icons.dashboard_customize_outlined),
                    text: 'Përmbajtja',
                  ),
                  Tab(
                    icon: Icon(Icons.inventory_2_outlined),
                    text: 'Produktet',
                  ),
                  Tab(
                    icon: Icon(Icons.storefront_outlined),
                    text: 'Bizneset',
                  ),
                  Tab(
                    icon: Icon(Icons.shopping_bag_outlined),
                    text: 'Porositë',
                  ),
                  Tab(
                    icon: Icon(Icons.campaign_outlined),
                    text: 'Marketing',
                  ),
                  Tab(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    text: 'Financa',
                  ),
                  Tab(
                    icon: Icon(Icons.shield_outlined),
                    text: 'Moderim',
                  ),
                  Tab(
                    icon: Icon(Icons.query_stats_outlined),
                    text: 'Analitika',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: TabBarView(
                  children: [
                    DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          const TabBar(
                            isScrollable: true,
                            tabs: [
                              Tab(
                                icon: Icon(Icons.campaign_outlined),
                                text: 'Reklama',
                              ),
                              Tab(
                                icon: Icon(Icons.category_outlined),
                                text: 'Kategori',
                              ),
                              Tab(
                                icon: Icon(Icons.sell_outlined),
                                text: 'Marka',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _bannersTab(_rows(data, 'banners')),
                                _simpleCrudTab(
                                  context,
                                  rows: _rows(data, 'categories'),
                                  addLabel: 'Shto kategori',
                                  onAdd: _createCategory,
                                  title: (r) =>
                                      (r['name_sq'] ?? '').toString(),
                                  subtitle: (r) =>
                                      (r['audience'] ?? '').toString() +
                                      ' • ' +
                                      (r['product_count'] ?? 0).toString() +
                                      ' produkte',
                                  trailing: (r) => Switch(
                                    value: r['is_active'] == true,
                                    onChanged: _busy
                                        ? null
                                        : (_) => _action(
                                              'category',
                                              r['id'].toString(),
                                              'toggle',
                                            ),
                                  ),
                                ),
                                _simpleCrudTab(
                                  context,
                                  rows: _rows(data, 'brands'),
                                  addLabel: 'Shto markë',
                                  onAdd: _createBrand,
                                  title: (r) =>
                                      (r['name'] ?? '').toString(),
                                  subtitle: (r) =>
                                      (r['product_count'] ?? 0).toString() +
                                      ' produkte',
                                  trailing: (r) => Switch(
                                    value: r['is_active'] == true,
                                    onChanged: _busy
                                        ? null
                                        : (_) => _action(
                                              'brand',
                                              r['id'].toString(),
                                              'toggle',
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _productsManagementTab(products),
                    _vendorsManagementTab(vendors),
                    _ordersManagementTab(
                      orders,
                      _rows(data, 'returns'),
                    ),
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            isScrollable: true,
                            tabs: [
                              Tab(
                                icon: Icon(Icons.local_offer_outlined),
                                text: 'Promocione',
                              ),
                              Tab(
                                icon: Icon(Icons.auto_awesome_outlined),
                                text: 'Rekomanduara',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _simpleCrudTab(
                                  context,
                                  rows: promotions,
                                  addLabel: 'Shto promocion',
                                  onAdd: () => _createPromotion(vendors),
                                  title: (r) =>
                                      (r['name'] ?? '').toString(),
                                  subtitle: (r) =>
                                      (r['vendor_name'] ?? 'Global')
                                              .toString() +
                                      ' • ' +
                                      (r['value'] ?? 0).toString(),
                                  trailing: (r) => Switch(
                                    value: r['is_active'] == true,
                                    onChanged: _busy
                                        ? null
                                        : (_) => _action(
                                              'promotion',
                                              r['id'].toString(),
                                              'toggle',
                                            ),
                                  ),
                                ),
                                ListView(
                                  padding:
                                      const EdgeInsets.only(bottom: 36),
                                  children: [
                                    if (!products.any(
                                      (p) => p['is_featured'] == true,
                                    ))
                                      const _EmptyBackoffice(
                                        'Nuk ka produkte të rekomanduara.',
                                      )
                                    else
                                      ...products
                                          .where(
                                            (p) =>
                                                p['is_featured'] == true,
                                          )
                                          .map(
                                            (p) => ListTile(
                                              leading: const Icon(
                                                Icons.auto_awesome_rounded,
                                                color: Color(0xFF125C9E),
                                              ),
                                              title: Text(
                                                (p['name'] ?? '')
                                                    .toString(),
                                                style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w900,
                                                ),
                                              ),
                                              subtitle: Text(
                                                (p['vendor_name'] ?? '')
                                                        .toString() +
                                                    ' • ' +
                                                    (p['category_name'] ?? '')
                                                        .toString(),
                                              ),
                                              trailing: OutlinedButton(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _adminAction(
                                                          'product',
                                                          p['id'].toString(),
                                                          'unfeature',
                                                        ),
                                                child: const Text('Hiq'),
                                              ),
                                            ),
                                          ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            isScrollable: true,
                            tabs: [
                              Tab(
                                icon: Icon(
                                  Icons.workspace_premium_outlined,
                                ),
                                text: 'Abonime',
                              ),
                              Tab(
                                icon: Icon(Icons.percent_rounded),
                                text: 'Komisione',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _subscriptionsTab(
                                  subscriptions,
                                  vendors,
                                ),
                                _commissionsTab(commissions),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _moderationManagementTab(data),
                    _analyticsManagementTab(data),
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

Color _marketManagementStatusColor(String status) {
  switch (status) {
    case 'active':
    case 'approved':
    case 'published':
    case 'resolved':
    case 'delivered':
      return const Color(0xFF168C5A);
    case 'pending':
    case 'pending_review':
    case 'reviewing':
    case 'processing':
    case 'confirmed':
      return const Color(0xFFB7791F);
    case 'needs_correction':
      return const Color(0xFFC2410C);
    case 'rejected':
    case 'suspended':
    case 'removed':
    case 'cancelled':
      return const Color(0xFFC24141);
    default:
      return const Color(0xFF667085);
  }
}

String _marketManagementStatusLabel(String status) {
  switch (status) {
    case 'pending_review':
      return 'Në aprovim';
    case 'needs_correction':
      return 'Kërkon korrigjim';
    case 'active':
      return 'Aktiv';
    case 'approved':
      return 'Aprovuar';
    case 'rejected':
      return 'Refuzuar';
    case 'suspended':
      return 'Pezulluar';
    case 'inactive':
      return 'Jo aktiv';
    case 'archived':
      return 'Arkivuar';
    case 'pending':
      return 'Në pritje';
    case 'confirmed':
      return 'Konfirmuar';
    case 'processing':
      return 'Në përpunim';
    case 'shipped':
      return 'Dërguar';
    case 'delivered':
      return 'Dorëzuar';
    case 'cancelled':
      return 'Anuluar';
    case 'published':
      return 'Publikuar';
    case 'hidden':
      return 'Fshehur';
    case 'reported':
      return 'Raportuar';
    case 'removed':
      return 'Hequr';
    case 'reviewing':
      return 'Në shqyrtim';
    case 'resolved':
      return 'Zgjidhur';
    case 'dismissed':
      return 'Mbyllur';
    default:
      return status;
  }
}

class _ManagementFilterChip extends StatelessWidget {
  const _ManagementFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF125C9E)
                : const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF125C9E)
                  : const Color(0xFFE4EAF2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : const Color(0xFF344054),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      );
}

class _ManagementTag extends StatelessWidget {
  const _ManagementTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
}

class _ManagementKpi extends StatelessWidget {
  const _ManagementKpi({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final dynamic value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: const Color(0xFFE4EAF2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF125C9E)
                      .withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF125C9E),
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (value ?? 0).toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ManagementPanel extends StatelessWidget {
  const _ManagementPanel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE4EAF2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
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
