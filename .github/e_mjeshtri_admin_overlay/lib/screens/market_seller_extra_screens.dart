import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../data/market_seller_repository.dart';

String marketMoney(dynamic value, [String currency = 'ALL']) {
  final n = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  final text = n.truncateToDouble() == n ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  return text + ' ' + currency;
}

String marketStatusSq(String value) {
  const labels = <String, String>{
    'pending': 'Në pritje',
    'confirmed': 'Konfirmuar',
    'processing': 'Po përgatitet',
    'shipped': 'U nis',
    'delivered': 'U dorëzua',
    'cancelled': 'U anulua',
    'requested': 'Kërkuar',
    'vendor_approved': 'Pranuar nga shitësi',
    'vendor_rejected': 'Refuzuar nga shitësi',
    'escalated': 'Në shqyrtim nga Admini',
    'admin_approved': 'Aprovuar nga Admini',
    'admin_rejected': 'Refuzuar nga Admini',
    'received': 'Produkti u kthye',
    'refunded': 'Rimbursuar',
    'closed': 'Mbyllur',
    'paid': 'Paguar',
    'awaiting_confirmation': 'Pret konfirmim',
    'failed': 'Dështoi',
  };
  return labels[value] ?? value;
}

class MarketSellerSales extends StatefulWidget {
  const MarketSellerSales({super.key, required this.vendorId});
  final String vendorId;
  @override
  State<MarketSellerSales> createState() => _MarketSellerSalesState();
}

class _MarketSellerSalesState extends State<MarketSellerSales> {
  final repo = MarketSellerRepository.instance;
  late Future<Map<String, dynamic>> future;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { future = repo.sales(widget.vendorId); }

  @override
  Widget build(BuildContext context) => SellerExtraPage(
    title: 'Shitjet',
    subtitle: 'Porositë e dorëzuara dhe xhiroja e dyqanit',
    onRefresh: () => setState(reload),
    child: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || snap.data == null) {
          return const SellerExtraEmpty('Shitjet nuk mund të ngarkoheshin.');
        }
        final data = snap.data!;
        final summary = Map<String, dynamic>.from((data['summary'] as Map?) ?? const {});
        final sales = List<Map<String, dynamic>>.from((data['sales'] as List?) ?? const []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              final cw = w < 650 ? (w - 12) / 2 : (w - 36) / 4;
              return Wrap(
                spacing: 12, runSpacing: 12,
                children: [
                  SellerExtraKpi('Shitje', summary['sales_count'], Icons.shopping_cart_checkout_rounded, cw),
                  SellerExtraKpi('Produkte të shitura', summary['products_sold'], Icons.inventory_2_outlined, cw),
                  SellerExtraKpi('Xhiro totale', marketMoney(summary['gross_sales']), Icons.payments_outlined, cw),
                  SellerExtraKpi('Këtë muaj', marketMoney(summary['this_month']), Icons.calendar_month_outlined, cw),
                ],
              );
            }),
            const SizedBox(height: 18),
            if (sales.isEmpty)
              const SellerExtraEmpty('Nuk ka ende shitje të përfunduara.')
            else
              ...sales.map((s) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.check_circle_outline_rounded)),
                  title: Text((s['vendor_order_number'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text((s['delivery_name'] ?? '').toString() + ' • ' + (s['delivery_city'] ?? '').toString() + ' • ' + (s['item_count'] ?? 0).toString() + ' artikuj'),
                  trailing: Text(marketMoney(s['total'], (s['currency'] ?? 'ALL').toString()), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              )),
          ],
        );
      },
    ),
  );
}

class MarketSellerCancellationsReturns extends StatefulWidget {
  const MarketSellerCancellationsReturns({super.key, required this.vendorId});
  final String vendorId;
  @override
  State<MarketSellerCancellationsReturns> createState() => _MarketSellerCancellationsReturnsState();
}

