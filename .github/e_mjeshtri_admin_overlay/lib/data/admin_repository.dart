import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  AdminRepository._();
  static final instance = AdminRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final row = await _client
          .from('admin_users')
          .select('user_id,is_active,role,display_name')
          .eq('user_id', user.id)
          .maybeSingle();
      return row != null && row['is_active'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> currentAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final row = await _client
        .from('admin_users')
        .select('user_id,is_active,role,display_name')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> loadDashboard() async {
    final raw = await _client.rpc('admin_dashboard_overview');
    if (raw is! Map) {
      throw const FormatException('Përgjigje e pavlefshme nga Dashboard API.');
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<List<Map<String, dynamic>>> loadCitizens() async {
    final raw = await _client.rpc('admin_citizens_list');
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadProviders() async {
    final raw = await _client.rpc('admin_providers_list');
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> setCitizenStatus(
    String userId,
    String status, {
    String? reason,
  }) async {
    await _client.rpc(
      'admin_set_citizen_status',
      params: {
        'p_user_id': userId,
        'p_status': status,
        'p_reason': reason,
      },
    );
  }

  Future<void> setProviderStatus(
    String providerId,
    String action, {
    String? reason,
  }) async {
    await _client.rpc(
      'admin_set_provider_status',
      params: {
        'p_provider_id': providerId,
        'p_action': action,
        'p_reason': reason,
      },
    );
  }

  String friendlyError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (text.contains('42501') || lower.contains('not authorized') || lower.contains('insufficient admin')) {
      return 'Nuk ke leje për këtë veprim.';
    }
    if (text.contains('23514')) {
      if (lower.contains('approved document')) {
        return 'Mjeshtri duhet të ketë të paktën një dokument të aprovuar.';
      }
      if (lower.contains('active category')) {
        return 'Mjeshtri duhet të ketë të paktën një kategori aktive.';
      }
      if (lower.contains('city')) {
        return 'Mjeshtrit i mungon qyteti.';
      }
      if (lower.contains('contact')) {
        return 'Mjeshtrit i mungon telefoni ose email-i.';
      }
      return 'Të dhënat nuk plotësojnë kushtet e kërkuara.';
    }
    if (text.contains('P0002')) return 'Rekordi nuk u gjet.';
    if (lower.contains('invalid login credentials')) {
      return 'Email ose fjalëkalim i gabuar.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email-i nuk është konfirmuar.';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'Problem me internetin. Provo përsëri.';
    }
    return 'Ndodhi një gabim. Provo përsëri.';
  }
}
