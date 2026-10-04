import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import 'market_repository.dart';

String _marketOrderStatusLabel(String value) {
  switch (value) {
    case 'pending':
      return 'Në pritje';
    case 'confirmed':
      return 'Konfirmuar';
    case 'processing':
      return 'Po përgatitet';
    case 'partially_shipped':
      return 'Dërguar pjesërisht';
    case 'shipped':
      return 'U nis';
    case 'delivered':
      return 'U dorëzua';
    case 'cancelled':
      return 'U anulua';
    case 'partially_returned':
      return 'Kthyer pjesërisht';
    case 'returned':
      return 'U kthye';
    case 'refunded':
      return 'U rimbursua';
    default:
      return value;
  }
}

String _marketPaymentMethodLabel(String value) {
  switch (value) {
    case 'cash_on_delivery':
      return 'Pagesë në dorëzim';
    case 'bank_transfer':
      return 'Transfertë bankare';
    case 'card':
      return 'Kartë';
    default:
      return value;
  }
}

String _marketPaymentStatusLabel(String value) {
  switch (value) {
    case 'pending':
      return 'Në pritje';
    case 'awaiting_confirmation':
      return 'Pret konfirmim';
    case 'paid':
      return 'Paguar';
    case 'partially_refunded':
      return 'Rimbursuar pjesërisht';
    case 'refunded':
      return 'Rimbursuar';
    case 'failed':
      return 'Dështoi';
    default:
      return value;
  }
}


