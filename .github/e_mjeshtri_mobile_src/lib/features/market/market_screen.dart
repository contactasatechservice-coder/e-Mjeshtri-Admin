import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import 'market_repository.dart';
import 'market_vendor_profile_screen.dart';

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


String _marketReturnStatusLabel(String value) {
  switch (value) {
    case 'requested':
      return 'Në pritje të shitësit';
    case 'vendor_approved':
      return 'Pranuar nga shitësi';
    case 'vendor_rejected':
      return 'Refuzuar nga shitësi';
    case 'escalated':
      return 'Në shqyrtim nga Admini';
    case 'admin_approved':
      return 'Aprovuar nga Admini';
    case 'admin_rejected':
      return 'Refuzuar nga Admini';
    case 'received':
      return 'Produkti u pranua';
    case 'refunded':
      return 'Rimbursuar';
    case 'closed':
      return 'Mbyllur';
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
    case 'cancelled':
      return 'Anuluar';
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
  late Future<List<Map<String, dynamic>>> _banners;
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
    _banners = repo.banners(widget.audience);
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

  Future<void> _openOrders() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketOrdersScreen(audience: widget.audience),
      ),
    );
  }

  Future<void> _openCart() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketCartScreen(audience: widget.audience),
      ),
    );
    if (!mounted) return;
    final value = await ref.read(marketRepositoryProvider).cartCount();
    if (mounted) setState(() => _cartCount = value);
  }

  Future<void> _openProduct(Map<String, dynamic> product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketProductScreen(
          productId: product['id'].toString(),
          audience: widget.audience,
        ),
      ),
    );
    if (!mounted) return;
    final value = await ref.read(marketRepositoryProvider).cartCount();
    if (mounted) setState(() => _cartCount = value);
  }

  Future<void> _openVendor(Map<String, dynamic> vendor) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketVendorProfileScreen(
          vendorId: vendor['vendor_id'].toString(),
          audience: widget.audience,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProvider = widget.audience == 'provider';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _reloadAll();
            await Future.wait<dynamic>([_categories, _products, _banners]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      const _EMarketMark(size: 54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'e-Market',
                              style: TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                                letterSpacing: -.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isProvider
                                  ? 'Vegla dhe materiale pune'
                                  : 'Pajisje dhe produkte për shtëpinë',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _MarketHeaderButton(
                        tooltip: 'Porositë',
                        icon: Icons.receipt_long_outlined,
                        onTap: _openOrders,
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _MarketHeaderButton(
                            tooltip: 'Shporta',
                            icon: Icons.shopping_bag_outlined,
                            onTap: _openCart,
                          ),
                          if (_cartCount > 0)
                            Positioned(
                              right: -4,
                              top: -5,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 19),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5484D),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _cartCount > 99 ? '99+' : '$_cartCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0C172033),
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _reloadProducts(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: isProvider
                            ? 'Kërko vegla, materiale ose marka...'
                            : 'Kërko pajisje, produkte ose marka...',
                        hintStyle: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 15,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.blue,
                          size: 28,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_search.text.isNotEmpty)
                              IconButton(
                                onPressed: () {
                                  _search.clear();
                                  _reloadProducts();
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            Container(
                              width: 1,
                              height: 28,
                              color: AppColors.divider,
                            ),
                            IconButton(
                              tooltip: 'Filtro',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Përdor kategoritë për të filtruar produktet.',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.tune_rounded,
                                color: AppColors.blue,
                              ),
                            ),
                          ],
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
                        height: 58,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 58,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _MarketCategoryPill(
                            label: 'Të gjitha',
                            icon: Icons.grid_view_rounded,
                            selected: _categoryId == null,
                            onTap: () {
                              setState(() => _categoryId = null);
                              _reloadProducts();
                            },
                          ),
                          ...categories.map(
                            (category) => _MarketCategoryPill(
                              label: (category['name_sq'] ?? '').toString(),
                              icon: _marketCategoryIcon(
                                (category['icon_key'] ??
                                        category['slug'] ??
                                        '')
                                    .toString(),
                              ),
                              selected:
                                  _categoryId == category['id']?.toString(),
                              onTap: () {
                                setState(
                                  () => _categoryId =
                                      category['id']?.toString(),
                                );
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _banners,
                    builder: (context, snap) {
                      final banners =
                          snap.data ?? const <Map<String, dynamic>>[];
                      if (banners.isEmpty) {
                        return _MarketHeroBanner(isProvider: isProvider);
                      }
                      return _MarketBannerCarousel(
                        banners: banners,
                        isProvider: isProvider,
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _products,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 54, bottom: 120),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 120),
                        child: _MarketStateCard(
                          icon: Icons.cloud_off_rounded,
                          title: 'Produktet nuk u ngarkuan',
                          text: 'Kontrollo lidhjen dhe provo përsëri.',
                          actionLabel: 'Provo përsëri',
                          onAction: _reloadProducts,
                        ),
                      );
                    }

                    final products = snap.data ?? const <Map<String, dynamic>>[];
                    if (products.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                        child: _MarketStateCard(
                          icon: Icons.inventory_2_outlined,
                          title: 'Produkte të reja po shtohen',
                          text: isProvider
                              ? 'Produktet profesionale do të shfaqen sapo bizneset e aprovuara t’i publikojnë.'
                              : 'Produktet për shtëpinë do të shfaqen sapo bizneset e aprovuara t’i publikojnë.',
                        ),
                      );
                    }

                    final discounted = products.where((p) {
                      final current = _marketPriceFor(p, widget.audience);
                      final compare = (p['compare_at_price'] as num?)?.toDouble();
                      return compare != null &&
                          current != null &&
                          compare > current;
                    }).toList();

                    final featured = discounted.isNotEmpty
                        ? discounted
                        : products
                            .where((p) => p['is_featured'] == true)
                            .toList();
                    final displayProducts =
                        featured.isNotEmpty ? featured : products;

                    final vendors = <String, Map<String, dynamic>>{};
                    for (final p in products) {
                      if (p['vendor_verified'] != true) continue;
                      final id = p['vendor_id']?.toString();
                      if (id == null || id.isEmpty) continue;
                      vendors.putIfAbsent(id, () => p);
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 125),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MarketSectionHeading(
                            icon: discounted.isNotEmpty
                                ? Icons.local_fire_department_rounded
                                : Icons.auto_awesome_rounded,
                            iconColor: discounted.isNotEmpty
                                ? AppColors.orange
                                : AppColors.blue,
                            title: discounted.isNotEmpty
                                ? 'Ofertat e ditës'
                                : 'Produkte për ty',
                            trailing:
                                '${displayProducts.length} produkte',
                          ),
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  color: AppColors.success,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Vetëm produkte nga biznese të aprovuara',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: displayProducts.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 11,
                              mainAxisSpacing: 11,
                              childAspectRatio: .67,
                            ),
                            itemBuilder: (context, index) => _ProductCard(
                              product: displayProducts[index],
                              audience: widget.audience,
                              onOpen: () =>
                                  _openProduct(displayProducts[index]),
                            ),
                          ),
                          if (vendors.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const _MarketSectionHeading(
                              icon: Icons.storefront_rounded,
                              iconColor: AppColors.blue,
                              title: 'Dyqane të verifikuara',
                              trailing: 'Biznese të aprovuara',
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 94,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: vendors.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final vendor =
                                      vendors.values.elementAt(index);
                                  return _VerifiedVendorCard(
                                    vendor: vendor,
                                    onTap: () => _openVendor(vendor),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
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

class _EMarketMark extends StatelessWidget {
  const _EMarketMark({this.size = 52});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .29),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF19A7F7),
              Color(0xFF0866DB),
              Color(0xFF063CBF),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24125C9E),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: size * .20,
              left: size * .18,
              right: size * .18,
              child: Container(
                height: size * .18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(size * .08),
                ),
              ),
            ),
            Positioned(
              top: size * .15,
              left: size * .20,
              right: size * .20,
              child: Row(
                children: List.generate(
                  5,
                  (i) => Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: size * .012),
                      height: size * .19,
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? Colors.white
                            : const Color(0xFFA9DDFF),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(size * .06),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: size * .22,
              right: size * .22,
              bottom: size * .17,
              child: Container(
                height: size * .34,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: size * .055,
                  ),
                  borderRadius: BorderRadius.circular(size * .08),
                ),
                child: Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: size * .19,
                ),
              ),
            ),
          ],
        ),
      );
}