class _MarketSellerCancellationsReturnsState extends State<MarketSellerCancellationsReturns> {
  final repo = MarketSellerRepository.instance;
  late Future<Map<String, dynamic>> future;
  bool busy = false;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { future = repo.cancellationsAndReturns(widget.vendorId); }

  Future<void> act(Map<String, dynamic> row, String action) async {
    final c = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action == 'approve' ? 'Prano kthimin' : 'Refuzo kthimin'),
        content: TextField(controller: c, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Shënim / arsye')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulo')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Ruaj')),
        ],
      ),
    );
    c.dispose();
    if (note == null) return;
    setState(() => busy = true);
    try {
      await repo.returnAction(vendorId: widget.vendorId, returnId: row['id'].toString(), action: action, note: note);
      if (mounted) setState(reload);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SellerExtraPage(
    title: 'Anullime & Kthime',
    subtitle: 'Porositë e anulluara dhe kërkesat për kthim',
    onRefresh: () => setState(reload),
    child: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError || snap.data == null) return const SellerExtraEmpty('Të dhënat nuk mund të ngarkoheshin.');
        final cancelled = List<Map<String, dynamic>>.from((snap.data!['cancelled'] as List?) ?? const []);
        final returns = List<Map<String, dynamic>>.from((snap.data!['returns'] as List?) ?? const []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SellerExtraSectionTitle('Kthimet', 'Kërkesat që vijnë nga blerësit'),
            const SizedBox(height: 10),
            if (returns.isEmpty)
              const SellerExtraEmpty('Nuk ka kërkesa kthimi.')
            else
              ...returns.map((r) {
                final status = (r['status'] ?? '').toString();
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text((r['vendor_order_number'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900))),
                          Chip(label: Text(marketStatusSq(status))),
                        ]),
                        const SizedBox(height: 5),
                        Text('Arsyeja: ' + (r['reason'] ?? '').toString()),
                        if ((r['buyer_note'] ?? '').toString().trim().isNotEmpty)
                          Text('Shënim klienti: ' + (r['buyer_note'] ?? '').toString()),
                        const SizedBox(height: 10),
                        if (status == 'requested')
                          Wrap(spacing: 8, children: [
                            FilledButton.icon(onPressed: busy ? null : () => act(r, 'approve'), icon: const Icon(Icons.check_rounded), label: const Text('Prano')),
                            OutlinedButton.icon(onPressed: busy ? null : () => act(r, 'reject'), icon: const Icon(Icons.close_rounded), label: const Text('Refuzo')),
                          ]),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            const SellerExtraSectionTitle('Porositë e anulluara', 'Historiku i anullimeve'),
            const SizedBox(height: 10),
            if (cancelled.isEmpty)
              const SellerExtraEmpty('Nuk ka porosi të anulluara.')
            else
              ...cancelled.map((o) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.cancel_outlined)),
                  title: Text((o['vendor_order_number'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text((o['delivery_name'] ?? '').toString() + ' • ' + (o['delivery_city'] ?? '').toString()),
                  trailing: Text(marketMoney(o['total'], (o['currency'] ?? 'ALL').toString()), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              )),
          ],
        );
      },
    ),
  );
}

class MarketSellerInvoices extends StatefulWidget {
  const MarketSellerInvoices({super.key, required this.vendorId});
  final String vendorId;
  @override
  State<MarketSellerInvoices> createState() => _MarketSellerInvoicesState();
}

class _MarketSellerInvoicesState extends State<MarketSellerInvoices> {
  final repo = MarketSellerRepository.instance;
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { future = repo.invoices(widget.vendorId); }

