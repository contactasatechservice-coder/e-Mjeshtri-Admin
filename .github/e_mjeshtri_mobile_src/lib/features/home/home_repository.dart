import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) => HomeRepository(Supabase.instance.client));
final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ref.read(homeRepositoryProvider).categories());
final activeProvidersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ref.read(homeRepositoryProvider).activeProviders());

class HomeRepository {
  HomeRepository(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> categories() async {
    final rows = await client.from('service_categories').select('id,slug,icon_key,sort_order,service_category_translations(language_code,name)').eq('is_active', true).isFilter('parent_id', null).order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> activeProviders() async {
    final rows = await client.from('providers').select('id,display_name,rating_avg,rating_count,city,logo_path,is_verified,blue_tick_expires_at').eq('status', 'active').order('rating_avg', ascending: false).limit(8);
    return List<Map<String, dynamic>>.from(rows);
  }
}