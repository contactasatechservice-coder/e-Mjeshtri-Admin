from pathlib import Path
import re

root = Path('.')
repo = root / 'lib/features/provider_portal/provider_repository.dart'
home = root / 'lib/features/provider_portal/home.dart'
requests = root / 'lib/features/provider_portal/requests.dart'
jobs = root / 'lib/features/provider_portal/jobs.dart'
profile = root / 'lib/features/provider_portal/profile.dart'
messages = root / 'lib/features/provider_portal/messages.dart'
shell = root / 'lib/features/provider_portal/shell.dart'


def replace_between(text, start, end, replacement):
    a = text.index(start)
    b = text.index(end, a)
    return text[:a] + replacement + '\n\n' + text[b:]


# Repository: realtime hooks, active subscription summary, weekly schedule save, branding uploads.
s = repo.read_text()
insert = r'''
  Stream<List<Map<String,dynamic>>> requestsStream() {
    return client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .where((x) => const ['published','searching','offers_received'].contains((x['status'] ?? '').toString()))
            .map((x) => Map<String,dynamic>.from(x))
            .toList());
  }

  Stream<List<Map<String,dynamic>>> ordersStream(String providerId) {
    return client
        .from('service_orders')
        .stream(primaryKey: ['id'])
        .eq('provider_id', providerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((x) => Map<String,dynamic>.from(x)).toList());
  }

  Future<Map<String,dynamic>?> activeSubscription(String providerId) async {
    final raw = await client.rpc(
      'provider_subscription_overview',
      params: {'p_provider_id': providerId},
    );
    final overview = raw is Map
        ? Map<String,dynamic>.from(raw)
        : <String,dynamic>{};
    final currentRaw = overview['current_subscription'];
    if (currentRaw is! Map) return null;
    final current = Map<String,dynamic>.from(currentRaw);

    Map<String,dynamic>? plan;
    final rawPlans = overview['plans'];
    if (rawPlans is List) {
      for (final item in rawPlans) {
        if (item is! Map) continue;
        final candidate = Map<String,dynamic>.from(item);
        if ((candidate['code'] ?? '').toString() ==
            (current['plan_code'] ?? '').toString()) {
          plan = candidate;
          break;
        }
      }
    }

    final blueRaw = overview['blue_tick'];
    final blue = blueRaw is Map
        ? Map<String,dynamic>.from(blueRaw)
        : <String,dynamic>{};

    return {
      ...current,
      'plan_name': plan?['name'],
      'plan_price_amount': plan?['price_amount'],
      'plan_blue_tick_included': plan?['blue_tick_included'] == true,
      'blue_tick_active': blue['active'] == true,
      'blue_tick_expires_at': blue['expires_at'],
      'blue_tick_source': blue['source'],
    };
  }

  Future<void> saveWeeklyAvailability(
    String providerId,
    List<Map<String,dynamic>> rows, {
    required bool acceptsAsap,
  }) async {
    await client.from('provider_availability').delete().eq('provider_id', providerId);
    if (rows.isNotEmpty) {
      await client.from('provider_availability').insert(rows.map((x) => {
        'provider_id': providerId,
        'weekday': x['weekday'],
        'start_time': x['start_time'],
        'end_time': x['end_time'],
        'is_active': x['is_active'] == true,
      }).toList());
    }
    await updateProvider(providerId, {'accepts_asap': acceptsAsap});
  }

  Future<String?> providerImageUrl(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    return client.storage.from('provider-media').createSignedUrl(path, 3600);
  }

  Future<String> signedDocumentUrl(String path) {
    return client.storage.from('provider-documents').createSignedUrl(path, 3600);
  }

  Future<String> uploadProviderBrandImage(
    String providerId,
    XFile file, {
    required bool banner,
  }) async {
    final ext0 = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    final ext = ext0 == 'jpeg' ? 'jpg' : ext0;
    final mime = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
    final kind = banner ? 'banner' : 'profile';
    final path = providerId + '/branding/' + kind + '-' + DateTime.now().millisecondsSinceEpoch.toString() + '.' + ext;
    await client.storage.from('provider-media').uploadBinary(
      path,
      await file.readAsBytes(),
      fileOptions: FileOptions(upsert: false, contentType: mime),
    );
    if (banner) {
      await client.from('provider_media')
          .delete()
          .eq('provider_id', providerId)
          .eq('caption', 'Banner');
      await updateProvider(providerId, {'banner_path': path});
    } else {
      await updateProvider(providerId, {'logo_path': path});
    }
    return path;
  }

  Future<void> deleteProviderBrandImage(
    String providerId, {
    required bool banner,
    required String? storagePath,
  }) async {
    final path = storagePath?.trim() ?? '';
    if (path.isNotEmpty) {
      try {
        await client.storage.from('provider-media').remove([path]);
      } catch (_) {}
    }
    await updateProvider(
      providerId,
      {banner ? 'banner_path' : 'logo_path': null},
    );
    if (banner) {
      await client.from('provider_media')
          .delete()
          .eq('provider_id', providerId)
          .eq('caption', 'Banner');
    }
  }

  Future<void> deletePortfolioImage(
    String providerId,
    String mediaId,
    String storagePath,
  ) async {
    await client.from('provider_media')
        .delete()
        .eq('id', mediaId)
        .eq('provider_id', providerId);
    if (storagePath.trim().isNotEmpty) {
      try {
        await client.storage.from('provider-media').remove([storagePath]);
      } catch (_) {}
    }
  }

  Future<List<Map<String,dynamic>>> reviews(String providerId) async {
    final rows = await client
        .from('reviews')
        .select('id,rating,comment,status,created_at,updated_at,order_id')
        .eq('provider_id', providerId)
        .eq('status', 'published')
        .order('created_at', ascending: false);
    return List<Map<String,dynamic>>.from(rows);
  }
'''
marker = '\n  Future<List<Map<String,dynamic>>> notifications() async {'
if 'requestsStream()' not in s:
    s = s.replace(marker, '\n' + insert + marker)

# Provider chat visibility and deletion.
s = s.replace(
"""  Future<List<Map<String,dynamic>>> conversations(String providerId) async {
    final rows = await client.from('conversations').select().eq('provider_id',providerId).order('updated_at',ascending:false);
    return List<Map<String,dynamic>>.from(rows);
  }
""",
"""  Future<List<Map<String,dynamic>>> conversations(String providerId) async {
    final rows = await client
        .from('conversations')
        .select()
        .eq('provider_id', providerId)
        .isFilter('provider_deleted_at', null)
        .order('updated_at', ascending: false);
    return List<Map<String,dynamic>>.from(rows);
  }

  Future<void> hideConversation(String conversationId) async {
    await client.rpc(
      'hide_my_provider_conversation',
      params: {'p_conversation_id': conversationId},
    );
  }
"""
)

repo.write_text(s)

new_messages = r'''import 'package:flutter/material.dart';
import 'core.dart';
import 'provider_repository.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.providerId});
  final String providerId;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = providerRepo.conversations(widget.providerId);
  }

  Future<void> reload() async {
    setState(() => future = providerRepo.conversations(widget.providerId));
    await future;
  }

  Future<void> deleteChat(Map<String,dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fshi bisedën'),
        content: const Text(
          'Biseda do të hiqet nga lista jote. Nëse klienti dërgon një mesazh të ri, ajo do të shfaqet përsëri.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Fshi'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await providerRepo.hideConversation(row['id'].toString());
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <Map<String,dynamic>>[];
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              children: [
                Text(
                  t('messages'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (rows.isEmpty)
                  softCard(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.forum_outlined,
                          size: 38,
                          color: AppColors.navy,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t('noMessages'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                else
                  ...rows.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.white,
                        elevation: 1.3,
                        shadowColor: const Color(0x12000000),
                        borderRadius: BorderRadius.circular(22),
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(
                            16, 8, 4, 8,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.navy.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.navy,
                            ),
                          ),
                          title: Text(
                            t('client'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            c['order_id'] != null
                                ? '#${c['order_id'].toString().substring(0, 8)}'
                                : t('chat'),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') deleteChat(c);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.danger,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Fshi bisedën',
                                      style: TextStyle(
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  conversationId: c['id'].toString(),
                                  title: t('client'),
                                ),
                              ),
                            );
                            if (mounted) reload();
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
  });

  final String conversationId;
  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final text = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final v = text.text.trim();
    if (v.isEmpty) return;
    setState(() => sending = true);
    try {
      await providerRepo.sendMessage(widget.conversationId, v);
      text.clear();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> deleteChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fshi bisedën'),
        content: const Text(
          'Biseda do të hiqet nga lista jote. Mesazhet nuk fshihen nga llogaria e klientit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Fshi'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await providerRepo.hideConversation(widget.conversationId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    final uid = providerRepo.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Fshi bisedën',
            onPressed: deleteChat,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: providerRepo.messages(widget.conversationId),
              builder: (context, snapshot) {
                final rows = snapshot.data ?? const <Map<String,dynamic>>[];
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final m = rows[rows.length - 1 - i];
                    final mine = m['sender_user_id'] == uid;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * .76,
                        ),
                        decoration: BoxDecoration(
                          color: mine ? AppColors.navy : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          (m['body'] ?? '').toString(),
                          style: TextStyle(
                            color: mine ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: text,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: t('typeMessage'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.navy,
                    ),
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
'''
messages.write_text(new_messages)

