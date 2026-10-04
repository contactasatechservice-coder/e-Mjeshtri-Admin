import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/market_seller_repository.dart';

class MarketSellerLoginScreen extends StatefulWidget {
  const MarketSellerLoginScreen({super.key});

  @override
  State<MarketSellerLoginScreen> createState() => _MarketSellerLoginScreenState();
}

class _MarketSellerLoginScreenState extends State<MarketSellerLoginScreen> {
  final _repo = MarketSellerRepository.instance;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.signIn(_email.text, _password.text);
      if (mounted) context.go('/seller');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Hyrja dështoi. Kontrollo email-in dhe fjalëkalimin.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 34, 30, 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 74,
                        child: Image.asset(
                          'assets/branding/e_mjeshtri_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'e-Market Seller',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Menaxho dyqanin, produktet, stokun dhe porositë e tua.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          return value.contains('@') ? null : 'Vendos email të vlefshëm.';
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Fjalëkalimi',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            (v ?? '').isEmpty ? 'Vendos fjalëkalimin.' : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(_loading ? 'Po hyn...' : 'Hyr në Seller Panel'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Përdor të njëjtën llogari që ke në e-Mjeshtri. Nëse nuk je ende shitës, regjistrimi i dyqanit bëhet pasi të hysh.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MarketSellerGateScreen extends StatefulWidget {
  const MarketSellerGateScreen({super.key});

  @override
  State<MarketSellerGateScreen> createState() => _MarketSellerGateScreenState();
}

class _MarketSellerGateScreenState extends State<MarketSellerGateScreen> {
  final _repo = MarketSellerRepository.instance;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _membership;

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
      _membership = await _repo.membership();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Provo përsëri'),
          ),
        ),
      );
    }
    if (_membership == null) {
      return MarketVendorRegistrationScreen(onCreated: _load);
    }

    final vendor = Map<String, dynamic>.from(
      (_membership!['market_vendors'] as Map?) ?? const {},
    );
    final vendorId = _membership!['vendor_id'].toString();
    final status = (vendor['status'] ?? 'pending').toString();

    if (status != 'approved') {
      return MarketVendorStatusScreen(
        vendorId: vendorId,
        vendor: vendor,
        onRefresh: _load,
      );
    }

    return MarketSellerPanel(
      vendorId: vendorId,
      vendor: vendor,
    );
  }
}

class MarketVendorRegistrationScreen extends StatefulWidget {
  const MarketVendorRegistrationScreen({
    super.key,
    required this.onCreated,
  });

  final VoidCallback onCreated;

  @override
  State<MarketVendorRegistrationScreen> createState() =>
      _MarketVendorRegistrationScreenState();
}