class _MarketHeaderButton extends StatelessWidget {
  const _MarketHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.blue.withValues(alpha: .08),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: AppColors.ink, size: 22),
            ),
          ),
        ),
      );
}

class _MarketBannerCarousel extends ConsumerStatefulWidget {
  const _MarketBannerCarousel({
    required this.banners,
    required this.isProvider,
  });

  final List<Map<String, dynamic>> banners;
  final bool isProvider;

  @override
  ConsumerState<_MarketBannerCarousel> createState() =>
      _MarketBannerCarouselState();
}

class _MarketBannerCarouselState
    extends ConsumerState<_MarketBannerCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _MarketBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _index = 0;
      _timer?.cancel();
      _schedule();
    }
  }

  void _schedule() {
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openTarget(String? raw) async {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 156,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == widget.banners.length - 1 ? 0 : 0,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openTarget(
                      banner['target_url']?.toString(),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FutureBuilder<String?>(
                          future: ref
                              .read(marketRepositoryProvider)
                              .signedBannerUrl(
                                banner['image_path']?.toString(),
                              ),
                          builder: (context, snap) {
                            final url = snap.data;
                            if (url == null) {
                              return _MarketHeroBanner(
                                isProvider: widget.isProvider,
                              );
                            }
                            return Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _MarketHeroBanner(
                                isProvider: widget.isProvider,
                              ),
                            );
                          },
                        ),
                        if ((banner['title'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .48),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    banner['title'].toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if ((banner['subtitle'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      banner['subtitle'].toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: .86,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: i == _index ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _index
                      ? AppColors.blue
                      : AppColors.muted.withValues(alpha: .28),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MarketHeroBanner extends StatelessWidget {
  const _MarketHeroBanner({required this.isProvider});
  final bool isProvider;

  @override
  Widget build(BuildContext context) => Container(
        height: 156,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF075AA9),
              Color(0xFF0B65B7),
              Color(0xFF1F86D5),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24125C9E),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -28,
              child: Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 10,
              child: Icon(
                isProvider ? Icons.handyman_rounded : Icons.weekend_rounded,
                color: Colors.white.withValues(alpha: .92),
                size: 92,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 130, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'e-Market',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isProvider
                        ? 'Veglat e duhura për çdo projekt'
                        : 'Produkte cilësore për një shtëpi më të mirë',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isProvider
                        ? 'Materiale dhe pajisje nga biznese të aprovuara.'
                        : 'Pajisje dhe produkte nga shitës të aprovuar.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .86),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MarketCategoryPill extends StatelessWidget {
  const _MarketCategoryPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.blue.withValues(alpha: .12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.blue.withValues(alpha: .12)
                    : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_rounded : icon,
                  size: 18,
                  color: AppColors.blue,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.blue : AppColors.ink,
                    fontSize: 12.5,
                    fontWeight:
                        selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MarketSectionHeading extends StatelessWidget {
  const _MarketSectionHeading({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 19,
              ),
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      );
}

class _MarketStateCard extends StatelessWidget {
  const _MarketStateCard({
    required this.icon,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.blue, size: 38),
            const SizedBox(height: 11),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      );
}

class _VerifiedVendorCard extends ConsumerWidget {
  const _VerifiedVendorCard({
    required this.vendor,
    required this.onTap,
  });

  final Map<String, dynamic> vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: 215,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                FutureBuilder<String?>(
                  future: ref.read(marketRepositoryProvider).signedImageUrl(
                        vendor['vendor_logo_path']?.toString(),
                      ),
                  builder: (context, snap) {
                    final url = snap.data;
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: .07),
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: url == null
                          ? const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.blue,
                            )
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.storefront_rounded,
                                color: AppColors.blue,
                              ),
                            ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              (vendor['vendor_name'] ?? '').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.blue,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (vendor['category_name'] ?? 'e-Market').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      );
}

IconData _marketCategoryIcon(String key) {
  final value = key.toLowerCase();
  if (value.contains('tv') || value.contains('audio')) return Icons.tv_rounded;
  if (value.contains('kuzh') || value.contains('kitchen')) {
    return Icons.soup_kitchen_rounded;
  }
  if (value.contains('smart')) return Icons.home_rounded;
  if (value.contains('elektr')) return Icons.electrical_services_rounded;
  if (value.contains('hidraul') || value.contains('plumb')) {
    return Icons.plumbing_rounded;
  }
  if (value.contains('vegla') || value.contains('tool')) {
    return Icons.handyman_rounded;
  }
  if (value.contains('material')) return Icons.construction_rounded;
  if (value.contains('ngroh') || value.contains('ftoh')) {
    return Icons.ac_unit_rounded;
  }
  return Icons.inventory_2_outlined;
}

double? _marketPriceFor(Map<String, dynamic> product, String audience) {
  final professional = audience == 'provider';
  final raw = professional && product['professional_price'] != null
      ? product['professional_price']
      : product['retail_price'];
  return (raw as num?)?.toDouble();
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
                      leading: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.blue,
                      ),
                      title: Text((p['vendor_name'] ?? '').toString()),
                      subtitle: Text((p['vendor_city'] ?? '').toString()),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MarketVendorProfileScreen(
                              vendorId: p['vendor_id'].toString(),
                              audience: widget.audience,
                            ),
                          ),
                        );
                      },
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
    final price = _marketPriceFor(product, audience) ?? 0;
    final compare = (product['compare_at_price'] as num?)?.toDouble();
    final hasDiscount = compare != null && compare > price && price > 0;
    final discount = hasDiscount
        ? (((compare - price) / compare) * 100).round()
        : 0;
    final rating = (product['rating_avg'] as num?)?.toDouble() ?? 0;
    final ratingCount = (product['rating_count'] as num?)?.toInt() ?? 0;
    final verified = product['vendor_verified'] == true;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
            boxShadow: const [
              BoxShadow(
                color: Color(0x09172033),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FutureBuilder<String?>(
                      future: repo.signedImageUrl(
                        product['primary_image_path']?.toString(),
                      ),
                      builder: (context, snap) {
                        final url = snap.data;
                        return Container(
                          color: const Color(0xFFF5F7FA),
                          alignment: Alignment.center,
                          child: url == null
                              ? const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.blue,
                                  size: 44,
                                )
                              : Image.network(
                                  url,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.inventory_2_outlined,
                                    color: AppColors.blue,
                                    size: 44,
                                  ),
                                ),
                        );
                      },
                    ),
                    if (hasDiscount)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3D45),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '-$discount%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    if (product['is_new'] == true && !hasDiscount)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Text(
                            'E RE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (product['name'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            color: AppColors.muted,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              (product['vendor_name'] ?? '').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.blue,
                              size: 13,
                            ),
                          ],
                        ],
                      ),
                      if (ratingCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.orange,
                              size: 15,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '($ratingCount)',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_marketMoney(price)} ${(product['currency'] ?? 'ALL')}',
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                if (hasDiscount)
                                  Text(
                                    '${_marketMoney(compare)} ${(product['currency'] ?? 'ALL')}',
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 9.5,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _marketMoney(num? value) {
  if (value == null) return '0';
  final n = value.toDouble();
  if (n == n.roundToDouble()) {
    final raw = n.toInt().toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
      out.write(raw[i]);
    }
    return out.toString();
  }
  return n.toStringAsFixed(2);
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
          _error = 'Nuk u ngarkua e-Market. Provo përsëri.';
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


class MarketOrderDetailScreen extends ConsumerStatefulWidget {
  const MarketOrderDetailScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  ConsumerState<MarketOrderDetailScreen> createState() =>
      _MarketOrderDetailScreenState();
}

class _MarketOrderDetailScreenState
    extends ConsumerState<MarketOrderDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;

  static const _cancelReasons = <String>[
    'Nuk më duhet më produkti',
    'E porosita gabimisht',
    'Ndryshova mendje',
    'Adresa ose të dhënat e porosisë janë gabim',
    'Arsye tjetër',
  ];

  static const _returnReasons = <String>[
    'Produkti erdhi i dëmtuar',
    'Produkti nuk përputhet me përshkrimin',
    'Produkti është i gabuar',
    'Produkti nuk funksionon',
    'Arsye tjetër',
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future =
        ref.read(marketRepositoryProvider).orderDetail(widget.orderId);
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    const paid =
        'Kjo porosi është paguar. Anulimi kërkon proces rimbursimi nga shitësi ose Admini.';
    const late =
        'Kjo porosi nuk mund të anulohet më sepse është nisur ose përfunduar.';
    if (raw.contains('Paid orders require refund processing')) return paid;
    if (raw.contains('This order can no longer be cancelled')) return late;
    if (raw.contains('Cancellation reason is required')) {
      return 'Vendos arsyen e anulimit.';
    }
    if (raw.contains('Return window has expired')) {
      return 'Afati i kthimit për këtë porosi ka përfunduar.';
    }
    if (raw.contains('A return request already exists')) {
      return 'Për këtë porosi ekziston tashmë një kërkesë kthimi.';
    }
    if (raw.contains('Return reason is required')) {
      return 'Vendos arsyen e kthimit.';
    }
    if (raw.contains('Delivered order not found')) {
      return 'Kthimi lejohet vetëm për porosi të dorëzuara.';
    }
    return 'Veprimi nuk u krye. Provo përsëri.';
  }

  Future<void> _cancelVendorOrder(
    Map<String, dynamic> vendor,
  ) async {
    String selected = _cancelReasons.first;
    final custom = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Anulo porosinë'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Shitësi: ' +
                      (vendor['vendor_name'] ?? '').toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Arsyeja e anulimit',
                  ),
                  items: _cancelReasons
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selected = value);
                    }
                  },
                ),
                if (selected == 'Arsye tjetër') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: custom,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Shkruaj arsyen',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Pas anulimit, stoku i rezervuar lirohet automatikisht. '
                  'Porosia nuk mund të anulohet pasi të jetë nisur.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Mbyll'),
            ),
            FilledButton(
              onPressed: () {
                final value = selected == 'Arsye tjetër'
                    ? custom.text.trim()
                    : selected;
                if (value.length < 3) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Shkruaj arsyen e anulimit.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text('Po, anuloje'),
            ),
          ],
        ),
      ),
    );

    custom.dispose();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(marketRepositoryProvider).cancelVendorOrder(
            vendorOrderId: vendor['id'].toString(),
            reason: reason,
          );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Porosia u anulua dhe shitësi u njoftua.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Future<void> _requestReturn(
    Map<String, dynamic> vendor,
  ) async {
    String selected = _returnReasons.first;
    final note = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Kërko kthim'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Shitësi: ' + (vendor['vendor_name'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Arsyeja e kthimit',
                  ),
                  items: _returnReasons
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selected = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Shënim për shitësin (opsional)',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Afati i kthimit: ' +
                      (vendor['return_window_days'] ?? 14).toString() +
                      ' ditë nga dorëzimi.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Mbyll'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                dialogContext,
                {
                  'reason': selected,
                  'note': note.text.trim(),
                },
              ),
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('Dërgo kërkesën'),
            ),
          ],
        ),
      ),
    );

    note.dispose();
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(marketRepositoryProvider).requestReturn(
            vendorOrderId: vendor['id'].toString(),
            reason: result['reason'] ?? '',
            note: result['note'],
          );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kërkesa e kthimit iu dërgua shitësit.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detajet e porosisë')),
      body: FutureBuilder<Map<String, dynamic>>(
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
          final order = Map<String, dynamic>.from(
            (data['order'] as Map?) ?? const {},
          );
          final vendors = List<Map<String, dynamic>>.from(
            (data['vendor_orders'] as List?) ?? const [],
          );

          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _future;
            },
            child: ListView(
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
                  final status = (vendor['status'] ?? '').toString();
                  final vendorPaymentStatus =
                      (vendor['vendor_payment_status'] ?? '').toString();
                  final canCancel = const {
                        'pending',
                        'confirmed',
                        'processing',
                      }.contains(status) &&
                      !const {
                        'paid',
                        'partially_refunded',
                        'refunded',
                      }.contains(vendorPaymentStatus);
                  final deliveredAt = DateTime.tryParse(
                    (vendor['delivered_at'] ?? '').toString(),
                  )?.toLocal();
                  final returnWindowDays =
                      (vendor['return_window_days'] as num?)?.toInt() ?? 14;
                  final returnStatus =
                      (vendor['return_status'] ?? '').toString();
                  final returnDeadline = deliveredAt?.add(
                    Duration(days: returnWindowDays),
                  );
                  final canReturn = status == 'delivered' &&
                      (returnStatus.isEmpty ||
                          const {
                            'vendor_rejected',
                            'admin_rejected',
                            'closed',
                          }.contains(returnStatus)) &&
                      (returnDeadline == null ||
                          DateTime.now().isBefore(returnDeadline));
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
                                  _marketOrderStatusLabel(status),
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
                          if (canCancel) ...[
                            const Divider(),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _cancelVendorOrder(vendor),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(
                                    color: AppColors.danger,
                                  ),
                                ),
                                icon: const Icon(Icons.cancel_outlined),
                                label: Text(
                                  vendors.length > 1
                                      ? 'Anulo porosinë nga ky shitës'
                                      : 'Anulo porosinë',
                                ),
                              ),
                            ),
                          ],

                          if (canReturn) ...[
                            const Divider(),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _requestReturn(vendor),
                                icon: const Icon(
                                  Icons.assignment_return_outlined,
                                ),
                                label: const Text('Kërko kthim / rimbursim'),
                              ),
                            ),
                          ],
                          if (returnStatus.isNotEmpty) ...[
                            const Divider(),
                            Text(
                              'Kthimi: ' + _marketReturnStatusLabel(returnStatus),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if ((vendor['return_reason'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty)
                              Text(
                                'Arsyeja: ' +
                                    vendor['return_reason'].toString(),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                ),
                              ),
                          ],
                          if (status == 'cancelled' &&
                              (vendor['cancellation_reason'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                            const Divider(),
                            Text(
                              'Arsyeja e anulimit: ' +
                                  vendor['cancellation_reason'].toString(),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
                                      mode:
                                          LaunchMode.externalApplication,
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
            ),
          );
        },
      ),
    );
  }
}

