import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final marketRepositoryProvider = Provider<MarketRepository>(
  (ref) => MarketRepository(Supabase.instance.client),
);

class MarketRepository {
  MarketRepository(this.client);
  final SupabaseClient client;

  String get uid {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('User is not authenticated.');
    return id;
  }

  Future<List<Map<String, dynamic>>> banners(String audience) async {
    final raw = await client.rpc(
      'market_active_banners',
      params: {'p_audience': audience},
    );
    return List<Map<String, dynamic>>.from((raw as List?) ?? const []);
  }

  Future<String?> signedBannerUrl(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    try {
      return await client.storage
          .from('market-banners')
          .createSignedUrl(path, 1800);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> categories(String audience) async {
    final raw = await client.rpc(
      'market_categories_for_audience',
      params: {'p_audience': audience},
    );
    return List<Map<String, dynamic>>.from((raw as List?) ?? const []);
  }

  Future<List<Map<String, dynamic>>> catalog({
    required String audience,
    String query = '',
    String? categoryId,
  }) async {
    final raw = await client.rpc(
      'market_catalog',
      params: {
        'p_audience': audience,
        'p_query': query.trim().isEmpty ? null : query.trim(),
        'p_category_id': categoryId,
        'p_limit': 100,
        'p_offset': 0,
      },
    );
    return List<Map<String, dynamic>>.from((raw as List?) ?? const []);
  }

  Future<Map<String, dynamic>> product(String productId) async {
    final raw = await client.rpc(
      'market_product_detail',
      params: {'p_product_id': productId},
    );
    if (raw is! Map) throw StateError('Produkti nuk u gjet.');
    return Map<String, dynamic>.from(raw);
  }

  Future<Map<String, dynamic>> vendorProfile({
    required String vendorId,
    required String audience,
  }) async {
    final raw = await client.rpc(
      'market_vendor_public_profile',
      params: {
        'p_vendor_id': vendorId,
        'p_audience': audience,
      },
    );
    if (raw is! Map) throw StateError('Dyqani nuk u gjet.');
    return Map<String, dynamic>.from(raw);
  }

  Future<bool> isFavorite(String productId) async {
    final row = await client
        .from('market_favorites')
        .select('product_id')
        .eq('user_id', uid)
        .eq('product_id', productId)
        .maybeSingle();
    return row != null;
  }

  Future<void> setFavorite(String productId, bool value) async {
    if (value) {
      await client.from('market_favorites').upsert({
        'user_id': uid,
        'product_id': productId,
      });
    } else {
      await client
          .from('market_favorites')
          .delete()
          .eq('user_id', uid)
          .eq('product_id', productId);
    }
  }

  Future<String> _activeCartId() async {
    final existing = await client
        .from('market_carts')
        .select('id')
        .eq('user_id', uid)
        .eq('status', 'active')
        .maybeSingle();
    if (existing != null) return existing['id'].toString();

    final created = await client
        .from('market_carts')
        .insert({'user_id': uid, 'status': 'active'})
        .select('id')
        .single();
    return created['id'].toString();
  }

  Future<void> addToCart({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) async {
    final cartId = await _activeCartId();
    var query = client
        .from('market_cart_items')
        .select('id,quantity')
        .eq('cart_id', cartId)
        .eq('product_id', productId);

    if (variantId == null) {
      query = query.isFilter('variant_id', null);
    } else {
      query = query.eq('variant_id', variantId);
    }

    final existing = await query.maybeSingle();
    if (existing == null) {
      await client.from('market_cart_items').insert({
        'cart_id': cartId,
        'product_id': productId,
        'variant_id': variantId,
        'quantity': quantity,
      });
    } else {
      await client
          .from('market_cart_items')
          .update({
            'quantity': (existing['quantity'] as num).toInt() + quantity,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', existing['id']);
    }
  }

  Future<int> cartCount() async {
    final cart = await client
        .from('market_carts')
        .select('id')
        .eq('user_id', uid)
        .eq('status', 'active')
        .maybeSingle();
    if (cart == null) return 0;

    final rows = await client
        .from('market_cart_items')
        .select('quantity')
        .eq('cart_id', cart['id']);
    var total = 0;
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      total += (row['quantity'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  Future<Map<String, dynamic>> cartSnapshot(String audience) async {
    final raw = await client.rpc(
      'market_cart_snapshot',
      params: {'p_audience': audience},
    );
    if (raw is! Map) {
      return {
        'cart_id': null,
        'items': <Map<String, dynamic>>[],
        'subtotal': 0,
        'count': 0,
      };
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<void> setCartItemQuantity(String cartItemId, int quantity) async {
    if (quantity <= 0) {
      await client.from('market_cart_items').delete().eq('id', cartItemId);
      return;
    }
    await client
        .from('market_cart_items')
        .update({
          'quantity': quantity,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', cartItemId);
  }

  Future<Map<String, dynamic>> checkoutDefaults() async {
    final profile = await client
        .from('profiles')
        .select('first_name,last_name,phone')
        .eq('id', uid)
        .single();

    final address = await client
        .from('user_addresses')
        .select()
        .eq('user_id', uid)
        .order('is_primary', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return {
      'profile': Map<String, dynamic>.from(profile),
      'address': address == null
          ? null
          : Map<String, dynamic>.from(address),
    };
  }

  Future<Map<String, dynamic>> checkout({
    required String audience,
    required String paymentMethod,
    required String deliveryName,
    required String deliveryPhone,
    required String deliveryStreet,
    required String deliveryCity,
    String? deliveryPostalCode,
    String? buyerNote,
  }) async {
    final raw = await client.rpc(
      'market_checkout',
      params: {
        'p_buyer_role': audience,
        'p_payment_method': paymentMethod,
        'p_delivery_name': deliveryName.trim(),
        'p_delivery_phone': deliveryPhone.trim(),
        'p_delivery_street': deliveryStreet.trim(),
        'p_delivery_city': deliveryCity.trim(),
        'p_delivery_postal_code': deliveryPostalCode?.trim(),
        'p_buyer_note': buyerNote?.trim(),
        'p_delivery_methods': <String, dynamic>{},
      },
    );
    if (raw is! Map) throw StateError('Checkout failed.');
    return Map<String, dynamic>.from(raw);
  }

  Future<List<Map<String, dynamic>>> orders() async {
    final raw = await client.rpc('market_orders_list');
    return List<Map<String, dynamic>>.from((raw as List?) ?? const []);
  }

  Future<Map<String, dynamic>> orderDetail(String orderId) async {
    final raw = await client.rpc(
      'market_order_detail',
      params: {'p_order_id': orderId},
    );
    if (raw is! Map) throw StateError('Porosia nuk u gjet.');
    return Map<String, dynamic>.from(raw);
  }

  Future<Map<String, dynamic>> cancelVendorOrder({
    required String vendorOrderId,
    required String reason,
  }) async {
    final raw = await client.rpc(
      'market_cancel_vendor_order',
      params: {
        'p_vendor_order_id': vendorOrderId,
        'p_reason': reason.trim(),
      },
    );
    if (raw is! Map) throw StateError('Anulimi dështoi.');
    return Map<String, dynamic>.from(raw);
  }

  Future<Map<String, dynamic>> requestReturn({
    required String vendorOrderId,
    required String reason,
    String? note,
  }) async {
    final raw = await client.rpc(
      'market_request_return',
      params: {
        'p_vendor_order_id': vendorOrderId,
        'p_reason': reason.trim(),
        'p_note': note?.trim(),
      },
    );
    if (raw is! Map) {
      throw StateError('Kërkesa e kthimit nuk u krijua.');
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<void> reportMarketEntity({
    required String entityType,
    required String entityId,
    required String reason,
    String? details,
  }) async {
    await client.from('market_reports').insert({
      'reporter_user_id': uid,
      'entity_type': entityType,
      'entity_id': entityId,
      'reason': reason.trim(),
      'details': details?.trim(),
      'status': 'open',
    });
  }

  Future<String?> signedImageUrl(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    try {
      return await client.storage.from('market-media').createSignedUrl(path, 1800);
    } catch (_) {
      return null;
    }
  }
}