# Premium provider home with realtime refresh and compact layout.
s = home.read_text()
if "import 'dart:async';" not in s:
    s = "import 'dart:async';\n" + s
new_home = r'''class ProviderHome extends StatefulWidget {
  const ProviderHome({super.key, required this.providerId, required this.onTab});
  final String providerId;
  final ValueChanged<int> onTab;
  @override
  State<ProviderHome> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHome> {
  late Future<_DashboardData> future;
  StreamSubscription? requestSub;
  StreamSubscription? orderSub;
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    future = _load();
    requestSub = providerRepo.requestsStream().listen((_) => refresh(silent: true));
    orderSub = providerRepo.ordersStream(widget.providerId).listen((_) => refresh(silent: true));
  }

  @override
  void dispose() {
    requestSub?.cancel();
    orderSub?.cancel();
    super.dispose();
  }

  Future<_DashboardData> _load() async {
    final values = await Future.wait<dynamic>([
      providerRepo.provider(widget.providerId),
      providerRepo.requests(),
      providerRepo.orders(widget.providerId),
      providerRepo.financeSummary(widget.providerId),
      providerRepo.activeSubscription(widget.providerId),
    ]);
    return _DashboardData(
      Map<String,dynamic>.from(values[0] as Map),
      List<Map<String,dynamic>>.from(values[1] as List),
      List<Map<String,dynamic>>.from(values[2] as List),
      Map<String,dynamic>.from(values[3] as Map),
      values[4] == null ? null : Map<String,dynamic>.from(values[4] as Map),
    );
  }

  Future<void> refresh({bool silent = false}) async {
    if (refreshing || !mounted) return;
    refreshing = true;
    final next = _load();
    setState(() => future = next);
    try { await next; } finally { refreshing = false; }
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => refresh(),
        child: FutureBuilder<_DashboardData>(
          future: future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CustomScrollView(slivers: [
                SliverFillRemaining(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              ]);
            }
            final d = snapshot.data!;
            final p = d.provider;
            final active = d.orders.where((x) => !const ['completed','cancelled'].contains((x['status'] ?? '').toString())).length;
            final sub = d.subscription;
            final subActive = (sub?['status'] ?? '') == 'active';
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 118),
              children: [
                Row(children: [
                  Image.asset('assets/branding/e_mjeshtri_logo.png', width: 118, height: 50, fit: BoxFit.contain),
                  const Spacer(),
                  _HomeIconButton(
                    icon: Icons.notifications_none_rounded,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderNotificationsScreen())),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('dashboard'), style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(width: 9, height: 9, decoration: BoxDecoration(color: p['status'] == 'active' ? AppColors.success : AppColors.warning, shape: BoxShape.circle)),
                      const SizedBox(width: 7),
                      Text(p['status'] == 'active' ? t('active') : t('pendingApproval'), style: Theme.of(context).textTheme.bodyMedium),
                    ]),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(color: subActive ? AppColors.navy.withValues(alpha: .08) : AppColors.warning.withValues(alpha: .10), borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.workspace_premium_rounded, size: 15, color: subActive ? AppColors.navy : AppColors.warning),
                      const SizedBox(width: 5),
                      Text(subActive ? ((sub?['billing_cycle'] ?? sub?['plan_code'] ?? 'Aktiv').toString().toUpperCase()) : 'ABONIM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: subActive ? AppColors.navy : AppColors.warning)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 18),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: [
                    _StatCard(label: t('newRequests'), value: d.requests.length.toString(), icon: Icons.inbox_rounded, bg: const Color(0xFFEAF3FF), fg: const Color(0xFF176FD0), onTap: () => widget.onTab(1)),
                    _StatCard(label: t('activeJobs'), value: active.toString(), icon: Icons.work_rounded, bg: const Color(0xFFFFF2E6), fg: AppColors.orange, onTap: () => widget.onTab(2)),
                    _StatCard(label: t('rating'), value: (p['rating_avg'] ?? 0).toString(), icon: Icons.star_rounded, bg: const Color(0xFFFFF7D9), fg: const Color(0xFFE0A400)),
                    _StatCard(label: t('earnings'), value: (d.finance['net'] as num).toStringAsFixed(0) + ' ALL', icon: Icons.account_balance_wallet_rounded, bg: const Color(0xFFEAF8F1), fg: AppColors.success, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FinancesScreen(providerId: widget.providerId)))),
                  ],
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Text(t('latestRequests'), style: Theme.of(context).textTheme.titleLarge)),
                  TextButton(onPressed: () => widget.onTab(1), child: Text(t('seeAll'))),
                ]),
                const SizedBox(height: 8),
                if (d.requests.isEmpty)
                  softCard(child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.inbox_outlined, color: AppColors.navy)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t('noRequests'), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text('Kërkesat që përputhen me shërbimet dhe zonën tënde shfaqen automatikisht.', style: Theme.of(context).textTheme.bodyMedium),
                    ])),
                  ]))
                else
                  ...d.requests.take(3).map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RequestCard(
                      request: r,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(providerId: widget.providerId, requestId: r['id'].toString()))),
                    ),
                  )),
                const SizedBox(height: 20),
                Text(t('quickActions'), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _Quick(icon: Icons.design_services_rounded, label: t('services'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServicesScreen(providerId: widget.providerId))))),
                  const SizedBox(width: 10),
                  Expanded(child: _Quick(icon: Icons.schedule_rounded, label: t('availability'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AvailabilityScreen(providerId: widget.providerId))))),
                  const SizedBox(width: 10),
                  Expanded(child: _Quick(icon: Icons.verified_user_rounded, label: t('documents'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentsScreen(providerId: widget.providerId))))),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeIconButton extends StatelessWidget {
  const _HomeIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 1,
    shadowColor: const Color(0x12000000),
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 21)),
    ),
  );
}
'''
s = replace_between(s, 'class ProviderHome extends StatefulWidget', 'class _DashboardData', new_home)
s = s.replace("class _DashboardData {\n  _DashboardData(this.provider, this.requests, this.orders, this.finance);", "class _DashboardData {\n  _DashboardData(this.provider, this.requests, this.orders, this.finance, this.subscription);")
s = s.replace("  final Map<String, dynamic> finance;\n}", "  final Map<String, dynamic> finance;\n  final Map<String, dynamic>? subscription;\n}")
s = s.replace("width: 112,", "width: double.infinity,")
home.write_text(s)

# Requests realtime refresh.
s = requests.read_text()
if "import 'dart:async';" not in s:
    s = "import 'dart:async';\n" + s
s = s.replace("class _RequestsScreenState extends State<RequestsScreen> {\n  late Future<List<Map<String, dynamic>>> future;", "class _RequestsScreenState extends State<RequestsScreen> {\n  late Future<List<Map<String, dynamic>>> future;\n  StreamSubscription? sub;")
s = s.replace("    future = providerRepo.requests();\n  }", "    future = providerRepo.requests();\n    sub = providerRepo.requestsStream().listen((_) => refresh());\n  }\n\n  @override\n  void dispose() {\n    sub?.cancel();\n    super.dispose();\n  }")
requests.write_text(s)