  String esc(dynamic value) => (value ?? '').toString()
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  void printInvoice(Map<String, dynamic> i) {
    final currency = esc(i['currency'] ?? 'ALL');
    final body = '<!doctype html><html><head><meta charset="utf-8"><title>' + esc(i['invoice_number']) +
      '</title><style>body{font-family:Arial,sans-serif;margin:40px;color:#182235}h1{margin:0 0 6px;font-size:28px}.muted{color:#667085}.box{border:1px solid #e5e7eb;border-radius:14px;padding:18px;margin-top:18px}.row{display:flex;justify-content:space-between;gap:20px;margin:6px 0}.total{font-size:22px;font-weight:700;color:#125C9E}@media print{button{display:none}}</style></head><body>' +
      '<h1>Faturë e-Market</h1><div class="muted">' + esc(i['invoice_number']) + '</div>' +
      '<div class="box"><strong>Shitësi</strong><div>' + esc(i['seller_display_name']) + '</div><div>' + esc(i['seller_legal_name']) + '</div><div>NIPT/NUIS: ' + esc(i['seller_tax_id']) + '</div><div>' + esc(i['seller_street']) + ', ' + esc(i['seller_city']) + '</div></div>' +
      '<div class="box"><strong>Blerësi</strong><div>' + esc(i['buyer_name']) + '</div><div>' + esc(i['buyer_phone']) + '</div><div>' + esc(i['buyer_street']) + ', ' + esc(i['buyer_city']) + ' ' + esc(i['buyer_postal_code']) + '</div></div>' +
      '<div class="box"><div class="row"><span>Porosia</span><strong>' + esc(i['order_number']) + '</strong></div><div class="row"><span>Nëntotali</span><strong>' + esc(i['subtotal']) + ' ' + currency + '</strong></div><div class="row"><span>Transporti</span><strong>' + esc(i['delivery_fee']) + ' ' + currency + '</strong></div><div class="row"><span>Zbritja</span><strong>' + esc(i['discount_total']) + ' ' + currency + '</strong></div><hr><div class="row total"><span>Totali</span><span>' + esc(i['total']) + ' ' + currency + '</span></div><div class="row"><span>Pagesa</span><span>' + esc(i['payment_method']) + ' • ' + esc(i['payment_status']) + '</span></div></div>' +
      '<p class="muted">Dokument i gjeneruar nga e-Market. Për faturim fiskal përdoret dokumentacioni fiskal i shitësit.</p><button onclick="window.print()">Printo / Ruaj PDF</button></body></html>';
    final blob = html.Blob([body], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    Future.delayed(const Duration(seconds: 20), () => html.Url.revokeObjectUrl(url));
  }

  @override
  Widget build(BuildContext context) => SellerExtraPage(
    title: 'Faturat',
    subtitle: 'Dokumentet e krijuara për porositë e dorëzuara',
    onRefresh: () => setState(reload),
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return const SellerExtraEmpty('Faturat nuk mund të ngarkoheshin.');
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return const SellerExtraEmpty('Nuk ka ende fatura.');
        return Column(children: rows.map((i) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
            title: Text((i['invoice_number'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text((i['order_number'] ?? '').toString() + ' • ' + (i['buyer_name'] ?? '').toString()),
            trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(marketMoney(i['total'], (i['currency'] ?? 'ALL').toString()), style: const TextStyle(fontWeight: FontWeight.w900)),
              IconButton(tooltip: 'Printo / Ruaj PDF', onPressed: () => printInvoice(i), icon: const Icon(Icons.print_outlined)),
            ]),
          ),
        )).toList());
      },
    ),
  );
}

class MarketSellerInventory extends StatefulWidget {
  const MarketSellerInventory({super.key, required this.vendorId});
  final String vendorId;
  @override
  State<MarketSellerInventory> createState() => _MarketSellerInventoryState();
}

class _MarketSellerInventoryState extends State<MarketSellerInventory> {
  final repo = MarketSellerRepository.instance;
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { future = repo.inventory(widget.vendorId); }

