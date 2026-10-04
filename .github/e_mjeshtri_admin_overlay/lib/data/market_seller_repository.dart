import 'dart:html' as html;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class MarketSellerRepository {
  MarketSellerRepository._();
  static final instance = MarketSellerRepository._();

  final SupabaseClient client = Supabase.instance.client;

  String get uid {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Duhet të hysh në llogari.');
    return id;
  }

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => client.auth.signOut();

  Future<Map<String, dynamic>?> membership() async {
    final row = await client
        .from('market_vendor_members')
        .select('id,vendor_id,role,is_active,market_vendors(*)')
        .eq('user_id', uid)
        .eq('is_active', true)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<String> registerVendor({
    required String displayName,
    String? legalName,
    String? taxId,
    String? email,
    String? phone,
    String? city,
    String? street,
    String? postalCode,
    String? description,
  }) async {
    final raw = await client.rpc(
      'market_register_vendor',
      params: {
        'p_display_name': displayName.trim(),
        'p_legal_name': _nullIfEmpty(legalName),
        'p_tax_id': _nullIfEmpty(taxId),
        'p_email': _nullIfEmpty(email),
        'p_phone': _nullIfEmpty(phone),
        'p_city': _nullIfEmpty(city),
        'p_street': _nullIfEmpty(street),
        'p_postal_code': _nullIfEmpty(postalCode),
        'p_description': _nullIfEmpty(description),
      },
    );
    return raw.toString();
  }

  Future<Map<String, dynamic>> dashboard(String vendorId) async {
    final raw = await client.rpc(
      'market_vendor_dashboard',
      params: {'p_vendor_id': vendorId},
    );
    if (raw is! Map) throw StateError('Dashboard i e-Market nuk u ngarkua.');
    return Map<String, dynamic>.from(raw);
  }

  Future<List<Map<String, dynamic>>> products(String vendorId) async {
    final rows = await client
        .from('market_products')
        .select(
          'id,name,sku,audience,retail_price,professional_price,compare_at_price,'
          'currency,stock_quantity,reserved_quantity,low_stock_threshold,'
          'warranty_months,status,is_featured,is_new,rejection_reason,created_at,'
          'market_categories(name_sq),market_brands(name)',
        )
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> categories() async {
    final rows = await client
        .from('market_categories')
        .select('id,name_sq,audience,parent_id,sort_order')
        .eq('is_active', true)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> brands() async {
    final rows = await client
        .from('market_brands')
        .select('id,name')
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String> createProduct({
    required String vendorId,
    required String categoryId,
    String? brandId,
    String? installationCategoryId,
    required String name,
    required String slug,
    String? sku,
    String? shortDescription,
    String? description,
    required String audience,
    required double retailPrice,
    double? professionalPrice,
    double? compareAtPrice,
    required int stockQuantity,
    required int lowStockThreshold,
    required int warrantyMonths,
  }) async {
    final row = await client
        .from('market_products')
        .insert({
          'vendor_id': vendorId,
          'category_id': categoryId,
          'brand_id': brandId,
          'installation_category_id': installationCategoryId,
          'name': name.trim(),
          'slug': slug.trim(),
          'sku': _nullIfEmpty(sku),
          'short_description': _nullIfEmpty(shortDescription),
          'description': _nullIfEmpty(description),
          'audience': audience,
          'retail_price': retailPrice,
          'professional_price': professionalPrice,
          'compare_at_price': compareAtPrice,
          'currency': 'ALL',
          'stock_quantity': stockQuantity,
          'low_stock_threshold': lowStockThreshold,
          'warranty_months': warrantyMonths,
          'created_by': uid,
        })
        .select('id')
        .single();
    return row['id'].toString();
  }

  Future<void> updateStock({
    required String productId,
    required int stockQuantity,
    String? note,
  }) async {
    final current = await client
        .from('market_products')
        .select('vendor_id,stock_quantity')
        .eq('id', productId)
        .single();
    final oldQty = (current['stock_quantity'] as num?)?.toInt() ?? 0;

    await client
        .from('market_products')
        .update({
          'stock_quantity': stockQuantity,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId);

    await client.from('market_inventory_movements').insert({
      'vendor_id': current['vendor_id'],
      'product_id': productId,
      'movement_type': 'adjustment',
      'quantity': stockQuantity - oldQty,
      'note': _nullIfEmpty(note) ?? 'Korrigjim stoku nga Seller Panel',
      'created_by': uid,
    });
  }

  Future<void> setProductState(String productId, String state) async {
    if (!const {'draft', 'inactive', 'archived'}.contains(state)) {
      throw ArgumentError('Status i pavlefshëm.');
    }
    await client
        .from('market_products')
        .update({
          'status': state,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId);
  }

  Future<List<Map<String, dynamic>>> vendorOrders(String vendorId) async {
    final raw = await dashboard(vendorId);
    return List<Map<String, dynamic>>.from(
      (raw['recent_orders'] as List?) ?? const [],
    );
  }

  Future<Map<String, dynamic>> vendorOrderDetail(
    String vendorId,
    String vendorOrderId,
  ) async {
    final raw = await client.rpc(
      'market_vendor_order_detail',
      params: {
        'p_vendor_id': vendorId,
        'p_vendor_order_id': vendorOrderId,
      },
    );
    if (raw is! Map) throw StateError('Porosia nuk u gjet.');
    return Map<String, dynamic>.from(raw);
  }

  Future<void> orderAction({
    required String vendorId,
    required String vendorOrderId,
    required String action,
    String? trackingCode,
    String? trackingUrl,
  }) async {
    await client.rpc(
      'market_vendor_order_action',
      params: {
        'p_vendor_id': vendorId,
        'p_vendor_order_id': vendorOrderId,
        'p_action': action,
        'p_tracking_code': _nullIfEmpty(trackingCode),
        'p_tracking_url': _nullIfEmpty(trackingUrl),
      },
    );
  }

  Future<void> updateVendorProfile({
    required String vendorId,
    required String displayName,
    String? legalName,
    String? taxId,
    String? email,
    String? phone,
    String? description,
    String? street,
    String? city,
    String? postalCode,
    required bool deliveryEnabled,
    required bool pickupEnabled,
    required double flatDeliveryFee,
    double? freeDeliveryOver,
    required int returnWindowDays,
    String? bankName,
    String? bankAccountName,
    String? bankIban,
    String? bankNote,
  }) async {
    await client
        .from('market_vendors')
        .update({
          'display_name': displayName.trim(),
          'legal_name': _nullIfEmpty(legalName),
          'tax_id': _nullIfEmpty(taxId),
          'email': _nullIfEmpty(email),
          'phone': _nullIfEmpty(phone),
          'description': _nullIfEmpty(description),
          'street': _nullIfEmpty(street),
          'city': _nullIfEmpty(city),
          'postal_code': _nullIfEmpty(postalCode),
          'delivery_enabled': deliveryEnabled,
          'pickup_enabled': pickupEnabled,
          'flat_delivery_fee': flatDeliveryFee,
          'free_delivery_over': freeDeliveryOver,
          'return_window_days': returnWindowDays,
          'bank_name': _nullIfEmpty(bankName),
          'bank_account_name': _nullIfEmpty(bankAccountName),
          'bank_iban': _nullIfEmpty(bankIban),
          'bank_note': _nullIfEmpty(bankNote),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', vendorId);
  }

  Future<html.File?> pickFile({
    String accept = 'image/jpeg,image/png,image/webp',
  }) async {
    final input = html.FileUploadInputElement()
      ..accept = accept
      ..multiple = false;
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return null;
    return input.files!.first;
  }

  Future<Uint8List> _readFile(html.File file) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final result = reader.result;
    if (result is ByteBuffer) return result.asUint8List();
    if (result is Uint8List) return result;
    throw StateError('Skedari nuk mund të lexohet.');
  }

  Future<String> uploadProductImage({
    required String vendorId,
    required String productId,
    required html.File file,
  }) async {
    if (file.size > 20 * 1024 * 1024) {
      throw StateError('Fotoja nuk mund të jetë më e madhe se 20 MB.');
    }
    final bytes = await _readFile(file);
    final ext = _extension(file.name);
    final path = vendorId +
        '/' +
        productId +
        '/' +
        DateTime.now().microsecondsSinceEpoch.toString() +
        '.' +
        ext;

    await client.storage.from('market-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: file.type.isEmpty ? 'image/jpeg' : file.type,
            upsert: false,
          ),
        );

    await client.from('market_product_media').insert({
      'product_id': productId,
      'media_type': 'image',
      'storage_path': path,
      'sort_order': 0,
      'is_primary': true,
    });
    return path;
  }

  Future<String> uploadVendorDocument({
    required String vendorId,
    required String documentType,
    required html.File file,
  }) async {
    if (file.size > 8 * 1024 * 1024) {
      throw StateError('Dokumenti nuk mund të jetë më i madh se 8 MB.');
    }
    final bytes = await _readFile(file);
    final ext = _extension(file.name);
    final path = vendorId +
        '/' +
        DateTime.now().microsecondsSinceEpoch.toString() +
        '.' +
        ext;

    await client.storage.from('market-vendor-documents').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: file.type.isEmpty
                ? 'application/octet-stream'
                : file.type,
            upsert: false,
          ),
        );

    await client.from('market_vendor_documents').insert({
      'vendor_id': vendorId,
      'document_type': documentType,
      'storage_path': path,
      'status': 'pending',
    });
    return path;
  }

  Future<List<Map<String, dynamic>>> vendorDocuments(String vendorId) async {
    final rows = await client
        .from('market_vendor_documents')
        .select('id,document_type,status,review_note,created_at')
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  String slugify(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('ë', 'e')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final raw = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = raw.length > 7 ? raw.substring(7) : raw;
    return normalized.isEmpty
        ? 'produkt-' + suffix
        : normalized + '-' + suffix;
  }

  String? _nullIfEmpty(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'bin';
    return name.substring(dot + 1).toLowerCase();
  }
}