class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({
    super.key,
    required this.audience,
  });

  final String audience;

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final _search = TextEditingController();
  String? _categoryId;
  late Future<List<Map<String, dynamic>>> _categories;
  late Future<List<Map<String, dynamic>>> _products;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reloadAll() {
    final repo = ref.read(marketRepositoryProvider);
    _categories = repo.categories(widget.audience);
    _products = repo.catalog(
      audience: widget.audience,
      query: _search.text,
      categoryId: _categoryId,
    );
    repo.cartCount().then((value) {
      if (mounted) setState(() => _cartCount = value);
    });
  }

  void _reloadProducts() {
    setState(() {
      _products = ref.read(marketRepositoryProvider).catalog(
        audience: widget.audience,
        query: _search.text,
        categoryId: _categoryId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isProvider = widget.audience == 'provider';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _reloadAll();
            await _products;
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'e-Market',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              isProvider
                                  ? 'Vegla pune dhe materiale profesionale'
                                  : 'Pajisje dhe produkte për shtëpinë',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Porositë e e-Market',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MarketOrdersScreen(
                                audience: widget.audience,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_outlined),
                      ),
                      const SizedBox(width: 6),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Shporta',
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MarketCartScreen(
                                    audience: widget.audience,
                                  ),
                                ),
                              );
                              if (mounted) {
                                final value = await ref
                                    .read(marketRepositoryProvider)
                                    .cartCount();
                                if (mounted) setState(() => _cartCount = value);
                              }
                            },
                            icon: const Icon(Icons.shopping_bag_outlined),
                          ),
                          if (_cartCount > 0)
                            Positioned(
                              right: -2,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.orange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _cartCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _reloadProducts(),
                    decoration: InputDecoration(
                      hintText: isProvider
                          ? 'Kërko vegla, materiale ose marka...'
                          : 'Kërko pajisje, produkte ose marka...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.blue,
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                _reloadProducts();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categories,
                  builder: (context, snap) {
                    final categories = snap.data ?? const [];
                    if (snap.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 55,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    return SizedBox(
                      height: 54,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryChip(
                            label: 'Të gjitha',
                            selected: _categoryId == null,
                            onTap: () {
                              _categoryId = null;
                              _reloadProducts();
                            },
                          ),
                          ...categories.map(
                            (c) => _CategoryChip(
                              label: (c['name_sq'] ?? '').toString(),
                              selected: _categoryId == c['id']?.toString(),
                              onTap: () {
                                _categoryId = c['id']?.toString();
                                _reloadProducts();
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _products,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: FilledButton.icon(
                              onPressed: _reloadProducts,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Provo përsëri'),
                            ),
                          ),
                        ),
                      );
                    }

                    final products = snap.data ?? const [];
                    if (products.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.only(top: 30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 54,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.storefront_outlined,
                                color: AppColors.blue,
                                size: 48,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'e-Market po përgatitet',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isProvider
                                    ? 'Produktet profesionale do të shfaqen sapo shitësit e aprovuar t’i publikojnë.'
                                    : 'Produktet për shtëpinë do të shfaqen sapo shitësit e aprovuar t’i publikojnë.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ProductCard(
                          product: products[index],
                          audience: widget.audience,
                          onOpen: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MarketProductScreen(
                                  productId: products[index]['id'].toString(),
                                  audience: widget.audience,
                                ),
                              ),
                            );
                            if (mounted) {
                              ref.read(marketRepositoryProvider).cartCount().then((value) {
                                if (mounted) setState(() => _cartCount = value);
                              });
                            }
                          },
                        ),
                        childCount: products.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: .70,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MarketProductScreen extends ConsumerStatefulWidget {
  const MarketProductScreen({
    super.key,
    required this.productId,
    required this.audience,
  });

  final String productId;
  final String audience;

  @override
  ConsumerState<MarketProductScreen> createState() => _MarketProductScreenState();
}

class _MarketProductScreenState extends ConsumerState<MarketProductScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _favorite = false;
  bool _busy = false;
  String? _variantId;

  @override
  void initState() {
    super.initState();
    _future = ref.read(marketRepositoryProvider).product(widget.productId);
    ref.read(marketRepositoryProvider).isFavorite(widget.productId).then((value) {
      if (mounted) setState(() => _favorite = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(marketRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produkti'),
        actions: [
          IconButton(
            tooltip: 'Të preferuarat',
            onPressed: () async {
              final next = !_favorite;
              setState(() => _favorite = next);
              try {
                await repo.setFavorite(widget.productId, next);
              } catch (_) {
                if (mounted) setState(() => _favorite = !next);
              }
            },
            icon: Icon(
              _favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _favorite ? AppColors.danger : null,
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return const Center(child: Text('Produkti nuk mund të ngarkohej.'));
          }

          final p = snap.data!;
          final media = List<Map<String, dynamic>>.from((p['media'] as List?) ?? const []);
          final variants = List<Map<String, dynamic>>.from((p['variants'] as List?) ?? const []);
          final attrs = List<Map<String, dynamic>>.from((p['attributes'] as List?) ?? const []);
          final professional = widget.audience == 'provider';
          dynamic price = professional && p['professional_price'] != null
              ? p['professional_price']
              : p['retail_price'];

          if (_variantId != null) {
            Map<String, dynamic>? variant;
            for (final item in variants) {
              if (item['id']?.toString() == _variantId) {
                variant = item;
                break;
              }
            }
            if (variant != null) {
              final candidate = professional && variant['professional_price'] != null
                  ? variant['professional_price']
                  : variant['retail_price'];
              if (candidate != null) price = candidate;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              _ProductHero(
                media: media,
                fallbackName: (p['name'] ?? '').toString(),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      (p['name'] ?? '').toString(),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  if (p['vendor_verified'] == true)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 3),
                      child: Icon(
                        Icons.verified_rounded,
                        color: AppColors.blue,
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                (p['vendor_name'] ?? '').toString(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                (price ?? 0).toString() + ' ' + (p['currency'] ?? 'ALL').toString(),
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (professional && p['professional_price'] != null)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Çmim profesional për Mjeshtrin',
                    style: TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              if (variants.isNotEmpty) ...[
                const Text(
                  'Zgjidh variantin',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: variants.map((v) {
                    final id = v['id'].toString();
                    return ChoiceChip(
                      label: Text((v['name'] ?? '').toString()),
                      selected: _variantId == id,
                      onSelected: (_) => setState(() => _variantId = id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
              ],
              if ((p['description'] ?? '').toString().trim().isNotEmpty) ...[
                const Text(
                  'Përshkrimi',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 8),
                Text(
                  p['description'].toString(),
                  style: const TextStyle(height: 1.45),
                ),
                const SizedBox(height: 18),
              ],
              if (attrs.isNotEmpty) ...[
                const Text(
                  'Specifikimet',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  child: Column(
                    children: attrs.map((a) => ListTile(
                      dense: true,
                      title: Text((a['name'] ?? '').toString()),
                      trailing: Text(
                        (a['value'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Card(
                elevation: 0,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storefront_rounded, color: AppColors.blue),
                      title: Text((p['vendor_name'] ?? '').toString()),
                      subtitle: Text((p['vendor_city'] ?? '').toString()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined, color: AppColors.blue),
                      title: const Text('Stoku'),
                      trailing: Text(
                        (((p['stock_quantity'] as num?)?.toInt() ?? 0) -
                                    ((p['reserved_quantity'] as num?)?.toInt() ?? 0) >
                                0)
                            ? 'Në stok'
                            : 'Jashtë stokut',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if ((p['warranty_months'] as num?)?.toInt() != 0)
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined, color: AppColors.blue),
                        title: const Text('Garancia'),
                        trailing: Text(
                          (p['warranty_months'] ?? 0).toString() + ' muaj',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
              ),
              if (p['installation_category_id'] != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ky produkt mund të lidhet me kërkesë për montim nga Mjeshtri.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.handyman_outlined),
                  label: const Text('Kërko Mjeshtër për instalim'),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (variants.isNotEmpty && _variantId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Zgjidh variantin e produktit.')),
                            );
                            return;
                          }
                          setState(() => _busy = true);
                          try {
                            await repo.addToCart(
                              productId: widget.productId,
                              variantId: _variantId,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Produkti u shtua në shportë.')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(_busy ? 'Duke shtuar...' : 'Shto në shportë'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({
    required this.product,
    required this.audience,
    required this.onOpen,
  });

  final Map<String, dynamic> product;
  final String audience;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(marketRepositoryProvider);
    final professional = audience == 'provider';
    final price = professional && product['professional_price'] != null
        ? product['professional_price']
        : product['retail_price'];

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FutureBuilder<String?>(
                  future: repo.signedImageUrl(product['primary_image_path']?.toString()),
                  builder: (context, snap) {
                    final url = snap.data;
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F6FB),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: url == null
                          ? const Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.blue,
                              size: 44,
                            )
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.blue,
                                size: 44,
                              ),
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                (product['name'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                (product['vendor_name'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                (price ?? 0).toString() +
                    ' ' +
                    (product['currency'] ?? 'ALL').toString(),
                style: const TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductHero extends ConsumerWidget {
  const _ProductHero({
    required this.media,
    required this.fallbackName,
  });

  final List<Map<String, dynamic>> media;
  final String fallbackName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = media.isEmpty ? null : media.first['storage_path']?.toString();
    return AspectRatio(
      aspectRatio: 1.2,
      child: FutureBuilder<String?>(
        future: ref.read(marketRepositoryProvider).signedImageUrl(path),
        builder: (context, snap) {
          final url = snap.data;
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FB),
              borderRadius: BorderRadius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: url == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.blue,
                        size: 64,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        fallbackName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : Image.network(
                    url,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
          );
        },
      ),
    );
  }
}


class MarketCartScreen extends ConsumerStatefulWidget {
  const MarketCartScreen({super.key, required this.audience});
  final String audience;

  @override
  ConsumerState<MarketCartScreen> createState() => _MarketCartScreenState();
}

class _MarketCartScreenState extends ConsumerState<MarketCartScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(marketRepositoryProvider).cartSnapshot(widget.audience);
  }

  Future<void> _change(String id, int quantity) async {
    setState(() => _busy = true);
    try {
      await ref.read(marketRepositoryProvider).setCartItemQuantity(id, quantity);
      if (mounted) setState(_reload);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shporta e e-Market')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => setState(_reload),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Provo përsëri'),
              ),
            );
          }

          final data = snap.data ?? const {};
          final items = List<Map<String, dynamic>>.from(
            (data['items'] as List?) ?? const [],
          );

          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 58,
                      color: AppColors.blue,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Shporta është bosh',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Shto produkte nga e-Market për të vazhduar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
                    final lineTotal = unitPrice * quantity;
                    return Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F6FB),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (item['name'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if ((item['variant_name'] ?? '').toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        (item['variant_name'] ?? '').toString(),
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (item['vendor_name'] ?? '').toString(),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    lineTotal.toStringAsFixed(0) +
                                        ' ' +
                                        (item['currency'] ?? 'ALL').toString(),
                                    style: const TextStyle(
                                      color: AppColors.blue,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  tooltip: 'Shto',
                                  onPressed: _busy
                                      ? null
                                      : () => _change(
                                            item['cart_item_id'].toString(),
                                            quantity + 1,
                                          ),
                                  icon: const Icon(Icons.add_circle_outline_rounded),
                                ),
                                Text(
                                  quantity.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                IconButton(
                                  tooltip: quantity == 1 ? 'Hiq' : 'Pakëso',
                                  onPressed: _busy
                                      ? null
                                      : () => _change(
                                            item['cart_item_id'].toString(),
                                            quantity - 1,
                                          ),
                                  icon: Icon(
                                    quantity == 1
                                        ? Icons.delete_outline_rounded
                                        : Icons.remove_circle_outline_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE9EDF4)),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Nëntotali',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            (data['subtotal'] ?? 0).toString() + ' ALL',
                            style: const TextStyle(
                              fontSize: 20,
                              color: AppColors.blue,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Transporti llogaritet veçmas për çdo shitës në checkout.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final completed =
                                      await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => MarketCheckoutScreen(
                                        audience: widget.audience,
                                      ),
                                    ),
                                  );
                                  if (completed == true && mounted) {
                                    setState(_reload);
                                  }
                                },
                          child: const Text('Vazhdo me porosinë'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MarketCheckoutScreen extends ConsumerStatefulWidget {
  const MarketCheckoutScreen({super.key, required this.audience});
  final String audience;

  @override
  ConsumerState<MarketCheckoutScreen> createState() =>
      _MarketCheckoutScreenState();
}

class _MarketCheckoutScreenState extends ConsumerState<MarketCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _postal = TextEditingController();
  final _note = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String _payment = 'cash_on_delivery';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    try {
      final raw = await ref.read(marketRepositoryProvider).checkoutDefaults();
      final profile = Map<String, dynamic>.from(
        (raw['profile'] as Map?) ?? const {},
      );
      final address = raw['address'] is Map
          ? Map<String, dynamic>.from(raw['address'] as Map)
          : <String, dynamic>{};

      _name.text = (
        (profile['first_name'] ?? '').toString() +
        ' ' +
        (profile['last_name'] ?? '').toString()
      ).trim();
      _phone.text = (profile['phone'] ?? '').toString();
      final number = (address['street_number'] ?? '').toString().trim();
      _street.text = (
        (address['street'] ?? '').toString() +
        (number.isEmpty ? '' : ' ' + number)
      ).trim();
      _city.text = (address['city'] ?? '').toString();
      _postal.text = (address['postal_code'] ?? '').toString();
    } catch (_) {
      // User can fill the form manually.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _street.dispose();
    _city.dispose();
    _postal.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(marketRepositoryProvider).checkout(
        audience: widget.audience,
        paymentMethod: _payment,
        deliveryName: _name.text,
        deliveryPhone: _phone.text,
        deliveryStreet: _street.text,
        deliveryCity: _city.text,
        deliveryPostalCode: _postal.text,
        buyerNote: _note.text,
      );

      if (!mounted) return;
      final number = (result['order_number'] ?? '').toString();
      final bankInstructions = List<Map<String, dynamic>>.from(
        (result['bank_instructions'] as List?) ?? const [],
      );
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 46,
          ),
          title: const Text('Porosia u krijua'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    number.isEmpty
                        ? 'Porosia jote u regjistrua me sukses.'
                        : 'Numri i porosisë: ' + number,
                    textAlign: TextAlign.center,
                  ),
                  if (bankInstructions.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Transfertat bankare',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    ...bankInstructions.map(
                      (bank) => Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (bank['vendor_name'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (bank['amount'] ?? 0).toString() +
                                    ' ' +
                                    (bank['currency'] ?? 'ALL').toString(),
                              ),
                              if ((bank['bank_name'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty)
                                Text('Banka: ' + bank['bank_name'].toString()),
                              if ((bank['account_name'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty)
                                Text(
                                  'Përfituesi: ' +
                                      bank['account_name'].toString(),
                                ),
                              Text(
                                'IBAN: ' + (bank['iban'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Referenca: ' +
                                    (bank['vendor_order_number'] ?? '')
                                        .toString(),
                              ),
                              if ((bank['note'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty)
                                Text(bank['note'].toString()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Në rregull'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmo porosinë')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
                children: [
                  const Text(
                    'Adresa e dorëzimit',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Emri dhe mbiemri'),
                    validator: (v) => v == null || v.trim().isEmpty ? '*' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefoni'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _street,
                    decoration: const InputDecoration(labelText: 'Rruga / adresa'),
                    validator: (v) => v == null || v.trim().isEmpty ? '*' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _city,
                          decoration: const InputDecoration(labelText: 'Qyteti'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? '*' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _postal,
                          decoration: const InputDecoration(labelText: 'Kodi postar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Pagesa',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    value: 'cash_on_delivery',
                    groupValue: _payment,
                    onChanged: (v) => setState(() => _payment = v!),
                    title: const Text('Pagesë në dorëzim'),
                    subtitle: const Text('Pagesa bëhet kur merr produktin.'),
                  ),
                  RadioListTile<String>(
                    value: 'bank_transfer',
                    groupValue: _payment,
                    onChanged: (v) => setState(() => _payment = v!),
                    title: const Text('Transfertë bankare'),
                    subtitle: const Text('Pagesa regjistrohet për shitësin përkatës.'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Shënim për porosinë',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: const Icon(Icons.lock_outline_rounded),
                      label: Text(
                        _busy ? 'Duke konfirmuar...' : 'Konfirmo porosinë',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class MarketOrdersScreen extends ConsumerWidget {
  const MarketOrdersScreen({super.key, required this.audience});
  final String audience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Porositë e e-Market')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(marketRepositoryProvider).orders(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text('Porositë nuk mund të ngarkoheshin.'));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nuk ke ende porosi nga e-Market.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final order = items[index];
              final subtitle = (order['status'] ?? '').toString() +
                  ' • ' +
                  (order['item_count'] ?? 0).toString() +
                  ' produkte • ' +
                  (order['vendor_count'] ?? 0).toString() +
                  ' shitës';
              return Card(
                elevation: 0,
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MarketOrderDetailScreen(
                          orderId: order['id'].toString(),
                        ),
                      ),
                    );
                  },
                  leading: const CircleAvatar(
                    child: Icon(Icons.shopping_bag_outlined),
                  ),
                  title: Text(
                    (order['order_number'] ?? '').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (order['grand_total'] ?? 0).toString() +
                            ' ' +
                            (order['currency'] ?? 'ALL').toString(),
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


class MarketOrderDetailScreen extends ConsumerWidget {
  const MarketOrderDetailScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detajet e porosisë')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.read(marketRepositoryProvider).orderDetail(orderId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return const Center(
              child: Text('Porosia nuk mund të ngarkohej.'),
            );
          }

          final data = snap.data!;
          final order = Map<String, dynamic>.from(
            (data['order'] as Map?) ?? const {},
          );
          final vendors = List<Map<String, dynamic>>.from(
            (data['vendor_orders'] as List?) ?? const [],
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (order['order_number'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Status: ' +
                            _marketOrderStatusLabel(
                              (order['status'] ?? '').toString(),
                            ),
                      ),
                      Text(
                        'Pagesa: ' +
                            _marketPaymentMethodLabel(
                              (order['payment_method'] ?? '').toString(),
                            ) +
                            ' • ' +
                            _marketPaymentStatusLabel(
                              (order['payment_status'] ?? '').toString(),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (order['grand_total'] ?? 0).toString() +
                            ' ' +
                            (order['currency'] ?? 'ALL').toString(),
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ...vendors.map((vendor) {
                final items = List<Map<String, dynamic>>.from(
                  (vendor['items'] as List?) ?? const [],
                );
                final trackingCode =
                    (vendor['tracking_code'] ?? '').toString().trim();
                final trackingUrl =
                    (vendor['tracking_url'] ?? '').toString().trim();
                final trackingUri = Uri.tryParse(trackingUrl);
                final canOpenTracking = trackingUri != null &&
                    (trackingUri.scheme == 'http' ||
                        trackingUri.scheme == 'https') &&
                    trackingUri.host.isNotEmpty;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (vendor['vendor_name'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                _marketOrderStatusLabel(
                                  (vendor['status'] ?? '').toString(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...items.map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              (item['product_name'] ?? '').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Sasia: ' +
                                  (item['quantity'] ?? 0).toString(),
                            ),
                            trailing: Text(
                              (item['line_total'] ?? 0).toString() +
                                  ' ' +
                                  (order['currency'] ?? 'ALL').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        if (trackingCode.isNotEmpty ||
                            canOpenTracking) ...[
                          const Divider(),
                          if (trackingCode.isNotEmpty)
                            Text(
                              'Kodi i gjurmimit: ' + trackingCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (canOpenTracking) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await launchUrl(
                                    trackingUri!,
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                icon: const Icon(
                                  Icons.local_shipping_outlined,
                                ),
                                label: const Text('Gjurmo porosinë'),
                              ),
                            ),
                          ],
                        ],
                        if ((vendor['bank_iban'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                          const Divider(),
                          const Text(
                            'Transferta bankare',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Banka: ' +
                                (vendor['bank_name'] ?? '').toString(),
                          ),
                          Text(
                            'Përfituesi: ' +
                                (vendor['bank_account_name'] ?? '')
                                    .toString(),
                          ),
                          SelectableText(
                            'IBAN: ' +
                                (vendor['bank_iban'] ?? '').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Referenca: ' +
                                (vendor['vendor_order_number'] ?? '')
                                    .toString(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