# Jobs realtime refresh.
s = jobs.read_text()
if "import 'dart:async';" not in s:
    s = "import 'dart:async';\n" + s
s = s.replace("class _JobsScreenState extends State<JobsScreen>{late Future<List<Map<String,dynamic>>> future;@override void initState(){super.initState();future=providerRepo.orders(widget.providerId);}Future<void> refresh()async{setState(()=>future=providerRepo.orders(widget.providerId));await future;}",
"class _JobsScreenState extends State<JobsScreen>{late Future<List<Map<String,dynamic>>> future;StreamSubscription? sub;@override void initState(){super.initState();future=providerRepo.orders(widget.providerId);sub=providerRepo.ordersStream(widget.providerId).listen((_){refresh();});}@override void dispose(){sub?.cancel();super.dispose();}Future<void> refresh()async{if(!mounted)return;setState(()=>future=providerRepo.orders(widget.providerId));await future;}")
jobs.write_text(s)

# Profile redesign: one subscription entry, brand imagery, weekly availability page.
s = profile.read_text()
if "package:url_launcher/url_launcher.dart" not in s:
    s = s.replace("import 'package:image_picker/image_picker.dart';\n", "import 'package:image_picker/image_picker.dart';\nimport 'package:url_launcher/url_launcher.dart';\n")
s = s.replace("import '../subscriptions/subscription_screen.dart' as subscription_ui;\n", "")
new_profile = r'''class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key, required this.providerId});
  final String providerId;
  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  late Future<Map<String,dynamic>> future;
  late Future<Map<String,dynamic>?> subscriptionFuture;

  @override
  void initState() {
    super.initState();
    future = providerRepo.provider(widget.providerId);
    subscriptionFuture = providerRepo.activeSubscription(widget.providerId);
  }

  Future<void> reload() async {
    setState(() {
      future = providerRepo.provider(widget.providerId);
      subscriptionFuture = providerRepo.activeSubscription(widget.providerId);
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return SafeArea(
      bottom: false,
      child: FutureBuilder<Map<String,dynamic>>(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          final p = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            children: [
              Text(t('profile'), style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 14),
              _ProviderBrandHeader(provider: p),
              const SizedBox(height: 14),
              _Menu(icon: Icons.edit_rounded, title: t('editProfile'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProviderScreen(providerId: widget.providerId, provider: p))).then((_) => reload())),
              _Menu(icon: Icons.design_services_rounded, title: t('services'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServicesScreen(providerId: widget.providerId)))),
              _Menu(icon: Icons.schedule_rounded, title: t('availability'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AvailabilityScreen(providerId: widget.providerId))).then((_) => reload())),
              _Menu(icon: Icons.verified_user_rounded, title: t('documents'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentsScreen(providerId: widget.providerId)))),
              _Menu(icon: Icons.photo_library_rounded, title: t('portfolio'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PortfolioScreen(providerId: widget.providerId)))),
              _Menu(icon: Icons.star_rounded, title: 'Vlerësimet', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderReviewsScreen(providerId: widget.providerId)))),
              _Menu(icon: Icons.account_balance_wallet_rounded, title: t('finances'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FinancesScreen(providerId: widget.providerId)))),
              FutureBuilder<Map<String,dynamic>?>(
                future: subscriptionFuture,
                builder: (context, subSnap) => _SubscriptionMenu(
                  data: subSnap.data,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionScreen(providerId: widget.providerId))).then((_) => reload()),
                ),
              ),
              _Menu(icon: Icons.language_rounded, title: t('language'), onTap: () => context.push('/profile/language')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await providerRepo.signOut();
                  if (context.mounted) context.go('/role');
                },
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: AppColors.danger, side: const BorderSide(color: Color(0x22D84C57)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                icon: const Icon(Icons.logout_rounded),
                label: Text(t('logout')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProviderBrandHeader extends StatelessWidget {
  const _ProviderBrandHeader({required this.provider});
  final Map<String,dynamic> provider;

  @override
  Widget build(BuildContext context) {
    final logoPath = provider['logo_path']?.toString();
    final bannerPath = provider['banner_path']?.toString();
    return Container(
      height: 178,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 7))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(children: [
          Positioned.fill(child: FutureBuilder<String?>(future: providerRepo.providerImageUrl(bannerPath), builder: (context, s) {
            if (s.data != null) return Image.network(s.data!, fit: BoxFit.cover);
            return Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFEAF3FF), Color(0xFFF7F9FC)], begin: Alignment.topLeft, end: Alignment.bottomRight)));
          })),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white.withValues(alpha: .94)])))),
          Positioned(left: 16, bottom: 14, child: FutureBuilder<String?>(future: providerRepo.providerImageUrl(logoPath), builder: (context, s) => Container(
            width: 68, height: 68,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21), border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 16, offset: Offset(0, 5))]),
            clipBehavior: Clip.antiAlias,
            child: s.data == null ? const Icon(Icons.handyman_rounded, color: AppColors.navy, size: 33) : Image.network(s.data!, fit: BoxFit.cover),
          ))),
          Positioned(left: 96, right: 14, bottom: 18, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Flexible(child: Text((provider['display_name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge)), if (_blueTickActive(provider)) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.verified_rounded, color: Colors.blue, size: 19))]),
            const SizedBox(height: 3),
            Text((provider['city'] ?? '').toString(), style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(provider['status'] == 'active' ? T.of(context)('active') : T.of(context)('pendingApproval'), style: TextStyle(fontWeight: FontWeight.w800, color: statusColor((provider['status'] ?? 'pending').toString()))),
          ])),
        ]),
      ),
    );
  }
}

class _SubscriptionMenu extends StatelessWidget {
  const _SubscriptionMenu({required this.data, required this.onTap});
  final Map<String,dynamic>? data;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = (data?['status'] ?? 'none').toString();
    final cycle = (data?['billing_cycle'] ?? data?['plan_code'] ?? '').toString();
    final renewRaw = data?['renews_at'] ?? data?['ends_at'];
    final renew = renewRaw == null ? null : DateTime.tryParse(renewRaw.toString())?.toLocal();
    final subtitle = data == null
        ? 'Pa abonim aktiv'
        : (cycle.isEmpty ? status : cycle.toUpperCase()) + ' • ' + (status == 'active' ? 'Aktiv' : status) + (renew == null ? '' : ' • deri ' + renew.day.toString().padLeft(2,'0') + '/' + renew.month.toString().padLeft(2,'0') + '/' + renew.year.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.workspace_premium_rounded, color: AppColors.navy, size: 21)),
          title: const Text('Abonimi i Mjeshtrit', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
        ),
      ),
    );
  }
}
'''
s = replace_between(s, 'class ProviderProfileScreen', 'class _Menu', new_profile)

