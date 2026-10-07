import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(Supabase.instance.client);
});

class MarketplaceRepository {
  MarketplaceRepository(this.client);
  final SupabaseClient client;

  String get uid {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('User is not authenticated.');
    return id;
  }

  Future<Map<String, dynamic>> profile() async => Map<String, dynamic>.from(
        await client.from('profiles').select().eq('id', uid).single(),
      );

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final cleanFirst = firstName.trim();
    final cleanLast = lastName.trim();
    await client.from('profiles').update({
      'first_name': cleanFirst,
      'last_name': cleanLast,
      'phone': phone.trim(),
    }).eq('id', uid);
    await client.auth.updateUser(
      UserAttributes(data: {'first_name': cleanFirst, 'last_name': cleanLast}),
    );
  }

  Future<String?> avatarSignedUrl(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    return client.storage.from('avatars').createSignedUrl(path, 3600);
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
  }) async {
    final ext = extension.toLowerCase();
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
    final path = '$uid/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(upsert: false, contentType: mime),
    );
    await client.from('profiles').update({'avatar_path': path}).eq('id', uid);
    return path;
  }

  Future<void> removeAvatar(String? path) async {
    if (path != null && path.isNotEmpty) {
      await client.storage.from('avatars').remove([path]);
    }
    await client.from('profiles').update({'avatar_path': null}).eq('id', uid);
  }

  Future<List<Map<String, dynamic>>> addresses() async {
    final rows = await client.from('user_addresses').select().eq('user_id', uid).order('is_primary', ascending: false).order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> saveAddress(Map<String, dynamic> values, {String? id}) async {
    final payload = {...values, 'user_id': uid};
    if (id == null) {
      return Map<String, dynamic>.from(await client.from('user_addresses').insert(payload).select().single());
    }
    return Map<String, dynamic>.from(await client.from('user_addresses').update(payload).eq('id', id).select().single());
  }

  Future<void> deleteAddress(String id) async => client.from('user_addresses').delete().eq('id', id).eq('user_id', uid);

  Future<Map<String, dynamic>> category(String id) async => Map<String, dynamic>.from(
        await client.from('service_categories').select('id,parent_id,slug,icon_key,service_category_translations(language_code,name,description)').eq('id', id).single(),
      );

  Future<List<Map<String, dynamic>>> childCategories(String parentId) async {
    final rows = await client.from('service_categories').select('id,parent_id,slug,icon_key,service_category_translations(language_code,name,description)').eq('parent_id', parentId).eq('is_active', true).order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createRequest({
    required String categoryId,
    required String description,
    String? customProblem,
    required String urgency,
    DateTime? scheduledFor,
    required String city,
    double? lat,
    double? lng,
    double? budgetMin,
    double? budgetMax,
    required double searchRadiusKm,
    required Map<String, dynamic> privateLocation,
    bool publish = false,
  }) async {
    final request = Map<String, dynamic>.from(await client.from('service_requests').insert({
      'client_id': uid,
      'category_id': categoryId,
      'custom_problem': customProblem?.trim().isEmpty == true ? null : customProblem?.trim(),
      'description': description.trim(),
      'urgency': urgency,
      'status': publish ? 'published' : 'draft',
      'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
      'city': city.trim(),
      'approximate_latitude': lat,
      'approximate_longitude': lng,
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'search_radius_km': searchRadiusKm,
      'published_at': publish ? DateTime.now().toUtc().toIso8601String() : null,
      'idempotency_key': 'mobile:${DateTime.now().microsecondsSinceEpoch}',
    }).select().single());

    await client.from('request_private_locations').insert({
      'request_id': request['id'],
      'source_address_id': privateLocation['source_address_id'],
      'street': privateLocation['street'],
      'street_number': privateLocation['street_number'],
      'city': privateLocation['city'],
      'postal_code': privateLocation['postal_code'],
      'entrance': privateLocation['entrance'],
      'floor': privateLocation['floor'],
      'apartment': privateLocation['apartment'],
      'note': privateLocation['note'],
      'latitude': privateLocation['latitude'],
      'longitude': privateLocation['longitude'],
    });
    return request;
  }

  Future<void> publishRequest(String requestId) async {
    await client.from('service_requests').update({
      'status': 'published',
      'published_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId).eq('client_id', uid);
  }

  Future<void> expandRequestRadius(String requestId, double radius) async {
    await client.from('service_requests').update({'search_radius_km': radius}).eq('id', requestId).eq('client_id', uid);
  }

  Future<void> cancelRequest(String requestId, String reason) async {
    await client.from('service_requests').update({'status': 'cancelled', 'cancel_reason': reason}).eq('id', requestId).eq('client_id', uid);
  }

  Future<void> uploadRequestMedia({
    required String requestId,
    required Uint8List bytes,
    required String extension,
    required String mediaType,
  }) async {
    final normalized = extension.toLowerCase();
    final mimeType = mediaType == 'video'
        ? (normalized == 'mov' ? 'video/quicktime' : 'video/mp4')
        : switch (normalized) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            'heic' => 'image/heic',
            'heif' => 'image/heif',
            _ => 'image/jpeg',
          };
    final path = '$uid/$requestId/${DateTime.now().microsecondsSinceEpoch}.$normalized';
    await client.storage.from('request-media').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(upsert: false, contentType: mimeType),
    );
    await client.from('request_media').insert({
      'request_id': requestId,
      'storage_path': path,
      'media_type': mediaType,
    });
  }

  Future<Map<String, dynamic>> request(String id) async => Map<String, dynamic>.from(
        await client.from('service_requests').select('*,service_categories(id,slug,service_category_translations(language_code,name)),request_private_locations(*)').eq('id', id).single(),
      );

  Future<List<Map<String, dynamic>>> requests({String? status}) async {
    var q = client.from('service_requests').select('id,description,status,urgency,scheduled_for,city,created_at,service_categories(slug,service_category_translations(language_code,name))').eq('client_id', uid);
    if (status != null) q = q.eq('status', status);
    final rows = await q.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> activityRequests() async {
    final rows = await client
        .from('service_requests')
        .select(
          'id,description,status,urgency,scheduled_for,city,created_at,'
          'budget_min,budget_max,currency,'
          'service_categories(id,slug,service_category_translations(language_code,name)),'
          'offers(id,total_amount,currency,status,is_current,created_at,'
          'providers(id,display_name,is_verified,blue_tick_expires_at,rating_avg,city))',
        )
        .eq('client_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> offers(String requestId) async {
    final rows = await client.from('offers').select('*,providers(id,display_name,logo_path,is_verified,blue_tick_expires_at,rating_avg,rating_count,city,bio)').eq('request_id', requestId).eq('is_current', true).order('total_amount');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> offer(String id) async => Map<String, dynamic>.from(
        await client.from('offers').select('*,providers(id,display_name,logo_path,is_verified,blue_tick_expires_at,rating_avg,rating_count,city,bio,phone)').eq('id', id).single(),
      );

  Future<dynamic> _clientOrderAction(Map<String, dynamic> body) async {
    final response = await client.functions.invoke('client-order-actions', body: body);
    final payload = response.data;
    if (payload is Map && payload['error'] != null) {
      throw StateError(payload['error'].toString());
    }
    if (payload is Map && payload.containsKey('data')) return payload['data'];
    return payload;
  }

  Future<String> acceptOffer(String offerId) async {
    final value = await _clientOrderAction({'action': 'accept_offer', 'offer_id': offerId});
    return value.toString();
  }

  Future<List<Map<String, dynamic>>> searchProviders({
    String query = '',
    bool verifiedOnly = false,
    double minRating = 0,
  }) async {
    var q = client.from('providers').select('id,display_name,is_verified,blue_tick_expires_at,rating_avg,rating_count,city,bio,logo_path,latitude,longitude').eq('status', 'active');
    if (verifiedOnly) q = q.eq('is_verified', true);
    if (minRating > 0) q = q.gte('rating_avg', minRating);
    final rows = await q.order('rating_avg', ascending: false).limit(100);
    final all = List<Map<String, dynamic>>.from(rows);
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return all;
    return all.where((p) {
      final text = '${p['display_name'] ?? ''} ${p['city'] ?? ''} ${p['bio'] ?? ''}'.toLowerCase();
      return text.contains(normalized);
    }).toList();
  }

  Future<String?> providerMediaSignedUrl(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    return client.storage.from('provider-media').createSignedUrl(path, 1800);
  }

  Future<Map<String, dynamic>> provider(String id) async => Map<String, dynamic>.from(
        await client.from('providers').select('*,provider_categories(*,service_categories(slug,service_category_translations(language_code,name))),provider_media(*),provider_branches(*)').eq('id', id).single(),
      );

  Future<Map<String,dynamic>> providerPublicProfileStats(String providerId) async {
    final raw = await client.rpc(
      'provider_public_profile_stats',
      params: {'p_provider_id': providerId},
    );
    return raw is Map ? Map<String,dynamic>.from(raw) : <String,dynamic>{};
  }

  Future<List<Map<String,dynamic>>> providerReviews(String providerId) async {
    final raw = await client.rpc(
      'provider_public_reviews',
      params: {'p_provider_id': providerId},
    );
    if (raw is! List) return const <Map<String,dynamic>>[];
    return raw
        .whereType<Map>()
        .map((x) => Map<String,dynamic>.from(x))
        .take(6)
        .toList();
  }

  Future<bool> isFavorite(String providerId) async {
    final row = await client.from('favorites').select('provider_id').eq('user_id', uid).eq('provider_id', providerId).maybeSingle();
    return row != null;
  }

  Future<void> setFavorite(String providerId, bool value) async {
    if (value) {
      await client.from('favorites').upsert({'user_id': uid, 'provider_id': providerId});
    } else {
      await client.from('favorites').delete().eq('user_id', uid).eq('provider_id', providerId);
    }
  }

  Future<List<Map<String, dynamic>>> favorites() async {
    final rows = await client.from('favorites').select('created_at,providers(id,display_name,is_verified,blue_tick_expires_at,rating_avg,rating_count,city,bio,logo_path)').eq('user_id', uid).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> orders() async {
    final rows = await client.from('service_orders').select('id,status,scheduled_for,current_total,currency,created_at,completed_at,providers(id,display_name,is_verified,blue_tick_expires_at,rating_avg,city),service_requests(id,description,urgency,city,category_id)').eq('client_id', uid).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> order(String id) async => Map<String, dynamic>.from(
        await client.from('service_orders').select('*,providers(id,display_name,is_verified,blue_tick_expires_at,rating_avg,rating_count,city,phone,bio),service_requests(id,description,urgency,city,category_id),order_price_changes(*),warranties(*)').eq('id', id).single(),
      );


  Stream<Map<String, dynamic>?> orderStatusStream(String orderId) {
    return client
        .from('service_orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((rows) => rows.isEmpty
            ? null
            : Map<String, dynamic>.from(rows.first));
  }

  Stream<Map<String, dynamic>?> liveLocationStream(String orderId) {
    return client
        .from('order_live_locations')
        .stream(primaryKey: ['order_id'])
        .eq('order_id', orderId)
        .map((rows) => rows.isEmpty ? null : Map<String, dynamic>.from(rows.first));
  }

  Future<void> cancelOrder(String orderId, String reason) async => _clientOrderAction({'action': 'cancel_order', 'order_id': orderId, 'reason': reason});
  Future<void> confirmCompletion(String orderId) async => _clientOrderAction({'action': 'confirm_completion', 'order_id': orderId});
  Future<void> respondPriceChange(String changeId, bool accept) async => _clientOrderAction({'action': 'respond_price_change', 'change_id': changeId, 'accept': accept});
  Future<String> confirmCashPayment(String orderId) async => (await _clientOrderAction({'action': 'confirm_cash_payment', 'order_id': orderId})).toString();

  Future<void> requestReschedule(String orderId, DateTime date, String reason) async {
    await client.from('order_reschedule_requests').insert({
      'order_id': orderId,
      'requested_by': uid,
      'proposed_for': date.toUtc().toIso8601String(),
      'reason': reason.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> conversations() async {
    final rows = await client
        .from('conversations')
        .select(
          'id,status,updated_at,provider_id,request_id,order_id,'
          'providers(id,display_name,is_verified,blue_tick_expires_at),'
          'messages(id,body,message_type,created_at,sender_user_id)',
        )
        .eq('client_id', uid)
        .isFilter('client_deleted_at', null)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String> conversationForProvider(
    String providerId, {
    String? requestId,
    String? orderId,
  }) async {
    final raw = await client.rpc(
      'client_conversation_for_provider',
      params: {
        'p_provider_id': providerId,
        'p_request_id': requestId,
        'p_order_id': orderId,
      },
    );
    return raw.toString();
  }

  Future<void> hideConversation(String conversationId) async {
    await client.rpc(
      'hide_my_conversation',
      params: {'p_conversation_id': conversationId},
    );
  }

  Future<Map<String, dynamic>> conversation(String id) async => Map<String, dynamic>.from(
        await client.from('conversations').select('*,providers(id,display_name,is_verified,blue_tick_expires_at)').eq('id', id).single(),
      );

  Stream<List<Map<String, dynamic>>> messagesStream(String conversationId) {
    return client.from('messages').stream(primaryKey: ['id']).eq('conversation_id', conversationId).order('created_at').map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_user_id': uid,
      'message_type': 'text',
      'body': text,
      'client_generated_id': '$uid:${DateTime.now().microsecondsSinceEpoch}',
    });
    await client.from('conversations').update({'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', conversationId);
  }


  Future<String> uploadChatAttachment({
    required String conversationId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
    required String messageType,
    required String fileName,
  }) async {
    final cleanExt = extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final path = '$uid/$conversationId/${DateTime.now().microsecondsSinceEpoch}.${cleanExt.isEmpty ? 'bin' : cleanExt}';
    await client.storage.from('chat-media').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(upsert: false, contentType: contentType),
    );
    final row = await client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_user_id': uid,
      'message_type': messageType,
      'body': fileName,
      'metadata': {'storage_path': path, 'file_name': fileName, 'content_type': contentType},
      'client_generated_id': '$uid:${DateTime.now().microsecondsSinceEpoch}',
    }).select('id').single();
    await client.from('conversations').update({'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', conversationId);
    return row['id'].toString();
  }

  Future<String?> chatMediaSignedUrl(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    return client.storage.from('chat-media').createSignedUrl(path, 1800);
  }

  Future<void> sendLocationMessage({
    required String conversationId,
    required double latitude,
    required double longitude,
  }) async {
    await client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_user_id': uid,
      'message_type': 'location',
      'body': '$latitude,$longitude',
      'metadata': {'latitude': latitude, 'longitude': longitude},
      'client_generated_id': '$uid:${DateTime.now().microsecondsSinceEpoch}',
    });
    await client.from('conversations').update({'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', conversationId);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final rows = await client.from('notifications').select().eq('user_id', uid).order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> markNotificationRead(String id) async => client.from('notifications').update({'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).eq('user_id', uid);

  Future<Map<String, dynamic>> notificationPreferences() async {
    return Map<String, dynamic>.from(await client.from('notification_preferences').select().eq('user_id', uid).single());
  }

  Future<void> saveNotificationPreferences(Map<String, dynamic> values) async => client.from('notification_preferences').update(values).eq('user_id', uid);

  Future<void> createReview({required String orderId, required String providerId, required int rating, String? comment}) async {
    await client.from('reviews').insert({'order_id': orderId, 'client_id': uid, 'provider_id': providerId, 'rating': rating, 'comment': comment?.trim()});
  }

  Future<List<Map<String, dynamic>>> supportTickets() async {
    final rows = await client.from('support_tickets').select().eq('user_id', uid).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String> createSupportTicket({required String category, required String subject, required String message, String? orderId}) async {
    final ticket = await client.from('support_tickets').insert({'user_id': uid, 'order_id': orderId, 'category': category, 'subject': subject}).select('id').single();
    final id = ticket['id'].toString();
    await client.from('support_messages').insert({'ticket_id': id, 'sender_user_id': uid, 'sender_type': 'user', 'body': message.trim()});
    return id;
  }

  Future<void> requestAccountDeletion(String? reason) async {
    await client.from('account_deletion_requests').upsert({'user_id': uid, 'reason': reason?.trim(), 'status': 'requested'});
    await client.from('profiles').update({'status': 'deletion_requested'}).eq('id', uid);
  }

  Future<void> requestDataExport() async {
    await client.from('data_export_requests').insert({'user_id': uid});
  }

  Future<List<Map<String, dynamic>>> blockedProviders() async {
    final rows = await client.from('blocked_providers').select('created_at,reason,providers(id,display_name)').eq('user_id', uid).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> unblockProvider(String providerId) async => client.from('blocked_providers').delete().eq('user_id', uid).eq('provider_id', providerId);

  Future<Map<String, dynamic>?> receiptForPayment(String paymentId) async {
    final row = await client
        .from('receipts')
        .select('id,receipt_number,invoice_url,issued_at')
        .eq('payment_id', paymentId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> supportMessages(String ticketId) async {
    final rows = await client
        .from('support_messages')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Stream<List<Map<String, dynamic>>> supportMessagesStream(String ticketId) {
    return client
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .map((rows) {
          final items = List<Map<String, dynamic>>.from(rows);
          items.sort((a, b) {
            final aTime =
                DateTime.tryParse((a['created_at'] ?? '').toString()) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                DateTime.tryParse((b['created_at'] ?? '').toString()) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
            final byTime = aTime.compareTo(bTime);
            if (byTime != 0) return byTime;
            return (a['id'] ?? '').toString().compareTo(
                  (b['id'] ?? '').toString(),
                );
          });
          return items;
        });
  }

  Future<String> openSubscriptionSupportChat() async {
    final existing = await client
        .from('support_tickets')
        .select('id,subject,status')
        .eq('user_id', uid)
        .eq('category', 'payment')
        .inFilter('status', ['open', 'in_progress', 'waiting_user'])
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) return existing['id'].toString();

    final ticket = await client
        .from('support_tickets')
        .insert({
          'user_id': uid,
          'category': 'payment',
          'subject': 'Abonimi i Mjeshtrit',
          'priority': 'high',
          'status': 'open',
        })
        .select('id')
        .single();

    final id = ticket['id'].toString();
    await client.from('support_messages').insert({
      'ticket_id': id,
      'sender_user_id': uid,
      'sender_type': 'user',
      'body': 'Përshëndetje, kam nevojë për ndihmë me abonimin e Mjeshtrit.',
    });
    return id;
  }

  Future<void> sendSupportMessage(String ticketId, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await client.from('support_messages').insert({
      'ticket_id': ticketId,
      'sender_user_id': uid,
      'sender_type': 'user',
      'body': text,
    });
    await client
        .from('support_tickets')
        .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', ticketId)
        .eq('user_id', uid);
  }

  Future<void> createReport({
    String? providerId,
    String? orderId,
    String? conversationId,
    required String type,
    required String description,
  }) async {
    await client.from('reports').insert({
      'reporter_user_id': uid,
      'provider_id': providerId,
      'order_id': orderId,
      'conversation_id': conversationId,
      'report_type': type,
      'description': description.trim(),
    });
  }

  Future<void> blockProvider(String providerId, {String? reason}) async {
    await client.from('blocked_providers').upsert({
      'user_id': uid,
      'provider_id': providerId,
      'reason': reason?.trim(),
    });
  }

}