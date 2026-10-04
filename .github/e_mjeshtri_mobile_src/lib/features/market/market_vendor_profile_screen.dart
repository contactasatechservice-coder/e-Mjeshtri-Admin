import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'market_repository.dart';
import 'market_screen.dart';

class MarketVendorProfileScreen extends ConsumerStatefulWidget {
  const MarketVendorProfileScreen({
    super.key,
    required this.vendorId,
    required this.audience,
  });

  final String vendorId;
  final String audience;

  @override
  ConsumerState<MarketVendorProfileScreen> createState() =>
      _MarketVendorProfileScreenState();
}

class _MarketVendorProfileScreenState
    extends ConsumerState<MarketVendorProfileScreen> {
  late Future<Map<String, dynamic>> _future;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _future = ref.read(marketRepositoryProvider).vendorProfile(
          vendorId: widget.vendorId,
          audience: widget.audience,
        );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(marketRepositoryProvider);
    final professional = widget.audience == 'provider';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Dyqani')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return const Center(child: Text('Profili i dyqanit nuk u ngarkua.'));
          }

          final data = snap.data!;
          final vendor = Map<String, dynamic>.from(
            (data['vendor'] as Map?) ?? const {},
          );
          final categories = List<Map<String, dynamic>>.from(
            (data['categories'] as List?) ?? const [],
          );
          final allProducts = List<Map<String, dynamic>>.from(
            (data['products'] as List?) ?? const [],
          );
          final products = _categoryId == null
              ? allProducts
              : allProducts
                  .where((p) => p['category_id']?.toString() == _categoryId)
                  .toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FutureBuilder<String?>(
                      future: repo.signedImageUrl(
                        vendor['banner_path']?.toString(),
                      ),
                      builder: (context, image) => Container(
                        height: 190,
                        width: double.infinity,
                        color: const Color(0xFFEAF2FC),
                        child: image.data == null
                            ? const Icon(
                                Icons.storefront_outlined,
                                size: 58,
                                color: AppColors.blue,
                              )
                            : Image.network(
                                image.data!,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: -44,
                      child: FutureBuilder<String?>(
                        future: repo.signedImageUrl(
                          vendor['logo_path']?.toString(),
                        ),
                        builder: (context, image) => Container(
                          width: 92,
                          height: 92,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: image.data == null
                              ? const Icon(
                                  Icons.storefront_rounded,
                                  color: AppColors.blue,
                                  size: 42,
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.network(
                                    image.data!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 58, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (vendor['display_name'] ?? '').toString(),
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (vendor['is_verified'] == true)
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.blue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 17,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (vendor['city'] ?? '').toString(),
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.star_rounded,
                            size: 17,
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (vendor['rating_avg'] ?? 0).toString() +
                                ' (' +
                                (vendor['rating_count'] ?? 0).toString() +
                                ')',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                      if ((vendor['description'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          vendor['description'].toString(),
                          style: const TextStyle(
                            height: 1.45,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (vendor['delivery_enabled'] == true)
                            const Chip(
                              avatar: Icon(
                                Icons.local_shipping_outlined,
                                size: 17,
                              ),
                              label: Text('Dërgesë'),
                            ),
                          if (vendor['pickup_enabled'] == true)
                            const Chip(
                              avatar: Icon(
                                Icons.store_mall_directory_outlined,
                                size: 17,
                              ),
                              label: Text('Marrje në dyqan'),
                            ),
                          Chip(
                            avatar: const Icon(
                              Icons.assignment_return_outlined,
                              size: 17,
                            ),
                            label: Text(
                              'Kthim ' +
                                  (vendor['return_window_days'] ?? 14)
                                      .toString() +
                                  ' ditë',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 54,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              'Të gjitha (' + allProducts.length.toString() + ')',
                            ),
                            selected: _categoryId == null,
                            onSelected: (_) =>
                                setState(() => _categoryId = null),
                          ),
                        ),
                        ...categories.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                (c['name_sq'] ?? '').toString() +
                                    ' (' +
                                    (c['product_count'] ?? 0).toString() +
                                    ')',
                              ),
                              selected:
                                  _categoryId == c['id']?.toString(),
                              onSelected: (_) => setState(
                                () => _categoryId = c['id']?.toString(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: products.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 50),
                          child: Center(
                            child: Text(
                              'Nuk ka produkte në këtë kategori.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        ),
                      )
                    : SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = products[index];
                            final price = professional &&
                                    product['professional_price'] != null
                                ? product['professional_price']
                                : product['retail_price'];
                            return Card(
                              elevation: 0,
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MarketProductScreen(
                                        productId:
                                            product['id'].toString(),
                                        audience: widget.audience,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: FutureBuilder<String?>(
                                          future: repo.signedImageUrl(
                                            product['primary_image_path']
                                                ?.toString(),
                                          ),
                                          builder: (context, image) =>
                                              Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: image.data == null
                                                ? const Icon(
                                                    Icons
                                                        .inventory_2_outlined,
                                                    color: AppColors.blue,
                                                    size: 42,
                                                  )
                                                : Image.network(
                                                    image.data!,
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 9),
                                      Text(
                                        (product['name'] ?? '').toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        (price ?? 0).toString() +
                                            ' ' +
                                            (product['currency'] ?? 'ALL')
                                                .toString(),
                                        style: const TextStyle(
                                          color: AppColors.blue,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: products.length,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .72,
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