new_edit = r'''class EditProviderScreen extends StatefulWidget {
  const EditProviderScreen({super.key, required this.providerId, required this.provider});
  final String providerId;
  final Map<String,dynamic> provider;
  @override
  State<EditProviderScreen> createState() => _EditProviderScreenState();
}

class _EditProviderScreenState extends State<EditProviderScreen> {
  late final TextEditingController name, phone, city, bio, years, radius, fee;
  bool saving = false;
  bool uploadingLogo = false;
  bool uploadingBanner = false;
  String? logoPath;
  String? bannerPath;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    logoPath = p['logo_path']?.toString();
    bannerPath = p['banner_path']?.toString();
    name = TextEditingController(text: (p['display_name'] ?? '').toString());
    phone = TextEditingController(text: (p['phone'] ?? '').toString());
    city = TextEditingController(text: (p['city'] ?? '').toString());
    bio = TextEditingController(text: (p['bio'] ?? '').toString());
    years = TextEditingController(text: (p['years_experience'] ?? '').toString());
    radius = TextEditingController(text: (p['travel_radius_km'] ?? '').toString());
    fee = TextEditingController(text: (p['travel_fee_base'] ?? '').toString());
  }

  Future<void> pickBrand(bool banner) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 86, maxWidth: banner ? 1800 : 900);
    if (image == null || !mounted) return;
    setState(() { if (banner) uploadingBanner = true; else uploadingLogo = true; });
    try {
      final path = await providerRepo.uploadProviderBrandImage(widget.providerId, image, banner: banner);
      if (mounted) setState(() { if (banner) bannerPath = path; else logoPath = path; });
    } finally {
      if (mounted) setState(() { if (banner) uploadingBanner = false; else uploadingLogo = false; });
    }
  }

  Future<void> removeBrand(bool banner) async {
    final current = banner ? bannerPath : logoPath;
    if (current == null || current!.trim().isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(banner ? 'Fshi bannerin' : 'Fshi foton e profilit'),
        content: Text(
          banner
              ? 'Banneri do të hiqet nga profili i Mjeshtrit.'
              : 'Fotoja e profilit do të hiqet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Fshi'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await providerRepo.deleteProviderBrandImage(
      widget.providerId,
      banner: banner,
      storagePath: current,
    );
    if (mounted) {
      setState(() {
        if (banner) {
          bannerPath = null;
        } else {
          logoPath = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t('editProfile')), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Text('Pamja e profilit', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            height: 150,
            decoration: BoxDecoration(color: const Color(0xFFEAF3FF), borderRadius: BorderRadius.circular(24)),
            child: Stack(children: [
              Positioned.fill(child: FutureBuilder<String?>(future: providerRepo.providerImageUrl(bannerPath), builder: (context, s) => ClipRRect(borderRadius: BorderRadius.circular(24), child: s.data == null ? const SizedBox() : Image.network(s.data!, fit: BoxFit.cover)))),
              Positioned(right: 10, top: 10, child: FilledButton.tonalIcon(onPressed: uploadingBanner ? null : () => pickBrand(true), icon: uploadingBanner ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wallpaper_rounded), label: const Text('Banner'))),
              if (bannerPath != null && bannerPath!.trim().isNotEmpty)
                Positioned(
                  right: 10,
                  top: 58,
                  child: IconButton.filledTonal(
                    tooltip: 'Fshi bannerin',
                    onPressed: uploadingBanner ? null : () => removeBrand(true),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                ),
              Positioned(left: 14, bottom: 14, child: FutureBuilder<String?>(future: providerRepo.providerImageUrl(logoPath), builder: (context, s) => Container(width: 72, height: 72, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white, width: 3)), child: s.data == null ? const Icon(Icons.handyman_rounded, color: AppColors.navy) : Image.network(s.data!, fit: BoxFit.cover)))),
              Positioned(left: 94, bottom: 18, child: OutlinedButton.icon(onPressed: uploadingLogo ? null : () => pickBrand(false), icon: uploadingLogo ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_a_photo_rounded), label: const Text('Foto profili'))),
              if (logoPath != null && logoPath!.trim().isNotEmpty)
                Positioned(
                  right: 10,
                  bottom: 14,
                  child: IconButton.filledTonal(
                    tooltip: 'Fshi foton e profilit',
                    onPressed: uploadingLogo ? null : () => removeBrand(false),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 18),
          TextField(controller: name, decoration: InputDecoration(labelText: t('name'))),
          const SizedBox(height: 10),
          TextField(controller: phone, decoration: InputDecoration(labelText: t('phone'))),
          const SizedBox(height: 10),
          TextField(controller: city, decoration: InputDecoration(labelText: t('city'))),
          const SizedBox(height: 10),
          TextField(controller: bio, maxLines: 4, decoration: InputDecoration(labelText: t('bio'))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: years, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('yearsExperience')))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: radius, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('radius')))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: fee, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('travelFee'))),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: saving ? null : () async {
              setState(() => saving = true);
              try {
                await providerRepo.updateProvider(widget.providerId, {
                  'display_name': name.text.trim(),
                  'phone': phone.text.trim(),
                  'city': city.text.trim(),
                  'bio': bio.text.trim(),
                  'years_experience': int.tryParse(years.text),
                  'travel_radius_km': double.tryParse(radius.text),
                  'travel_fee_base': double.tryParse(fee.text),
                });
                if (mounted) Navigator.pop(context);
              } finally {
                if (mounted) setState(() => saving = false);
              }
            },
            child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(t('save')),
          ),
        ],
      ),
    );
  }
}
'''
s = replace_between(s, 'class EditProviderScreen', 'class ServicesScreen', new_edit)

new_availability = r'''class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key, required this.providerId});
  final String providerId;
  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  static const days = ['Hënë','Martë','Mërkurë','Enjte','Premte','Shtunë','Diel'];
  bool loading = true;
  bool saving = false;
  bool acceptsAsap = true;
  late List<_DaySchedule> week;

  @override
  void initState() {
    super.initState();
    week = List.generate(7, (i) => _DaySchedule(i, i < 5, const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 17, minute: 0)));
    load();
  }

  Future<void> load() async {
    final values = await Future.wait<dynamic>([providerRepo.availability(widget.providerId), providerRepo.provider(widget.providerId)]);
    final rows = List<Map<String,dynamic>>.from(values[0] as List);
    final p = Map<String,dynamic>.from(values[1] as Map);
    for (final row in rows) {
      final i = ((row['weekday'] as num?)?.toInt() ?? 0).clamp(0, 6);
      week[i] = _DaySchedule(i, row['is_active'] == true, _parseTime(row['start_time']?.toString(), const TimeOfDay(hour: 8, minute: 0)), _parseTime(row['end_time']?.toString(), const TimeOfDay(hour: 17, minute: 0)));
    }
    if (mounted) setState(() { acceptsAsap = p['accepts_asap'] == true; loading = false; });
  }

  TimeOfDay _parseTime(String? value, TimeOfDay fallback) {
    if (value == null) return fallback;
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? fallback.hour, minute: int.tryParse(parts[1]) ?? fallback.minute);
  }

  String _dbTime(TimeOfDay x) => x.hour.toString().padLeft(2,'0') + ':' + x.minute.toString().padLeft(2,'0') + ':00';

  Future<void> pickTime(int i, bool start) async {
    final current = start ? week[i].start : week[i].end;
    final value = await showTimePicker(context: context, initialTime: current);
    if (value == null || !mounted) return;
    setState(() { if (start) week[i].start = value; else week[i].end = value; });
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await providerRepo.saveWeeklyAvailability(widget.providerId, [
        for (final d in week) {
          'weekday': d.weekday,
          'start_time': _dbTime(d.start),
          'end_time': _dbTime(d.end),
          'is_active': d.active,
        }
      ], acceptsAsap: acceptsAsap);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orari u ruajt.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t('availability')), backgroundColor: Colors.transparent),
      body: loading ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          softCard(color: const Color(0xFFEAF3FF), child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: acceptsAsap,
            onChanged: (v) => setState(() => acceptsAsap = v),
            title: const Text('I disponueshëm për kërkesa të menjëhershme', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Kur është aktiv, qytetarët mund të të gjejnë si mjeshtër i disponueshëm tani.'),
          )),
          const SizedBox(height: 16),
          Text('Orari javor', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...List.generate(7, (i) {
            final d = week[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                  child: Row(children: [
                    Switch.adaptive(value: d.active, onChanged: (v) => setState(() => d.active = v)),
                    const SizedBox(width: 8),
                    SizedBox(width: 72, child: Text(days[i], style: const TextStyle(fontWeight: FontWeight.w800))),
                    const Spacer(),
                    if (d.active) ...[
                      _TimeChip(label: d.start.format(context), onTap: () => pickTime(i, true)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Text('–')),
                      _TimeChip(label: d.end.format(context), onTap: () => pickTime(i, false)),
                    ] else
                      const Text('Jo aktiv', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_rounded), label: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Ruaj orarin')),
        ],
      ),
    );
  }
}

class _DaySchedule {
  _DaySchedule(this.weekday, this.active, this.start, this.end);
  final int weekday;
  bool active;
  TimeOfDay start;
  TimeOfDay end;
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8), decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: .07), borderRadius: BorderRadius.circular(12)), child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.navy))),
  );
}
'''
s = replace_between(s, 'class AvailabilityScreen', 'class DocumentsScreen', new_availability)