class _MarketVendorRegistrationScreenState
    extends State<MarketVendorRegistrationScreen> {
  final _repo = MarketSellerRepository.instance;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _legal = TextEditingController();
  final _tax = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _street = TextEditingController();
  final _postal = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name,
      _legal,
      _tax,
      _email,
      _phone,
      _city,
      _street,
      _postal,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.registerVendor(
        displayName: _name.text,
        legalName: _legal.text,
        taxId: _tax.text,
        email: _email.text,
        phone: _phone.text,
        city: _city.text,
        street: _street.text,
        postalCode: _postal.text,
        description: _description.text,
      );
      widget.onCreated();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Regjistro dyqanin në e-Market'),
        actions: [
          IconButton(
            tooltip: 'Dil',
            onPressed: () async {
              await _repo.signOut();
              if (context.mounted) context.go('/seller/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _SellerIntroCard(
                  icon: Icons.storefront_rounded,
                  title: 'Hap dyqanin tënd',
                  text:
                      'Plotëso të dhënat e biznesit. Admini i e-Mjeshtri do ta kontrollojë përpara se produktet të publikohen.',
                ),
                const SizedBox(height: 18),
                _SellerCard(
                  title: 'Të dhënat e biznesit',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Emri i dyqanit *',
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'E detyrueshme' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _legal,
                        decoration: const InputDecoration(
                          labelText: 'Emri ligjor i biznesit',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tax,
                        decoration: const InputDecoration(
                          labelText: 'NIPT / NUIS',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Telefon',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _city,
                              decoration: const InputDecoration(
                                labelText: 'Qyteti',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _postal,
                              decoration: const InputDecoration(
                                labelText: 'Kodi postar',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _street,
                        decoration: const InputDecoration(
                          labelText: 'Adresa / rruga',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Përshkrim i shkurtër',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      _busy ? 'Duke dërguar...' : 'Dërgo për aprovim',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MarketVendorStatusScreen extends StatefulWidget {
  const MarketVendorStatusScreen({
    super.key,
    required this.vendorId,
    required this.vendor,
    required this.onRefresh,
  });

  final String vendorId;
  final Map<String, dynamic> vendor;
  final VoidCallback onRefresh;

  @override
  State<MarketVendorStatusScreen> createState() =>
      _MarketVendorStatusScreenState();
}

class _MarketVendorStatusScreenState extends State<MarketVendorStatusScreen> {
  final _repo = MarketSellerRepository.instance;
  late Future<List<Map<String, dynamic>>> _documents;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _documents = _repo.vendorDocuments(widget.vendorId);
  }

  void _reloadDocs() {
    setState(() => _documents = _repo.vendorDocuments(widget.vendorId));
  }

  Future<void> _uploadDocument() async {
    final file = await _repo.pickFile(
      accept: 'image/jpeg,image/png,application/pdf',
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      await _repo.uploadVendorDocument(
        vendorId: widget.vendorId,
        documentType: 'business_registration',
        file: file,
      );
      _reloadDocs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.vendor['status'] ?? 'pending').toString();
    final rejected = status == 'rejected';
    final suspended = status == 'suspended';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('e-Market Seller'),
        actions: [
          IconButton(
            tooltip: 'Rifresko',
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Dil',
            onPressed: () async {
              await _repo.signOut();
              if (context.mounted) context.go('/seller/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SellerIntroCard(
                icon: rejected
                    ? Icons.cancel_outlined
                    : suspended
                        ? Icons.pause_circle_outline_rounded
                        : Icons.hourglass_top_rounded,
                title: rejected
                    ? 'Regjistrimi u refuzua'
                    : suspended
                        ? 'Dyqani është pezulluar'
                        : 'Në pritje të aprovimit',
                text: rejected
                    ? ((widget.vendor['rejection_reason'] ?? '')
                            .toString()
                            .trim()
                            .isEmpty
                        ? 'Kontakto Adminin ose plotëso dokumentacionin e kërkuar.'
                        : widget.vendor['rejection_reason'].toString())
                    : suspended
                        ? 'Kontakto Adminin e e-Mjeshtri për të sqaruar statusin.'
                        : 'Admini po kontrollon të dhënat e dyqanit. Mund të ngarkosh dokumentin e biznesit ndërkohë.',
              ),
              const SizedBox(height: 18),
              _SellerCard(
                title: 'Dokumentet',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _documents,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final docs = snap.data ?? const [];
                        if (docs.isEmpty) {
                          return const Text(
                            'Nuk ke ngarkuar ende dokument biznesi.',
                            style: TextStyle(color: Colors.black54),
                          );
                        }
                        return Column(
                          children: docs.map((doc) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.description_outlined),
                              title: Text(
                                (doc['document_type'] ?? 'Dokument').toString(),
                              ),
                              subtitle: Text(
                                'Status: ' + (doc['status'] ?? '').toString(),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _uploadDocument,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(
                        _uploading
                            ? 'Duke ngarkuar...'
                            : 'Ngarko dokument biznesi',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MarketSellerPanel extends StatefulWidget {
  const MarketSellerPanel({
    super.key,
    required this.vendorId,
    required this.vendor,
  });

  final String vendorId;
  final Map<String, dynamic> vendor;

  @override
  State<MarketSellerPanel> createState() => _MarketSellerPanelState();
}

class _MarketSellerPanelState extends State<MarketSellerPanel> {
  int _index = 0;

  static const _labels = [
    'Dashboard',
    'Produktet',
    'Porositë',
    'Profili',
  ];

  static const _icons = [
    Icons.dashboard_rounded,
    Icons.inventory_2_rounded,
    Icons.shopping_bag_rounded,
    Icons.storefront_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      MarketSellerDashboard(vendorId: widget.vendorId),
      MarketSellerProducts(vendorId: widget.vendorId),
      MarketSellerOrders(vendorId: widget.vendorId),
      MarketSellerProfile(
        vendorId: widget.vendorId,
        initialVendor: widget.vendor,
      ),
    ];

    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: wide
          ? null
          : AppBar(
              title: const Text('e-Market Seller'),
              actions: [
                IconButton(
                  tooltip: 'Dil',
                  onPressed: () async {
                    await MarketSellerRepository.instance.signOut();
                    if (context.mounted) context.go('/seller/login');
                  },
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: _SellerNavigation(
                  selected: _index,
                  onSelected: (value) {
                    setState(() => _index = value);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 250,
              child: _SellerNavigation(
                selected: _index,
                onSelected: (value) => setState(() => _index = value),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerNavigation extends StatelessWidget {
  const _SellerNavigation({
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF124E7E),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
            child: Container(
              height: 70,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Image.asset(
                'assets/branding/e_mjeshtri_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const Text(
            'e-Market Seller',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _MarketSellerPanelState._labels.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: ListTile(
                selected: i == selected,
                selectedTileColor: Colors.white.withValues(alpha: .13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Icon(
                  _MarketSellerPanelState._icons[i],
                  color: Colors.white,
                ),
                title: Text(
                  _MarketSellerPanelState._labels[i],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => onSelected(i),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              onPressed: () async {
                await MarketSellerRepository.instance.signOut();
                if (context.mounted) context.go('/seller/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Dil'),
            ),
          ),
        ],
      ),
    );
  }
}

class MarketSellerDashboard extends StatefulWidget {
  const MarketSellerDashboard({super.key, required this.vendorId});
  final String vendorId;

  @override
  State<MarketSellerDashboard> createState() => _MarketSellerDashboardState();
}

class _MarketSellerDashboardState extends State<MarketSellerDashboard> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = MarketSellerRepository.instance.dashboard(widget.vendorId);
  }

  @override
  Widget build(BuildContext context) {
    return _SellerPage(
      title: 'Dashboard',
      subtitle: 'Pamje e përgjithshme e dyqanit në e-Market',
      onRefresh: () => setState(_reload),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return const _SellerEmpty('Dashboard nuk mund të ngarkohej.');
          }
          final data = snap.data!;
          final kpis = Map<String, dynamic>.from(
            (data['kpis'] as Map?) ?? const {},
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final cardWidth = width < 650
                  ? (width - 12) / 2
                  : (width - 36) / 4;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SellerKpi(
                    'Produkte aktive',
                    kpis['products_active'],
                    Icons.inventory_2_rounded,
                    cardWidth,
                  ),
                  _SellerKpi(
                    'Në aprovim',
                    kpis['products_pending'],
                    Icons.hourglass_top_rounded,
                    cardWidth,
                  ),
                  _SellerKpi(
                    'Porosi aktive',
                    kpis['orders_open'],
                    Icons.shopping_bag_rounded,
                    cardWidth,
                  ),
                  _SellerKpi(
                    'Stok i ulët',
                    kpis['low_stock'],
                    Icons.warning_amber_rounded,
                    cardWidth,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class MarketSellerProducts extends StatefulWidget {
  const MarketSellerProducts({super.key, required this.vendorId});
  final String vendorId;

  @override
  State<MarketSellerProducts> createState() => _MarketSellerProductsState();
}

class _MarketSellerProductsState extends State<MarketSellerProducts> {
  final _repo = MarketSellerRepository.instance;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repo.products(widget.vendorId);
  }

  Future<void> _add() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _AddMarketProductDialog(vendorId: widget.vendorId),
    );
    if (created == true && mounted) setState(_reload);
  }

  Future<void> _editStock(Map<String, dynamic> product) async {
    final controller = TextEditingController(
      text: (product['stock_quantity'] ?? 0).toString(),
    );
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stoku • ' + (product['name'] ?? '').toString()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Sasia në stok'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulo'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.pop(context, parsed);
            },
            child: const Text('Ruaj'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value < 0) return;
    await _repo.updateStock(
      productId: product['id'].toString(),
      stockQuantity: value,
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return _SellerPage(
      title: 'Produktet',
      subtitle: 'Menaxho katalogun, çmimet dhe stokun',
      onRefresh: () => setState(_reload),
      trailing: FilledButton.icon(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Shto produkt'),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const _SellerEmpty('Produktet nuk mund të ngarkoheshin.');
          }
          final products = snap.data ?? const [];
          if (products.isEmpty) {
            return const _SellerEmpty(
              'Nuk ke ende produkte. Shto produktin e parë.',
            );
          }
          return Column(
            children: products.map((p) {
              final category = p['market_categories'] is Map
                  ? Map<String, dynamic>.from(p['market_categories'] as Map)
                  : <String, dynamic>{};
              final reserved =
                  (p['reserved_quantity'] as num?)?.toInt() ?? 0;
              final stock = (p['stock_quantity'] as num?)?.toInt() ?? 0;
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.inventory_2_outlined),
                  ),
                  title: Text(
                    (p['name'] ?? '').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    (category['name_sq'] ?? '').toString() +
                        ' • ' +
                        (p['retail_price'] ?? 0).toString() +
                        ' ' +
                        (p['currency'] ?? 'ALL').toString() +
                        ' • stok i lirë ' +
                        (stock - reserved).toString(),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      Chip(label: Text((p['status'] ?? '').toString())),
                      IconButton(
                        tooltip: 'Ndrysho stokun',
                        onPressed: () => _editStock(p),
                        icon: const Icon(Icons.inventory_rounded),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          await _repo.setProductState(
                            p['id'].toString(),
                            value,
                          );
                          if (mounted) setState(_reload);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'inactive',
                            child: Text('Çaktivizo'),
                          ),
                          PopupMenuItem(
                            value: 'archived',
                            child: Text('Arkivo'),
                          ),
                        ],
                      ),
                    ],
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

class _AddMarketProductDialog extends StatefulWidget {
  const _AddMarketProductDialog({required this.vendorId});
  final String vendorId;

  @override
  State<_AddMarketProductDialog> createState() =>
      _AddMarketProductDialogState();
}

class _AddMarketProductDialogState extends State<_AddMarketProductDialog> {
  final _repo = MarketSellerRepository.instance;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _short = TextEditingController();
  final _description = TextEditingController();
  final _retail = TextEditingController();
  final _professional = TextEditingController();
  final _compare = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _lowStock = TextEditingController(text: '3');
  final _warranty = TextEditingController(text: '0');

  late Future<List<Map<String, dynamic>>> _categories;
  String? _categoryId;
  String _audience = 'both';
  html.File? _image;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categories = _repo.categories();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _sku,
      _short,
      _description,
      _retail,
      _professional,
      _compare,
      _stock,
      _lowStock,
      _warranty,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _repo.pickFile();
    if (file != null && mounted) setState(() => _image = file);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null) {
      setState(() => _error = 'Zgjidh kategorinë.');
      return;
    }

    final retail = double.tryParse(_retail.text.trim().replaceAll(',', '.'));
    if (retail == null || retail < 0) {
      setState(() => _error = 'Çmimi është i pavlefshëm.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final productId = await _repo.createProduct(
        vendorId: widget.vendorId,
        categoryId: _categoryId!,
        name: _name.text,
        slug: _repo.slugify(_name.text),
        sku: _sku.text,
        shortDescription: _short.text,
        description: _description.text,
        audience: _audience,
        retailPrice: retail,
        professionalPrice:
            double.tryParse(_professional.text.trim().replaceAll(',', '.')),
        compareAtPrice:
            double.tryParse(_compare.text.trim().replaceAll(',', '.')),
        stockQuantity: int.tryParse(_stock.text.trim()) ?? 0,
        lowStockThreshold: int.tryParse(_lowStock.text.trim()) ?? 3,
        warrantyMonths: int.tryParse(_warranty.text.trim()) ?? 0,
      );

      if (_image != null) {
        await _repo.uploadProductImage(
          vendorId: widget.vendorId,
          productId: productId,
          file: _image!,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Shto produkt në e-Market'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Emri *'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'E detyrueshme' : null,
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categories,
                  builder: (context, snap) {
                    final items = snap.data ?? const [];
                    return DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategoria *',
                      ),
                      items: items
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id'].toString(),
                              child: Text((c['name_sq'] ?? '').toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  decoration: const InputDecoration(
                    labelText: 'Kujt i shfaqet',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'citizen',
                      child: Text('Vetëm Qytetarëve'),
                    ),
                    DropdownMenuItem(
                      value: 'provider',
                      child: Text('Vetëm Mjeshtrave'),
                    ),
                    DropdownMenuItem(
                      value: 'both',
                      child: Text('Qytetar + Mjeshtër'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _audience = v ?? 'both'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sku,
                  decoration: const InputDecoration(labelText: 'SKU / Kodi'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _short,
                  decoration: const InputDecoration(
                    labelText: 'Përshkrim i shkurtër',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Përshkrimi i plotë',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _retail,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Çmimi Qytetar *',
                          suffixText: 'ALL',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _professional,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Çmimi Mjeshtër',
                          suffixText: 'ALL',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stoku',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lowStock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Alarm stok i ulët',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _warranty,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Garancia (muaj)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _image == null
                        ? 'Zgjidh foton kryesore'
                        : 'Foto: ' + _image!.name,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Produkti do të kalojë në aprovim nga Admini përpara publikimit, përveç rasteve kur dyqani ka auto-aprovim.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Anulo'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Duke ruajtur...' : 'Ruaj produktin'),
        ),
      ],
    );
  }
}

class MarketSellerOrders extends StatefulWidget {
  const MarketSellerOrders({super.key, required this.vendorId});
  final String vendorId;

  @override
  State<MarketSellerOrders> createState() => _MarketSellerOrdersState();
}

class _MarketSellerOrdersState extends State<MarketSellerOrders> {
  final _repo = MarketSellerRepository.instance;
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repo.vendorOrders(widget.vendorId);
  }

  Future<void> _action(Map<String, dynamic> order, String action) async {
    String? trackingCode;
    String? trackingUrl;

    if (action == 'ship') {
      final code = TextEditingController();
      final url = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dërgo porosinë'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                decoration: const InputDecoration(
                  labelText: 'Kodi i gjurmimit',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: url,
                decoration: const InputDecoration(
                  labelText: 'Linku i gjurmimit',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anulo'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Shëno si dërguar'),
            ),
          ],
        ),
      );
      if (ok != true) {
        code.dispose();
        url.dispose();
        return;
      }
      trackingCode = code.text;
      trackingUrl = url.text;
      code.dispose();
      url.dispose();
    }

    setState(() => _busy = true);
    try {
      await _repo.orderAction(
        vendorId: widget.vendorId,
        vendorOrderId: order['id'].toString(),
        action: action,
        trackingCode: trackingCode,
        trackingUrl: trackingUrl,
      );
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SellerPage(
      title: 'Porositë',
      subtitle: 'Porositë që përmbajnë produkte të dyqanit tënd',
      onRefresh: () => setState(_reload),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const _SellerEmpty('Porositë nuk mund të ngarkoheshin.');
          }
          final orders = snap.data ?? const [];
          if (orders.isEmpty) {
            return const _SellerEmpty('Nuk ka ende porosi.');
          }
          return Column(
            children: orders.map((o) {
              final status = (o['status'] ?? '').toString();
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (o['vendor_order_number'] ?? '').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Chip(label: Text(status)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (o['delivery_name'] ?? '').toString() +
                            ' • ' +
                            (o['delivery_city'] ?? '').toString(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (o['total'] ?? 0).toString() +
                            ' ' +
                            (o['currency'] ?? 'ALL').toString(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status == 'pending')
                            FilledButton(
                              onPressed:
                                  _busy ? null : () => _action(o, 'confirm'),
                              child: const Text('Konfirmo'),
                            ),
                          if (status == 'pending' || status == 'confirmed')
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _action(o, 'processing'),
                              child: const Text('Po përgatitet'),
                            ),
                          if (status == 'confirmed' || status == 'processing')
                            FilledButton.icon(
                              onPressed:
                                  _busy ? null : () => _action(o, 'ship'),
                              icon: const Icon(Icons.local_shipping_outlined),
                              label: const Text('Dërgo'),
                            ),
                          if (status == 'shipped')
                            FilledButton(
                              onPressed:
                                  _busy ? null : () => _action(o, 'deliver'),
                              child: const Text('U dorëzua'),
                            ),
                          if (const [
                            'pending',
                            'confirmed',
                            'processing',
                          ].contains(status))
                            TextButton(
                              onPressed:
                                  _busy ? null : () => _action(o, 'cancel'),
                              child: const Text('Anulo'),
                            ),
                        ],
                      ),
                    ],
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

class MarketSellerProfile extends StatefulWidget {
  const MarketSellerProfile({
    super.key,
    required this.vendorId,
    required this.initialVendor,
  });

  final String vendorId;
  final Map<String, dynamic> initialVendor;

  @override
  State<MarketSellerProfile> createState() => _MarketSellerProfileState();
}

class _MarketSellerProfileState extends State<MarketSellerProfile> {
  final _repo = MarketSellerRepository.instance;
  late final TextEditingController _name;
  late final TextEditingController _legal;
  late final TextEditingController _tax;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _description;
  late final TextEditingController _street;
  late final TextEditingController _city;
  late final TextEditingController _postal;
  late final TextEditingController _deliveryFee;
  late final TextEditingController _freeOver;
  late final TextEditingController _returnDays;
  late final TextEditingController _bankName;
  late final TextEditingController _bankAccountName;
  late final TextEditingController _bankIban;
  late final TextEditingController _bankNote;

  bool _delivery = true;
  bool _pickup = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final v = widget.initialVendor;
    _name = TextEditingController(text: (v['display_name'] ?? '').toString());
    _legal = TextEditingController(text: (v['legal_name'] ?? '').toString());
    _tax = TextEditingController(text: (v['tax_id'] ?? '').toString());
    _email = TextEditingController(text: (v['email'] ?? '').toString());
    _phone = TextEditingController(text: (v['phone'] ?? '').toString());
    _description =
        TextEditingController(text: (v['description'] ?? '').toString());
    _street = TextEditingController(text: (v['street'] ?? '').toString());
    _city = TextEditingController(text: (v['city'] ?? '').toString());
    _postal = TextEditingController(text: (v['postal_code'] ?? '').toString());
    _deliveryFee = TextEditingController(
      text: (v['flat_delivery_fee'] ?? 0).toString(),
    );
    _freeOver = TextEditingController(
      text: (v['free_delivery_over'] ?? '').toString(),
    );
    _returnDays = TextEditingController(
      text: (v['return_window_days'] ?? 14).toString(),
    );
    _bankName = TextEditingController(
      text: (v['bank_name'] ?? '').toString(),
    );
    _bankAccountName = TextEditingController(
      text: (v['bank_account_name'] ?? '').toString(),
    );
    _bankIban = TextEditingController(
      text: (v['bank_iban'] ?? '').toString(),
    );
    _bankNote = TextEditingController(
      text: (v['bank_note'] ?? '').toString(),
    );
    _delivery = v['delivery_enabled'] != false;
    _pickup = v['pickup_enabled'] == true;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _legal,
      _tax,
      _email,
      _phone,
      _description,
      _street,
      _city,
      _postal,
      _deliveryFee,
      _freeOver,
      _returnDays,
      _bankName,
      _bankAccountName,
      _bankIban,
      _bankNote,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await _repo.updateVendorProfile(
        vendorId: widget.vendorId,
        displayName: _name.text,
        legalName: _legal.text,
        taxId: _tax.text,
        email: _email.text,
        phone: _phone.text,
        description: _description.text,
        street: _street.text,
        city: _city.text,
        postalCode: _postal.text,
        deliveryEnabled: _delivery,
        pickupEnabled: _pickup,
        flatDeliveryFee:
            double.tryParse(_deliveryFee.text.replaceAll(',', '.')) ?? 0,
        freeDeliveryOver:
            double.tryParse(_freeOver.text.replaceAll(',', '.')),
        returnWindowDays: int.tryParse(_returnDays.text) ?? 14,
        bankName: _bankName.text,
        bankAccountName: _bankAccountName.text,
        bankIban: _bankIban.text,
        bankNote: _bankNote.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profili i dyqanit u ruajt.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SellerPage(
      title: 'Profili i dyqanit',
      subtitle: 'Të dhënat publike, transporti dhe politika e kthimit',
      child: _SellerCard(
        title: 'Cilësimet e dyqanit',
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Emri i dyqanit'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _legal,
              decoration: const InputDecoration(labelText: 'Emri ligjor'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tax,
              decoration: const InputDecoration(labelText: 'NIPT / NUIS'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Përshkrimi'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _street,
              decoration: const InputDecoration(labelText: 'Adresa'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'Qyteti'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _postal,
                    decoration: const InputDecoration(labelText: 'Kodi postar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _delivery,
              onChanged: (v) => setState(() => _delivery = v),
              title: const Text('Dërgesë në adresë'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _pickup,
              onChanged: (v) => setState(() => _pickup = v),
              title: const Text('Marrje në dyqan'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _deliveryFee,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tarifa e transportit',
                      suffixText: 'ALL',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _freeOver,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Falas mbi',
                      suffixText: 'ALL',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _returnDays,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Afati kthimit',
                      suffixText: 'ditë',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Divider(),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Të dhënat bankare',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Përdoren vetëm kur blerësi zgjedh transfertë bankare.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bankName,
                    decoration: const InputDecoration(labelText: 'Banka'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _bankAccountName,
                    decoration: const InputDecoration(
                      labelText: 'Emri i përfituesit',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bankIban,
              decoration: const InputDecoration(labelText: 'IBAN'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bankNote,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Shënim për pagesën',
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(_busy ? 'Duke ruajtur...' : 'Ruaj ndryshimet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerPage extends StatelessWidget {
  const _SellerPage({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onRefresh,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onRefresh;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Rifresko',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _SellerIntroCard extends StatelessWidget {
  const _SellerIntroCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FC),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white,
              child: Icon(icon, color: const Color(0xFF125C9E)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );
}

class _SellerKpi extends StatelessWidget {
  const _SellerKpi(
    this.label,
    this.value,
    this.icon,
    this.width,
  );

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
                const SizedBox(height: 15),
                Text(
                  (value ?? 0).toString(),
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SellerEmpty extends StatelessWidget {
  const _SellerEmpty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 42,
              color: Colors.black38,
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
}
