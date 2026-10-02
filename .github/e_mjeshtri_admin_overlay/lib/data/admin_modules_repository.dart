import 'package:supabase_flutter/supabase_flutter.dart';

class AdminModulesRepository {
  AdminModulesRepository._();
  static final instance = AdminModulesRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<AdminModuleSnapshot> load(String module) async {
    final raw = await _client.rpc(
      'admin_module_snapshot',
      params: {'p_module': module},
    );
    if (raw is! Map) {
      throw const FormatException('Përgjigje e pavlefshme nga Admin API.');
    }
    return AdminModuleSnapshot.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<Map<String, dynamic>> action(
    String module,
    String id,
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    final raw = await _client.rpc(
      'admin_module_action',
      params: {
        'p_module': module,
        'p_id': id,
        'p_action': action,
        'p_payload': payload,
      },
    );
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> supportThread(String ticketId) async {
    final raw = await _client.rpc(
      'admin_support_thread',
      params: {'p_ticket_id': ticketId},
    );
    if (raw is! Map) {
      throw const FormatException('Përgjigje e pavlefshme nga Support API.');
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<void> replySupport(String ticketId, String body) async {
    await _client.rpc(
      'admin_support_reply',
      params: {'p_ticket_id': ticketId, 'p_body': body},
    );
  }

  Future<String> signedProviderDocumentUrl(String storagePath) {
    return _client.storage
        .from('provider-documents')
        .createSignedUrl(storagePath, 600);
  }
}

class AdminModuleSnapshot {
  final String module;
  final String adminRole;
  final Map<String, dynamic> summary;
  final List<AdminModuleItem> items;
  final DateTime? generatedAt;

  const AdminModuleSnapshot({
    required this.module,
    required this.adminRole,
    required this.summary,
    required this.items,
    required this.generatedAt,
  });

  factory AdminModuleSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['summary'];
    final rawItems = json['items'];
    return AdminModuleSnapshot(
      module: (json['module'] ?? '').toString(),
      adminRole: (json['admin_role'] ?? 'admin').toString(),
      summary: rawSummary is Map
          ? Map<String, dynamic>.from(rawSummary)
          : <String, dynamic>{},
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => AdminModuleItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <AdminModuleItem>[],
      generatedAt:
          DateTime.tryParse((json['generated_at'] ?? '').toString())?.toLocal(),
    );
  }
}

class AdminModuleItem {
  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final String status;
  final String detail;
  final String? metric;
  final DateTime? createdAt;
  final Map<String, dynamic> data;

  const AdminModuleItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.detail,
    required this.metric,
    required this.createdAt,
    required this.data,
  });

  factory AdminModuleItem.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return AdminModuleItem(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      title: (json['title'] ?? '—').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      metric: json['metric']?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString())?.toLocal(),
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{},
    );
  }
}