new_documents = r'''class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.providerId});
  final String providerId;
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late Future<List<Map<String,dynamic>>> future;
  bool uploading = false;

  static const slots = <(String,String,String)>[
    ('id_card','Kartë ID','Dokumenti bazë i verifikimit'),
    ('license','Licencë / Certifikatë','Licencë profesionale ose certifikatë'),
    ('business','Dokument biznesi / NIPT','Për biznes ose kompani'),
  ];

  @override
  void initState() {
    super.initState();
    future = providerRepo.documents(widget.providerId);
  }

  Future<void> reload() async {
    setState(() => future = providerRepo.documents(widget.providerId));
    await future;
  }

  Map<String,dynamic>? latestFor(
    List<Map<String,dynamic>> rows,
    String type,
  ) {
    for (final row in rows) {
      if ((row['document_type'] ?? '').toString() == type) return row;
    }
    return null;
  }

  Future<void> uploadType(String type) async {
    if (uploading) return;
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf','jpg','jpeg','png'],
    );
    if (picked == null || !mounted) return;
    setState(() => uploading = true);
    try {
      await providerRepo.uploadDocument(widget.providerId, type, picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dokumenti u dërgua për kontroll nga administratori.'),
          ),
        );
      }
      await reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> openDocument(Map<String,dynamic> doc) async {
    final path = (doc['storage_path'] ?? '').toString();
    if (path.isEmpty) return;
    try {
      final url = await providerRepo.signedDocumentUrl(path);
      if (!mounted) return;
      final lower = path.toLowerCase();
      if (lower.endsWith('.pdf')) {
        final ok = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dokumenti nuk u hap dot.')),
          );
        }
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _DocumentPreviewScreen(
            url: url,
            title: _docTitle((doc['document_type'] ?? '').toString()),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  String _docTitle(String type) => switch (type) {
    'id_card' => 'Kartë ID',
    'license' => 'Licencë / Certifikatë',
    'business' => 'Dokument biznesi / NIPT',
    _ => 'Dokument',
  };

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('documents')),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Map<String,dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          final rows = snapshot.data ?? const <Map<String,dynamic>>[];

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              children: [
                softCard(
                  color: const Color(0xFFFFF7E7),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.warning,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mund ta hapësh çdo dokument për ta parë dhe mund ta zëvendësosh. Dokumenti i aprovuar mbetet aktiv derisa administratori të kontrollojë versionin e ri.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final slot in slots)
                  _DocumentSlotCard(
                    title: slot.$2,
                    subtitle: slot.$3,
                    doc: latestFor(rows, slot.$1),
                    busy: uploading,
                    onOpen: (doc) => openDocument(doc),
                    onUpload: () => uploadType(slot.$1),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DocumentSlotCard extends StatelessWidget {
  const _DocumentSlotCard({
    required this.title,
    required this.subtitle,
    required this.doc,
    required this.busy,
    required this.onOpen,
    required this.onUpload,
  });

  final String title;
  final String subtitle;
  final Map<String,dynamic>? doc;
  final bool busy;
  final ValueChanged<Map<String,dynamic>> onOpen;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final status = (doc?['status'] ?? 'missing').toString();
    final color = status == 'approved'
        ? AppColors.success
        : status == 'rejected'
            ? AppColors.danger
            : status == 'pending'
                ? AppColors.warning
                : AppColors.muted;
    final statusText = switch (status) {
      'approved' => 'Aprovuar',
      'rejected' => 'Refuzuar',
      'pending' => 'Në pritje',
      _ => 'Mungon',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x10000000),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (doc != null)
                          OutlinedButton.icon(
                            onPressed: () => onOpen(doc!),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Shiko'),
                          ),
                        FilledButton.tonalIcon(
                          onPressed: busy ? null : onUpload,
                          icon: Icon(
                            doc == null
                                ? Icons.upload_file_rounded
                                : Icons.sync_rounded,
                          ),
                          label: Text(
                            doc == null ? 'Ngarko' : 'Zëvendëso',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentPreviewScreen extends StatelessWidget {
  const _DocumentPreviewScreen({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Center(
        child: InteractiveViewer(
          minScale: .8,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Dokumenti nuk u shfaq dot.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
'''
s = replace_between(s, 'class DocumentsScreen', 'class PortfolioScreen', new_documents)

new_sub = r'''class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, required this.providerId});
  final String providerId;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late Future<Map<String,dynamic>?> future;

  @override
  void initState() {
    super.initState();
    future = providerRepo.activeSubscription(widget.providerId);
  }

  Future<void> reload() async {
    setState(() => future = providerRepo.activeSubscription(widget.providerId));
    await future;
  }

  String cycleLabel(String value) => switch (value) {
    'monthly' => 'Mujor',
    'yearly' => 'Vjetor',
    _ => value,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonimi i Mjeshtrit'),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<Map<String,dynamic>?>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (snap.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Provo përsëri'),
              ),
            );
          }

          final x = snap.data;
          if (x == null) {
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 80),
                  softCard(
                    child: const Column(
                      children: [
                        Icon(
                          Icons.workspace_premium_outlined,
                          size: 42,
                          color: AppColors.navy,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Nuk ka abonim aktiv.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final status = (x['status'] ?? '').toString();
          final cycle =
              (x['billing_cycle'] ?? x['plan_code'] ?? '').toString();
          final planName = (x['plan_name'] ?? '').toString().trim();
          final priceValue =
              (x['price_amount'] ?? x['plan_price_amount'] ?? x['monthly_price'] ?? 0);
          final price = priceValue is num
              ? priceValue.toDouble()
              : double.tryParse(priceValue.toString()) ?? 0;
          final renewRaw = x['renews_at'] ?? x['ends_at'];
          final renew = renewRaw == null
              ? null
              : DateTime.tryParse(renewRaw.toString())?.toLocal();
          final blueActive = x['blue_tick_active'] == true;
          final effective = x['effective_active'] == true;

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A4B95), Color(0xFF176FD0)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        planName.isEmpty
                            ? 'Abonim ${cycleLabel(cycle)}'
                            : planName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        effective ? 'Aktiv' : status,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .88),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${price.toStringAsFixed(0)} ${(x['currency'] ?? 'ALL')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        color: AppColors.success,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Të dhënat merren direkt nga abonimi i aprovuar në panelin e Adminit.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                softCard(
                  child: Column(
                    children: [
                      _SubscriptionInfo(
                        label: 'Statusi',
                        value: effective ? 'Aktiv' : status,
                      ),
                      const Divider(height: 24),
                      _SubscriptionInfo(
                        label: 'Plani',
                        value: planName.isEmpty ? cycleLabel(cycle) : planName,
                      ),
                      const Divider(height: 24),
                      _SubscriptionInfo(
                        label: 'Cikli',
                        value: cycleLabel(cycle),
                      ),
                      const Divider(height: 24),
                      _SubscriptionInfo(
                        label: 'Vlen deri',
                        value: renew == null
                            ? '-'
                            : '${renew.day.toString().padLeft(2,'0')}/${renew.month.toString().padLeft(2,'0')}/${renew.year}',
                      ),
                      const Divider(height: 24),
                      _SubscriptionInfo(
                        label: 'Tick blu',
                        value: blueActive ? 'Aktiv' : 'Jo aktiv',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SubscriptionInfo extends StatelessWidget {
  const _SubscriptionInfo({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}
'''
idx = s.index('class SubscriptionScreen')
s = s[:idx] + new_sub + '\n'

