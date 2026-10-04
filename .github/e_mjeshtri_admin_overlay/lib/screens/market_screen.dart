import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketAdminScreen extends StatefulWidget {
  const MarketAdminScreen({super.key});
  @override
  State<MarketAdminScreen> createState() => _MarketAdminScreenState();
}

class _MarketAdminScreenState extends State<MarketAdminScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic> _data = const {};

  Map<String, dynamic> get _kpis =>
      Map<String, dynamic>.from((_data['kpis'] as Map?) ?? const {});
  List<Map<String, dynamic>> get _vendors =>
      List<Map<String, dynamic>>.from((_data['vendors'] as List?) ?? const []);
  List<Map<String, dynamic>> get _pendingProducts =>
      List<Map<String, dynamic>>.from((_data['products_pending'] as List?) ?? const []);
  List<Map<String, dynamic>> get _recentOrders =>
      List<Map<String, dynamic>>.from((_data['orders_recent'] as List?) ?? const []);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _client.rpc('admin_market_overview');
      if (raw is! Map) throw const FormatException('Përgjigje e pavlefshme nga e-Market.');
      _data = Map<String, dynamic>.from(raw);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(String entity, String id, String action, {bool askNote = false}) async {
    String? note;
    if (askNote) {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Arsye / shënim'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Shkruaj arsyen...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulo')),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Vazhdo'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (note == null) return;
    }

    setState(() => _busy = true);
    try {
      await _client.rpc('admin_market_action', params: {
        'p_entity': entity,
        'p_id': id,
        'p_action': action,
        'p_note': note,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ndryshimi u ruajt.')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 70),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.storefront_rounded, color: Color(0xFF125C9E)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('e-Market', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text(
                    'Kontrolli i shitësve, produkteve dhe porosive të marketplace-it',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Rifresko',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cardWidth = width < 650
                ? (width - 12) / 2
                : width < 1050
                    ? (width - 24) / 3
                    : (width - 48) / 5;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Kpi('Shitës', _kpis['vendors_total'], Icons.store_rounded, cardWidth),
                _Kpi('Në pritje', _kpis['vendors_pending'], Icons.hourglass_top_rounded, cardWidth),
                _Kpi('Produkte aktive', _kpis['products_active'], Icons.inventory_2_rounded, cardWidth),
                _Kpi('Produkte për aprovim', _kpis['products_pending'], Icons.fact_check_rounded, cardWidth),
                _Kpi('Porosi', _kpis['orders_total'], Icons.shopping_bag_rounded, cardWidth),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Shitësit',
          subtitle: 'Regjistrimet e bizneseve që duan të shesin në e-Market.',
          child: _vendors.isEmpty
              ? const _Empty('Nuk ka ende shitës të regjistruar.')
              : Column(
                  children: _vendors.map((v) => _VendorCard(
                    row: v,
                    busy: _busy,
                    onApprove: () => _action('vendor', v['id'].toString(), 'approve'),
                    onReject: () => _action('vendor', v['id'].toString(), 'reject', askNote: true),
                    onSuspend: () => _action('vendor', v['id'].toString(), 'suspend', askNote: true),
                    onReactivate: () => _action('vendor', v['id'].toString(), 'reactivate'),
                  )).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Produkte në pritje',
          subtitle: 'Produktet e reja nuk publikohen pa kontrollin e Adminit.',
          child: _pendingProducts.isEmpty
              ? const _Empty('Nuk ka produkte në pritje për aprovim.')
              : Column(
                  children: _pendingProducts.map((p) => _ProductCard(
                    row: p,
                    busy: _busy,
                    onApprove: () => _action('product', p['id'].toString(), 'approve'),
                    onReject: () => _action('product', p['id'].toString(), 'reject', askNote: true),
                  )).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Porositë e fundit',
          subtitle: 'Pamje e shpejtë e porosive multi-vendor.',
          child: _recentOrders.isEmpty
              ? const _Empty('Nuk ka ende porosi e-Market.')
              : Column(
                  children: _recentOrders.map((o) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const CircleAvatar(child: Icon(Icons.shopping_bag_outlined)),
                    title: Text(
                      (o['order_number'] ?? 'Porosi').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      (o['first_name'] ?? '').toString() +
                          ' ' +
                          (o['last_name'] ?? '').toString() +
                          ' • ' +
                          (o['status'] ?? '').toString(),
                    ),
                    trailing: Text(
                      (o['grand_total'] ?? 0).toString() +
                          ' ' +
                          (o['currency'] ?? 'ALL').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  )).toList(),
                ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon, this.width);
  final String label;
  final dynamic value;
  final IconData icon;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF125C9E)),
            const SizedBox(height: 12),
            Text(
              (value ?? 0).toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.row,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
    required this.onReactivate,
  });
  final Map<String, dynamic> row;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSuspend;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final status = (row['status'] ?? '').toString();
    final detail = (row['city'] ?? '').toString() +
        ' • ' +
        (row['email'] ?? '').toString();
    final counters = (row['product_count'] ?? 0).toString() +
        ' produkte • ' +
        (row['order_count'] ?? 0).toString() +
        ' porosi';
    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFD),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.storefront_rounded)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (row['display_name'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(detail, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            const SizedBox(height: 10),
            Text(counters, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status == 'pending' || status == 'rejected')
                  FilledButton(onPressed: busy ? null : onApprove, child: const Text('Aprovo')),
                if (status == 'pending')
                  OutlinedButton(onPressed: busy ? null : onReject, child: const Text('Refuzo')),
                if (status == 'approved')
                  OutlinedButton(onPressed: busy ? null : onSuspend, child: const Text('Pezullo')),
                if (status == 'suspended')
                  FilledButton(onPressed: busy ? null : onReactivate, child: const Text('Riaktivizo')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.row,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });
  final Map<String, dynamic> row;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final subtitle = (row['vendor_name'] ?? '').toString() +
        ' • ' +
        (row['category_name'] ?? '').toString() +
        ' • ' +
        (row['retail_price'] ?? 0).toString() +
        ' ' +
        (row['currency'] ?? 'ALL').toString();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
      title: Text(
        (row['name'] ?? '').toString(),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(subtitle),
      trailing: Wrap(
        spacing: 6,
        children: [
          IconButton(
            tooltip: 'Aprovo',
            onPressed: busy ? null : onApprove,
            icon: const Icon(Icons.check_circle_outline_rounded),
          ),
          IconButton(
            tooltip: 'Refuzo',
            onPressed: busy ? null : onReject,
            icon: const Icon(Icons.cancel_outlined),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFD),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 38, color: Colors.black38),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(color: Colors.black54)),
      ],
    ),
  );
}