  Future<void> changeStock(Map<String, dynamic> row) async {
    final c = TextEditingController(text: (row['stock_quantity'] ?? 0).toString());
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stoku • ' + (row['name'] ?? '').toString()),
        content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sasia në stok')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulo')),
          FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(c.text.trim())), child: const Text('Ruaj')),
        ],
      ),
    );
    c.dispose();
    if (value == null || value < 0) return;
    await repo.updateStock(productId: row['id'].toString(), stockQuantity: value);
    if (mounted) setState(reload);
  }

  @override
  Widget build(BuildContext context) => SellerExtraPage(
    title: 'Stoku',
    subtitle: 'Kontrollo stokun fizik, të rezervuar dhe stokun e lirë',
    onRefresh: () => setState(reload),
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return const SellerExtraEmpty('Nuk ka produkte në inventar.');
        return Column(children: rows.map((p) {
          final stock = (p['stock_quantity'] as num?)?.toInt() ?? 0;
          final reserved = (p['reserved_quantity'] as num?)?.toInt() ?? 0;
          final low = (p['low_stock_threshold'] as num?)?.toInt() ?? 0;
          final available = stock - reserved;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(child: Icon(available <= low ? Icons.warning_amber_rounded : Icons.inventory_2_outlined)),
              title: Text((p['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('Fizik: ' + stock.toString() + ' • Rezervuar: ' + reserved.toString() + ' • I lirë: ' + available.toString()),
              trailing: IconButton(tooltip: 'Ndrysho stokun', onPressed: () => changeStock(p), icon: const Icon(Icons.edit_outlined)),
            ),
          );
        }).toList());
      },
    ),
  );
}

class MarketSellerFinance extends StatefulWidget {
  const MarketSellerFinance({super.key, required this.vendorId});
  final String vendorId;
  @override
  State<MarketSellerFinance> createState() => _MarketSellerFinanceState();
}

class _MarketSellerFinanceState extends State<MarketSellerFinance> {
  final repo = MarketSellerRepository.instance;
  late Future<Map<String, dynamic>> future;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { future = repo.finance(widget.vendorId); }

  @override
  Widget build(BuildContext context) => SellerExtraPage(
    title: 'Financat',
    subtitle: 'Pagesat e marra, në pritje dhe komisionet',
    onRefresh: () => setState(reload),
    child: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError || snap.data == null) return const SellerExtraEmpty('Financat nuk mund të ngarkoheshin.');
        final summary = Map<String, dynamic>.from((snap.data!['summary'] as Map?) ?? const {});
        final payments = List<Map<String, dynamic>>.from((snap.data!['payments'] as List?) ?? const []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              final cw = w < 650 ? (w - 12) / 2 : (w - 36) / 4;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                SellerExtraKpi('Paguar', marketMoney(summary['paid']), Icons.check_circle_outline_rounded, cw),
                SellerExtraKpi('Në pritje', marketMoney(summary['pending']), Icons.hourglass_top_rounded, cw),
                SellerExtraKpi('Rimbursime', marketMoney(summary['refunded']), Icons.undo_rounded, cw),
                SellerExtraKpi('Komisione', marketMoney(summary['commission_due']), Icons.percent_rounded, cw),
              ]);
            }),
            const SizedBox(height: 18),
            if (payments.isEmpty)
              const SellerExtraEmpty('Nuk ka ende lëvizje financiare.')
            else
              ...payments.map((p) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
                  title: Text((p['vendor_order_number'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text((p['payment_method'] ?? '').toString() + ' • ' + marketStatusSq((p['status'] ?? '').toString())),
                  trailing: Text(marketMoney(p['amount'], (p['currency'] ?? 'ALL').toString()), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              )),
          ],
        );
      },
    ),
  );
}

class MarketProductMediaDialog extends StatefulWidget {
  const MarketProductMediaDialog({
    super.key,
    required this.vendorId,
    required this.productId,
    required this.productName,
  });
  final String vendorId;
  final String productId;
  final String productName;
  @override
  State<MarketProductMediaDialog> createState() => _MarketProductMediaDialogState();
}