new_portfolio_reviews = r'''class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key, required this.providerId});
  final String providerId;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = providerRepo.portfolio(widget.providerId);
  }

  Future<void> reload() async {
    setState(() => future = providerRepo.portfolio(widget.providerId));
    await future;
  }

  Future<void> deletePhoto(Map<String,dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fshi foton'),
        content: const Text('Kjo foto do të hiqet nga portofoli i punëve.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Fshi'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await providerRepo.deletePortfolioImage(
      widget.providerId,
      row['id'].toString(),
      (row['storage_path'] ?? '').toString(),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(T.of(context)('portfolio')),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pick,
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: Text(T.of(context)('uploadPhoto')),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <Map<String,dynamic>>[];
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (rows.isEmpty) {
            return const Center(
              child: Text('Nuk ka ende foto pune.'),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<String>(
                    future: providerRepo.signedProviderMedia(
                      row['storage_path'].toString(),
                    ),
                    builder: (context, urlSnapshot) => ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: urlSnapshot.hasData
                          ? Image.network(
                              urlSnapshot.data!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.white,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    right: 7,
                    top: 7,
                    child: IconButton.filled(
                      tooltip: 'Fshi',
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Colors.black.withValues(alpha: .55),
                      ),
                      onPressed: () => deletePhoto(row),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (x == null) return;
    await providerRepo.uploadPortfolioImage(widget.providerId, x);
    await reload();
  }
}

class ProviderReviewsScreen extends StatefulWidget {
  const ProviderReviewsScreen({super.key, required this.providerId});
  final String providerId;

  @override
  State<ProviderReviewsScreen> createState() => _ProviderReviewsScreenState();
}

class _ProviderReviewsScreenState extends State<ProviderReviewsScreen> {
  late Future<List<Map<String,dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = providerRepo.reviews(widget.providerId);
  }

  Future<void> reload() async {
    setState(() => future = providerRepo.reviews(widget.providerId));
    await future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Vlerësimet'),
      backgroundColor: Colors.transparent,
    ),
    body: FutureBuilder<List<Map<String,dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String,dynamic>>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        if (rows.isEmpty) {
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 80),
                softCard(
                  child: const Column(
                    children: [
                      Icon(
                        Icons.star_outline_rounded,
                        size: 42,
                        color: AppColors.navy,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Nuk ka ende vlerësime nga klientët.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final avg = rows.fold<double>(
              0,
              (sum, row) =>
                  sum + ((row['rating'] as num?)?.toDouble() ?? 0),
            ) /
            rows.length;

        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            children: [
              softCard(
                color: const Color(0xFFFFF8E3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.warning,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${avg.toStringAsFixed(1)} / 5',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${rows.length} vlerësime',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: softCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < ((row['rating'] as num?)?.toInt() ?? 0)
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: AppColors.warning,
                                size: 21,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateTime.tryParse(
                                        (row['created_at'] ?? '').toString(),
                                      ) ==
                                      null
                                  ? ''
                                  : () {
                                      final d = DateTime.parse(
                                        row['created_at'].toString(),
                                      ).toLocal();
                                      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
                                    }(),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if ((row['comment'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Text(
                            row['comment'].toString(),
                            style: const TextStyle(height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
'''
s = replace_between(
  s,
  'class PortfolioScreen',
  'class FinancesScreen',
  new_portfolio_reviews,
)

profile.write_text(s)

# Faster bottom-nav feedback.
s = shell.read_text()
s = s.replace('duration: const Duration(milliseconds: 180)', 'duration: const Duration(milliseconds: 90)')
s = s.replace('onTap: () => setState(() => index = i),', 'onTap: () { if (index != i) setState(() => index = i); },')
shell.write_text(s)


# PROFESSIONAL CREDENTIALS V1.9
repo_text = repo.read_text()
credential_repo_insert = r'''
  Future<List<Map<String,dynamic>>> professionalDocuments(String providerId) async {
    final rows = await client
        .from('provider_documents')
        .select('*,vocational_schools(name,city),study_programs(name)')
        .eq('provider_id', providerId)
        .order('created_at', ascending: false);
    return List<Map<String,dynamic>>.from(rows);
  }

  Future<Map<String,dynamic>> professionalCredentialCatalog() async {
    final results = await Future.wait<dynamic>([
      client
          .from('vocational_schools')
          .select('id,name,city,institution_type')
          .eq('is_active', true)
          .order('city')
          .order('name'),
      client
          .from('study_programs')
          .select('id,name,category')
          .eq('is_active', true)
          .order('name'),
      client
          .from('school_programs')
          .select('school_id,program_id,duration_label,credential_awarded')
          .eq('is_active', true),
    ]);
    return {
      'schools': List<Map<String,dynamic>>.from(results[0] as List),
      'programs': List<Map<String,dynamic>>.from(results[1] as List),
      'school_programs': List<Map<String,dynamic>>.from(results[2] as List),
    };
  }

  Future<void> uploadProfessionalCredential(
    String providerId,
    dynamic file, {
    String? schoolId,
    required String studyCity,
    String? customSchoolName,
    String? programId,
    String? customProgramName,
    required String credentialType,
    String? credentialName,
    int? graduationYear,
    String? credentialNumber,
    DateTime? issueDate,
    DateTime? expiresAt,
  }) async {
    final approved = await client
        .from('provider_documents')
        .select('id')
        .eq('provider_id', providerId)
        .eq('document_type', 'license')
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final originalName = file.name.toString();
    final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final lower = safeName.toLowerCase();
    final contentType = lower.endsWith('.pdf')
        ? 'application/pdf'
        : lower.endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
    final path = providerId +
        '/credentials/' +
        DateTime.now().millisecondsSinceEpoch.toString() +
        '_' +
        safeName;
    final bytes = await file.readAsBytes();
    var uploaded = false;
    try {
      await client.storage.from('provider-documents').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(upsert: false, contentType: contentType),
      );
      uploaded = true;
      String? dateOnly(DateTime? value) {
        if (value == null) return null;
        return value.year.toString().padLeft(4, '0') +
            '-' +
            value.month.toString().padLeft(2, '0') +
            '-' +
            value.day.toString().padLeft(2, '0');
      }

      await client.from('provider_documents').insert({
        'provider_id': providerId,
        'document_type': 'license',
        'storage_path': path,
        'status': 'pending',
        'credential_type': credentialType.trim(),
        'credential_name': credentialName?.trim().isEmpty == true
            ? null
            : credentialName?.trim(),
        'school_id': schoolId,
        'custom_school_name': customSchoolName?.trim().isEmpty == true
            ? null
            : customSchoolName?.trim(),
        'study_city': studyCity.trim(),
        'program_id': programId,
        'custom_program_name': customProgramName?.trim().isEmpty == true
            ? null
            : customProgramName?.trim(),
        'graduation_year': graduationYear,
        'credential_number': credentialNumber?.trim().isEmpty == true
            ? null
            : credentialNumber?.trim(),
        'issue_date': dateOnly(issueDate),
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'replaces_document_id': approved?['id'],
      });
    } catch (_) {
      if (uploaded) {
        try {
          await client.storage.from('provider-documents').remove([path]);
        } catch (_) {}
      }
      rethrow;
    }
  }
'''
marker = '\n  Future<List<Map<String,dynamic>>> notifications() async {'
if 'professionalCredentialCatalog()' not in repo_text:
    repo_text = repo_text.replace(marker, '\n' + credential_repo_insert + marker)
repo.write_text(repo_text)

