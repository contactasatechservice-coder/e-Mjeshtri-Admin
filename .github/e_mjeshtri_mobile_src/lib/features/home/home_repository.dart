import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final homeRepositoryProvider =
    Provider<HomeRepository>((ref) => HomeRepository(Supabase.instance.client));
final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.read(homeRepositoryProvider).categories(),
);
final activeProvidersProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.read(homeRepositoryProvider).activeProviders(),
);

class HomeRepository {
  HomeRepository(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> categories() async {
    final rows = await client
        .from('service_categories')
        .select(
          'id,slug,icon_key,sort_order,service_category_translations(language_code,name)',
        )
        .eq('is_active', true)
        .isFilter('parent_id', null)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> activeProviders() async {
    Map<String, dynamic>? primaryAddress;
    final uid = client.auth.currentUser?.id;
    if (uid != null) {
      final raw = await client
          .from('user_addresses')
          .select('latitude,longitude')
          .eq('user_id', uid)
          .eq('is_primary', true)
          .limit(1)
          .maybeSingle();
      if (raw != null) primaryAddress = Map<String, dynamic>.from(raw);
    }

    final rows = await client
        .from('providers')
        .select(
          'id,display_name,rating_avg,rating_count,city,logo_path,is_verified,'
          'blue_tick_expires_at,latitude,longitude,accepts_asap,vacation_mode,'
          'provider_categories(category_id,is_active,service_categories(id,slug,icon_key,service_category_translations(language_code,name)))',
        )
        .eq('status', 'active')
        .eq('is_verified', true)
        .order('rating_avg', ascending: false)
        .limit(20);

    final userLat = (primaryAddress?['latitude'] as num?)?.toDouble();
    final userLng = (primaryAddress?['longitude'] as num?)?.toDouble();

    final enriched = <Map<String, dynamic>>[];
    for (final raw in rows) {
      final item = Map<String, dynamic>.from(raw);
      final lat = (item['latitude'] as num?)?.toDouble();
      final lng = (item['longitude'] as num?)?.toDouble();
      if (userLat != null && userLng != null && lat != null && lng != null) {
        item['distance_km'] = _distanceKm(userLat, userLng, lat, lng);
      }
      enriched.add(item);
    }

    // Keep the Home feed clean when test/duplicate profiles share the same
    // visible identity and main specialty.
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final item in enriched) {
      final categories = item['provider_categories'];
      String specialty = '';
      if (categories is List) {
        for (final rawCategory in categories) {
          if (rawCategory is! Map || rawCategory['is_active'] != true) continue;
          final category = rawCategory['service_categories'];
          if (category is Map) {
            specialty = (category['slug'] ?? '').toString().toLowerCase();
            break;
          }
        }
      }
      final key = [
        (item['display_name'] ?? '').toString().trim().toLowerCase(),
        (item['city'] ?? '').toString().trim().toLowerCase(),
        specialty,
      ].join('|');
      if (seen.add(key)) unique.add(item);
      if (unique.length >= 8) break;
    }

    return unique;
  }

  double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _radians(double degrees) => degrees * math.pi / 180.0;
}