class _MarketProductMediaDialogState extends State<MarketProductMediaDialog> {
  final repo = MarketSellerRepository.instance;
  late Future<List<Map<String, dynamic>>> future;
  bool busy = false;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { future = repo.productMedia(widget.productId); }

  Future<void> addImage() async {
    final file = await repo.pickFile();
    if (file == null) return;
    setState(() => busy = true);
    try {
      await repo.uploadProductImage(vendorId: widget.vendorId, productId: widget.productId, file: file);
      if (mounted) setState(reload);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> setPrimary(Map<String, dynamic> m) async {
    setState(() => busy = true);
    try {
      await repo.setPrimaryProductMedia(productId: widget.productId, mediaId: m['id'].toString());
      if (mounted) setState(reload);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteMedia(Map<String, dynamic> m) async {
    setState(() => busy = true);
    try {
      await repo.deleteProductMedia(mediaId: m['id'].toString(), productId: widget.productId, storagePath: m['storage_path'].toString());
      if (mounted) setState(reload);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Fotot • ' + widget.productName),
    content: SizedBox(
      width: 720,
      height: 500,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final media = snap.data ?? const [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                FilledButton.icon(onPressed: busy ? null : addImage, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Shto foto')),
                const SizedBox(width: 10),
                Text(media.length.toString() + ' foto', style: const TextStyle(color: Colors.black54)),
              ]),
              const SizedBox(height: 14),
              Expanded(
                child: media.isEmpty
                    ? const SellerExtraEmpty('Nuk ka foto. Shto të paktën një foto të produktit.')
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                        ),
                        itemCount: media.length,
                        itemBuilder: (context, index) {
                          final m = media[index];
                          return FutureBuilder<String?>(
                            future: repo.signedMarketMediaUrl(m['storage_path']?.toString()),
                            builder: (context, urlSnap) => Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F7FB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: m['is_primary'] == true ? const Color(0xFF125C9E) : const Color(0xFFE5E7EB),
                                  width: m['is_primary'] == true ? 2 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (urlSnap.data != null)
                                    Image.network(urlSnap.data!, fit: BoxFit.cover)
                                  else
                                    const Icon(Icons.image_outlined, size: 42),
                                  Positioned(
                                    top: 6, right: 6,
                                    child: Row(children: [
                                      if (m['is_primary'] != true)
                                        IconButton.filledTonal(
                                          tooltip: 'Bëje kryesore',
                                          onPressed: busy ? null : () => setPrimary(m),
                                          icon: const Icon(Icons.star_outline_rounded),
                                        ),
                                      const SizedBox(width: 4),
                                      IconButton.filledTonal(
                                        tooltip: 'Fshi',
                                        onPressed: busy ? null : () => deleteMedia(m),
                                        icon: const Icon(Icons.delete_outline_rounded),
                                      ),
                                    ]),
                                  ),
                                  if (m['is_primary'] == true)
                                    const Positioned(left: 8, bottom: 8, child: Chip(label: Text('Foto kryesore'))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
    actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Mbyll'))],
  );
}

class SellerExtraPage extends StatelessWidget {
  const SellerExtraPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onRefresh,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 50),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
          )),
          if (onRefresh != null)
            IconButton(tooltip: 'Rifresko', onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
        ]),
        const SizedBox(height: 22),
        child,
      ],
    ),
  );
}

class SellerExtraKpi extends StatelessWidget {
  const SellerExtraKpi(this.label, this.value, this.icon, this.width, {super.key});
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF125C9E)),
            const SizedBox(height: 14),
            Text((value ?? 0).toString(), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    ),
  );
}

class SellerExtraEmpty extends StatelessWidget {
  const SellerExtraEmpty(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(children: [
      const Icon(Icons.inbox_outlined, size: 42, color: Colors.black38),
      const SizedBox(height: 10),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
    ]),
  );
}

class SellerExtraSectionTitle extends StatelessWidget {
  const SellerExtraSectionTitle(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: Colors.black54)),
    ],
  );
}