profile_text = profile.read_text()
new_documents_v19 = r'''class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.providerId});
  final String providerId;
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late Future<List<Map<String,dynamic>>> future;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    future = providerRepo.professionalDocuments(widget.providerId);
  }

  Future<void> reload() async {
    setState(() => future = providerRepo.professionalDocuments(widget.providerId));
    await future;
  }

  Map<String,dynamic>? latestFor(
    List<Map<String,dynamic>> rows,
    String type, {
    String? status,
  }) {
    for (final row in rows) {
      if ((row['document_type'] ?? '').toString() == type &&
          (status == null || (row['status'] ?? '').toString() == status)) {
        return row;
      }
    }
    return null;
  }

  Future<void> uploadType(String type) async {
    if (uploading) return;
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf','jpg','jpeg','png'],
    );
    if (picked == null || !mounted) return;
    setState(() => uploading = true);
    try {
      await providerRepo.uploadDocument(widget.providerId, type, picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dokumenti u dërgua për kontroll nga administratori.'),
          ),
        );
      }
      await reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> openCredentialForm() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfessionalCredentialFormScreen(
          providerId: widget.providerId,
        ),
      ),
    );
    if (saved == true && mounted) await reload();
  }

  Future<void> openDocument(Map<String,dynamic> doc) async {
    final path = (doc['storage_path'] ?? '').toString();
    if (path.isEmpty) return;
    try {
      final url = await providerRepo.signedDocumentUrl(path);
      if (!mounted) return;
      final lower = path.toLowerCase();
      if (lower.endsWith('.pdf')) {
        final ok = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dokumenti nuk u hap dot.')),
          );
        }
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _DocumentPreviewScreen(
            url: url,
            title: _docTitle((doc['document_type'] ?? '').toString()),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  String _docTitle(String type) => switch (type) {
    'id_card' => 'Kartë ID',
    'license' => 'Licencë / Certifikatë',
    'business' => 'Dokument biznesi / NIPT',
    _ => 'Dokument',
  };

  String? _credentialSummary(Map<String,dynamic>? doc) {
    if (doc == null) return null;
    final schoolRel = doc['vocational_schools'];
    final programRel = doc['study_programs'];
    final school = schoolRel is Map
        ? (schoolRel['name'] ?? '').toString()
        : (doc['custom_school_name'] ?? '').toString();
    final program = programRel is Map
        ? (programRel['name'] ?? '').toString()
        : (doc['custom_program_name'] ?? '').toString();
    final city = (doc['study_city'] ?? '').toString();
    final parts = [program, school, city].where((x) => x.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('documents')),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Map<String,dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          final rows = snapshot.data ?? const <Map<String,dynamic>>[];
          final latestLicense = latestFor(rows, 'license');
          final approvedLicense = latestFor(rows, 'license', status: 'approved');
          final pendingLicense = latestFor(rows, 'license', status: 'pending');

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              children: [
                softCard(
                  color: const Color(0xFFFFF7E7),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.warning,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Licenca ose certifikata lidhet me shkollën, qytetin dhe programin e studimit. Nëse diçka mungon në listë, zgjidh “Tjetër” dhe shkruaje manualisht. Kualifikimi shfaqet te qytetarët vetëm pasi aprovohet nga administratori.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DocumentSlotCard(
                  title: 'Kartë ID',
                  subtitle: 'Dokumenti bazë i verifikimit',
                  doc: latestFor(rows, 'id_card'),
                  busy: uploading,
                  onOpen: (doc) => openDocument(doc),
                  onUpload: () => uploadType('id_card'),
                ),
                _DocumentSlotCard(
                  title: 'Licencë / Certifikatë',
                  subtitle: 'Kualifikim profesional, shkollë dhe program studimi',
                  doc: pendingLicense ?? latestLicense,
                  detail: _credentialSummary(pendingLicense ?? latestLicense),
                  approvedStillActive:
                      pendingLicense != null && approvedLicense != null,
                  busy: uploading,
                  onOpen: (doc) => openDocument(doc),
                  onUpload: openCredentialForm,
                ),
                _DocumentSlotCard(
                  title: 'Dokument biznesi / NIPT',
                  subtitle: 'Për biznes ose kompani',
                  doc: latestFor(rows, 'business'),
                  busy: uploading,
                  onOpen: (doc) => openDocument(doc),
                  onUpload: () => uploadType('business'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ProfessionalCredentialFormScreen extends StatefulWidget {
  const ProfessionalCredentialFormScreen({
    super.key,
    required this.providerId,
  });
  final String providerId;

  @override
  State<ProfessionalCredentialFormScreen> createState() =>
      _ProfessionalCredentialFormScreenState();
}

class _ProfessionalCredentialFormScreenState
    extends State<ProfessionalCredentialFormScreen> {
  bool loading = true;
  bool saving = false;
  Map<String,dynamic> catalog = const {};
  String? cityValue;
  String? schoolId;
  String? programId;
  String credentialType = 'Certifikatë profesionale';
  bool customCity = false;
  bool customSchool = false;
  bool customProgram = false;
  bool customCredentialType = false;
  dynamic pickedFile;
  DateTime? issueDate;
  DateTime? expiryDate;

  final cityController = TextEditingController();
  final schoolController = TextEditingController();
  final programController = TextEditingController();
  final credentialTypeController = TextEditingController();
  final credentialNameController = TextEditingController();
  final graduationYearController = TextEditingController();
  final credentialNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    cityController.dispose();
    schoolController.dispose();
    programController.dispose();
    credentialTypeController.dispose();
    credentialNameController.dispose();
    graduationYearController.dispose();
    credentialNumberController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data = await providerRepo.professionalCredentialCatalog();
      if (mounted) setState(() => catalog = data);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String,dynamic>> get schools =>
      List<Map<String,dynamic>>.from(catalog['schools'] as List? ?? const []);
  List<Map<String,dynamic>> get programs =>
      List<Map<String,dynamic>>.from(catalog['programs'] as List? ?? const []);
  List<Map<String,dynamic>> get links =>
      List<Map<String,dynamic>>.from(catalog['school_programs'] as List? ?? const []);

  List<String> get cities {
    final values = schools
        .map((x) => (x['city'] ?? '').toString())
        .where((x) => x.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<Map<String,dynamic>> get filteredSchools {
    if (customCity || cityValue == null) return const [];
    return schools.where((x) => (x['city'] ?? '').toString() == cityValue).toList();
  }

  List<Map<String,dynamic>> get filteredPrograms {
    if (schoolId == null) return programs;
    final ids = links
        .where((x) => (x['school_id'] ?? '').toString() == schoolId)
        .map((x) => (x['program_id'] ?? '').toString())
        .toSet();
    if (ids.isEmpty) return programs;
    return programs.where((x) => ids.contains((x['id'] ?? '').toString())).toList();
  }

  String dateLabel(DateTime? value) {
    if (value == null) return 'Nuk është vendosur';
    return value.day.toString().padLeft(2,'0') +
        '/' +
        value.month.toString().padLeft(2,'0') +
        '/' +
        value.year.toString();
  }

  Future<void> pickDocument() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf','jpg','jpeg','png'],
    );
    if (file == null) return;
    final length = file.lengthSync() ?? await file.length();
    const maxBytes = 8 * 1024 * 1024;
    if (length == null || length <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokumenti nuk u lexua dot.')),
        );
      }
      return;
    }
    if (length > maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokumenti duhet të jetë më i vogël se 8 MB.')),
        );
      }
      return;
    }
    if (mounted) setState(() => pickedFile = file);
  }

  Future<void> chooseDate(bool expiry) async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: expiry ? (expiryDate ?? now) : (issueDate ?? now),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 20),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (expiry) {
        expiryDate = value;
      } else {
        issueDate = value;
      }
    });
  }

  Future<void> save() async {
    final city = customCity ? cityController.text.trim() : (cityValue ?? '').trim();
    final customSchoolName = customSchool ? schoolController.text.trim() : '';
    final customProgramName = customProgram ? programController.text.trim() : '';
    final type = customCredentialType
        ? credentialTypeController.text.trim()
        : credentialType.trim();
    final year = int.tryParse(graduationYearController.text.trim());

    if (city.isEmpty ||
        (!customSchool && schoolId == null) ||
        (customSchool && customSchoolName.isEmpty) ||
        (!customProgram && programId == null) ||
        (customProgram && customProgramName.isEmpty) ||
        type.isEmpty ||
        year == null ||
        pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Plotëso qytetin, shkollën, programin, llojin e dokumentit, vitin dhe ngarko dokumentin.',
          ),
        ),
      );
      return;
    }

    setState(() => saving = true);
    try {
      await providerRepo.uploadProfessionalCredential(
        widget.providerId,
        pickedFile,
        schoolId: customSchool ? null : schoolId,
        studyCity: city,
        customSchoolName: customSchool ? customSchoolName : null,
        programId: customProgram ? null : programId,
        customProgramName: customProgram ? customProgramName : null,
        credentialType: type,
        credentialName: credentialNameController.text,
        graduationYear: year,
        credentialNumber: credentialNumberController.text,
        issueDate: issueDate,
        expiresAt: expiryDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kualifikimi u dërgua për verifikim nga administratori.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shto kualifikim profesional'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          softCard(
            color: const Color(0xFFEAF3FF),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.navy),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Këto të dhëna nuk shfaqen si të verifikuara derisa administratori të kontrollojë dokumentin.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: customCity ? '__other__' : cityValue,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Qyteti ku ke studiuar'),
            items: [
              ...cities.map((x) => DropdownMenuItem(value: x, child: Text(x))),
              const DropdownMenuItem(value: '__other__', child: Text('Tjetër')),
            ],
            onChanged: (value) {
              setState(() {
                customCity = value == '__other__';
                cityValue = customCity ? null : value;
                schoolId = null;
                customSchool = false;
                programId = null;
                customProgram = false;
              });
            },
          ),
          if (customCity) ...[
            const SizedBox(height: 10),
            TextField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'Shkruaj qytetin'),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: customSchool ? '__other__' : schoolId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Shkolla / Qendra'),
            items: [
              ...filteredSchools.map(
                (x) => DropdownMenuItem(
                  value: x['id'].toString(),
                  child: Text((x['name'] ?? '').toString(), overflow: TextOverflow.ellipsis),
                ),
              ),
              const DropdownMenuItem(value: '__other__', child: Text('Tjetër')),
            ],
            onChanged: cityValue == null && !customCity
                ? null
                : (value) {
                    setState(() {
                      customSchool = value == '__other__';
                      schoolId = customSchool ? null : value;
                      programId = null;
                      customProgram = false;
                    });
                  },
          ),
          if (customSchool) ...[
            const SizedBox(height: 10),
            TextField(
              controller: schoolController,
              decoration: const InputDecoration(labelText: 'Shkruaj emrin e shkollës / qendrës'),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: customProgram ? '__other__' : programId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Programi i studimit / Zanati'),
            items: [
              ...filteredPrograms.map(
                (x) => DropdownMenuItem(
                  value: x['id'].toString(),
                  child: Text((x['name'] ?? '').toString(), overflow: TextOverflow.ellipsis),
                ),
              ),
              const DropdownMenuItem(value: '__other__', child: Text('Tjetër')),
            ],
            onChanged: (value) {
              setState(() {
                customProgram = value == '__other__';
                programId = customProgram ? null : value;
              });
            },
          ),
          if (customProgram) ...[
            const SizedBox(height: 10),
            TextField(
              controller: programController,
              decoration: const InputDecoration(labelText: 'Shkruaj programin / zanatin'),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: customCredentialType ? '__other__' : credentialType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Dokumenti që ke marrë'),
            items: const [
              DropdownMenuItem(value: 'Certifikatë profesionale', child: Text('Certifikatë profesionale')),
              DropdownMenuItem(value: 'Diplomë profesionale', child: Text('Diplomë profesionale')),
              DropdownMenuItem(value: 'Licencë profesionale', child: Text('Licencë profesionale')),
              DropdownMenuItem(value: 'Certifikatë kursi', child: Text('Certifikatë kursi')),
              DropdownMenuItem(value: 'Kualifikim pas të mesmes', child: Text('Kualifikim pas të mesmes')),
              DropdownMenuItem(value: '__other__', child: Text('Tjetër')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                customCredentialType = value == '__other__';
                if (!customCredentialType) credentialType = value;
              });
            },
          ),
          if (customCredentialType) ...[
            const SizedBox(height: 10),
            TextField(
              controller: credentialTypeController,
              decoration: const InputDecoration(labelText: 'Shkruaj llojin e dokumentit'),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: credentialNameController,
            decoration: const InputDecoration(
              labelText: 'Emri i diplomës / certifikatës (opsionale)',
              hintText: 'P.sh. Certifikatë Profesionale Niveli III',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: graduationYearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Viti i përfundimit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: credentialNumberController,
                  decoration: const InputDecoration(labelText: 'Nr. dokumentit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => chooseDate(false),
                  icon: const Icon(Icons.event_rounded),
                  label: Text('Lëshuar: ' + dateLabel(issueDate)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => chooseDate(true),
                  icon: const Icon(Icons.event_busy_rounded),
                  label: Text('Skadon: ' + dateLabel(expiryDate)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: pickDocument,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(
              pickedFile == null
                  ? 'Ngarko diplomën / certifikatën'
                  : pickedFile.name.toString(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(saving ? 'Po dërgohet...' : 'Dërgo për verifikim'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentSlotCard extends StatelessWidget {
  const _DocumentSlotCard({
    required this.title,
    required this.subtitle,
    required this.doc,
    required this.busy,
    required this.onOpen,
    required this.onUpload,
    this.detail,
    this.approvedStillActive = false,
  });

  final String title;
  final String subtitle;
  final Map<String,dynamic>? doc;
  final bool busy;
  final ValueChanged<Map<String,dynamic>> onOpen;
  final VoidCallback onUpload;
  final String? detail;
  final bool approvedStillActive;

  @override
  Widget build(BuildContext context) {
    final status = (doc?['status'] ?? 'missing').toString();
    final color = status == 'approved'
        ? AppColors.success
        : status == 'rejected'
            ? AppColors.danger
            : status == 'pending'
                ? AppColors.warning
                : AppColors.muted;
    final statusText = switch (status) {
      'approved' => 'Aprovuar',
      'rejected' => 'Refuzuar',
      'pending' => 'Në verifikim',
      'replaced' => 'Zëvendësuar',
      _ => 'Mungon',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x10000000),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    if (detail != null && detail!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        detail!,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      statusText,
                      style: TextStyle(color: color, fontWeight: FontWeight.w800),
                    ),
                    if (approvedStillActive) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Kualifikimi i aprovuar më parë mbetet aktiv derisa të kontrollohet ky version.',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (doc != null)
                          OutlinedButton.icon(
                            onPressed: () => onOpen(doc!),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Shiko'),
                          ),
                        FilledButton.tonalIcon(
                          onPressed: busy ? null : onUpload,
                          icon: Icon(
                            doc == null
                                ? Icons.upload_file_rounded
                                : Icons.sync_rounded,
                          ),
                          label: Text(doc == null ? 'Ngarko' : 'Shto / Zëvendëso'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentPreviewScreen extends StatelessWidget {
  const _DocumentPreviewScreen({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Center(
        child: InteractiveViewer(
          minScale: .8,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Dokumenti nuk u shfaq dot.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
'''
profile_text = replace_between(
  profile_text,
  'class DocumentsScreen',
  'class PortfolioScreen',
  new_documents_v19,
)
profile.write_text(profile_text)

marketplace = root / 'lib/features/marketplace/marketplace_repository.dart'
market_text = marketplace.read_text()
if 'verifiedCredentials(String providerId)' not in market_text:
    verified_method = r'''
  Future<List<Map<String,dynamic>>> verifiedCredentials(String providerId) async {
    final raw = await client.rpc(
      'provider_verified_credentials',
      params: {'p_provider_id': providerId},
    );
    if (raw is! List) return const <Map<String,dynamic>>[];
    return raw
        .whereType<Map>()
        .map((x) => Map<String,dynamic>.from(x))
        .toList();
  }

'''
    market_text = market_text.replace(
      '  Future<bool> isFavorite(String providerId) async {',
      verified_method + '  Future<bool> isFavorite(String providerId) async {',
      1,
    )
marketplace.write_text(market_text)

public_profile = root / 'lib/features/providers/provider_screens.dart'
public_text = public_profile.read_text()
credential_ui = r'''
              FutureBuilder<List<Map<String,dynamic>>>(
                future: repo.verifiedCredentials(widget.providerId),
                builder: (context, credentialSnap) {
                  final credentials =
                      credentialSnap.data ?? const <Map<String,dynamic>>[];
                  if (credentials.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arsim & Kualifikime',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      ...credentials.map((credential) {
                        final program =
                            (credential['program_name'] ?? '').toString();
                        final school =
                            (credential['school_name'] ?? '').toString();
                        final city = (credential['city'] ?? '').toString();
                        final type =
                            (credential['credential_type'] ?? 'Kualifikim profesional').toString();
                        final year = credential['graduation_year'];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: .06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: .18),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Kualifikim profesional i verifikuar',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (program.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          program,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                      if (school.isNotEmpty || city.isNotEmpty)
                                        Text(
                                          [school, city]
                                              .where((x) => x.isNotEmpty)
                                              .join(' • '),
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        year == null
                                            ? type
                                            : type + ' • ' + year.toString(),
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                    ],
                  );
                },
              ),
'''
services_marker = """              const SizedBox(height: 24),
              Text(
                strings.t('services'),"""
if 'Kualifikim profesional i verifikuar' not in public_text:
    public_text = public_text.replace(
      services_marker,
      credential_ui + services_marker,
      1,
    )
public_profile.write_text(public_text)
