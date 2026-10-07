import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../marketplace/marketplace_repository.dart';
import '../requests/request_flow.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  late Future<List<Map<String, dynamic>>> requestFuture;
  late Future<List<Map<String, dynamic>>> orderFuture;
  Timer? refreshTimer;

  MarketplaceRepository get repo => ref.read(marketplaceRepositoryProvider);

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 4, vsync: this);
    requestFuture = repo.activityRequests();
    orderFuture = repo.orders();
    refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) reload(silent: true);
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    tabs.dispose();
    super.dispose();
  }

  Future<void> reload({bool silent = false}) async {
    final nextRequests = repo.activityRequests();
    final nextOrders = repo.orders();
    if (mounted) {
      setState(() {
        requestFuture = nextRequests;
        orderFuture = nextOrders;
      });
    }
    if (!silent) {
      await Future.wait([nextRequests, nextOrders]);
    }
  }

  List<Map<String, dynamic>> _activeRequests(
    List<Map<String, dynamic>> rows,
  ) =>
      rows
          .where((r) => const {
                'published',
                'searching',
                'offers_received',
              }.contains((r['status'] ?? '').toString()))
          .toList();

  List<Map<String, dynamic>> _drafts(List<Map<String, dynamic>> rows) =>
      rows.where((r) => r['status'] == 'draft').toList();

  List<Map<String, dynamic>> _activeOrders(List<Map<String, dynamic>> rows) =>
      rows
          .where((o) => !const {'completed', 'cancelled'}
              .contains((o['status'] ?? '').toString()))
          .toList();

  List<Map<String, dynamic>> _historyOrders(List<Map<String, dynamic>> rows) =>
      rows
          .where((o) => const {'completed', 'cancelled'}
              .contains((o['status'] ?? '').toString()))
          .toList();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text(
              s.t('serviceActivity'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TabBar(
              controller: tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: s.t('serviceRequests')),
                Tab(text: s.t('activeJobs')),
                Tab(text: s.t('history')),
                Tab(text: s.t('drafts')),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: Future.wait([requestFuture, orderFuture]),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: FilledButton.icon(
                      onPressed: () => reload(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(s.t('retry')),
                    ),
                  );
                }

                final requests =
                    List<Map<String, dynamic>>.from(snap.data![0] as List);
                final orders =
                    List<Map<String, dynamic>>.from(snap.data![1] as List);

                return TabBarView(
                  controller: tabs,
                  children: [
                    _RequestList(
                      items: _activeRequests(requests),
                      emptyTitle: s.t('noServiceRequests'),
                      onRefresh: reload,
                    ),
                    _OrderList(
                      items: _activeOrders(orders),
                      emptyTitle: s.t('noActiveJobs'),
                      onRefresh: reload,
                    ),
                    _OrderList(
                      items: _historyOrders(orders),
                      emptyTitle: s.t('noHistory'),
                      onRefresh: reload,
                    ),
                    _RequestList(
                      items: _drafts(requests),
                      emptyTitle: s.t('noDrafts'),
                      onRefresh: reload,
                      drafts: true,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.items,
    required this.emptyTitle,
    required this.onRefresh,
    this.drafts = false,
  });

  final List<Map<String, dynamic>> items;
  final String emptyTitle;
  final Future<void> Function({bool silent}) onRefresh;
  final bool drafts;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => onRefresh(silent: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            const SizedBox(height: 50),
            EmptyState(
              icon: drafts
                  ? Icons.edit_note_rounded
                  : Icons.assignment_outlined,
              title: emptyTitle,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => onRefresh(silent: false),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _RequestActivityCard(
          request: items[i],
          draft: drafts,
        ),
      ),
    );
  }
}

class _RequestActivityCard extends StatelessWidget {
  const _RequestActivityCard({
    required this.request,
    required this.draft,
  });

  final Map<String, dynamic> request;
  final bool draft;

  List<Map<String, dynamic>> get currentOffers {
    final raw = request['offers'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((x) => Map<String, dynamic>.from(x))
        .where((x) =>
            x['is_current'] == true &&
            (x['status'] ?? '').toString() == 'submitted')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final category =
        (request['service_categories'] as Map?)?.cast<String, dynamic>() ?? {};
    final offers = currentOffers;
    final totals = offers
        .map((x) => (x['total_amount'] as num?)?.toDouble())
        .whereType<double>()
        .toList()
      ..sort();
    final best = totals.isEmpty ? null : totals.first;
    final status = (request['status'] ?? '').toString();

    void open() {
      final id = request['id'].toString();
      if (!draft && offers.isNotEmpty) {
        context.push('/request/${id}/offers');
      } else {
        context.push('/request/${id}/summary');
      }
    }

    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x12000000),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.home_repair_service_rounded,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translatedName(
                            category,
                            Localizations.localeOf(context).languageCode,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          (request['city'] ?? '').toString(),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  _RequestStatusPill(status: status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                (request['description'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 13),
              if (draft)
                Row(
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.t('continueDraft'),
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                )
              else if (offers.isEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      size: 18,
                      color: AppColors.orange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.t('waitingOffers'),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_offer_rounded,
                        color: AppColors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${offers.length} ${s.t('offers').toLowerCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.blue,
                        ),
                      ),
                      if (best != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${s.t('fromPrice')} ${best.toStringAsFixed(0)} ALL',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        s.t('viewOffers'),
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.blue,
                        size: 20,
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

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.items,
    required this.emptyTitle,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> items;
  final String emptyTitle;
  final Future<void> Function({bool silent}) onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => onRefresh(silent: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            const SizedBox(height: 50),
            EmptyState(
              icon: Icons.work_outline_rounded,
              title: emptyTitle,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => onRefresh(silent: false),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _OrderCard(order: items[i]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final p =
        (order['providers'] as Map?)?.cast<String, dynamic>() ?? {};
    final r =
        (order['service_requests'] as Map?)?.cast<String, dynamic>() ?? {};
    final total = (order['current_total'] as num?)?.toDouble() ?? 0;

    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x12000000),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/orders/${order['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.handyman_rounded,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p['display_name'] ?? '').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (r['description'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _StatusPill(
                          status: (order['status'] ?? '').toString(),
                        ),
                        const Spacer(),
                        Text(
                          '${total.toStringAsFixed(0)} ${order['currency'] ?? 'ALL'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestStatusPill extends StatelessWidget {
  const _RequestStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final (text, color) = switch (status) {
      'offers_received' => (s.t('offersReceived'), AppColors.blue),
      'searching' => (s.t('searching'), AppColors.orange),
      'published' => (s.t('published'), AppColors.success),
      'draft' => (s.t('drafts'), AppColors.muted),
      'cancelled' => (s.t('cancelled'), AppColors.danger),
      'expired' => (s.t('expired'), AppColors.muted),
      _ => (status, AppColors.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final (text, color) = switch (status) {
      'confirmed' => (s.t('statusConfirmed'), AppColors.blue),
      'provider_on_way' => (s.t('statusOnWay'), AppColors.orange),
      'arrived' => (s.t('statusArrived'), AppColors.orange),
      'in_progress' => (s.t('statusInProgress'), AppColors.orange),
      'completion_pending' =>
        (s.t('statusCompletionPending'), AppColors.orange),
      'completed' => (s.t('completed'), AppColors.success),
      'cancelled' => (s.t('cancelled'), AppColors.danger),
      _ => (status, AppColors.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

bool hasActiveBlueTick(Map<String, dynamic> provider) {
  if (provider['is_verified'] != true) return false;
  final raw = provider['blue_tick_expires_at']?.toString();
  if (raw == null || raw.trim().isEmpty) return true;
  final expires = DateTime.tryParse(raw);
  return expires == null || expires.isAfter(DateTime.now().toUtc());
}

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late Future<Map<String, dynamic>> future;
  StreamSubscription<Map<String, dynamic>?>? statusSubscription;
  String? observedStatus;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(marketplaceRepositoryProvider);
    future = repo.order(widget.orderId);
    statusSubscription = repo.orderStatusStream(widget.orderId).listen((row) {
      final nextStatus = row?['status']?.toString();
      if (!mounted || nextStatus == null) return;
      if (observedStatus == null) {
        observedStatus = nextStatus;
        return;
      }
      if (nextStatus != observedStatus) {
        observedStatus = nextStatus;
        reload();
      }
    });
  }

  @override
  void dispose() {
    statusSubscription?.cancel();
    super.dispose();
  }

  void reload() {
    if (!mounted) return;
    setState(() {
      future = ref.read(marketplaceRepositoryProvider).order(widget.orderId);
    });
  }

  Future<void> _cancel() async {
    final s = AppStrings.of(context);
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('cancelOrder')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: s.t('reason')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('back'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('confirm'))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(marketplaceRepositoryProvider).cancelOrder(widget.orderId, controller.text);
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final repo = ref.read(marketplaceRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: s.t('back'),
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              context.go('/home');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(s.t('orderDetails')),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 44,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.t('orderLoadFailed'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(s.t('retry')),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.home_rounded),
                      label: Text(s.t('backToPanel')),
                    ),
                  ],
                ),
              ),
            );
          }
          final o = snap.data!;
          final p = (o['providers'] as Map?)?.cast<String, dynamic>() ?? {};
          final r = (o['service_requests'] as Map?)?.cast<String, dynamic>() ?? {};
          final status = (o['status'] ?? '').toString();
          final changes = (o['order_price_changes'] as List? ?? const []).cast<Map>();
          final pending = changes.where((x) => x['status'] == 'pending').toList();
          final warrantyList = (o['warranties'] as List? ?? const []).cast<Map>();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Row(
                    children: [
                      Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.handyman_rounded, color: AppColors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    (p['display_name'] ?? '').toString(),
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                if (hasActiveBlueTick(p))
                                  const Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: Icon(Icons.verified_rounded, size: 17, color: AppColors.blue),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text((r['city'] ?? '').toString(), style: const TextStyle(color: AppColors.muted)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/providers/${p['id']}'),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(s.t('status'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          _StatusPill(status: status),
                        ],
                      ),
                      const Divider(height: 28),
                      Text((r['description'] ?? '').toString(), style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined, size: 19, color: AppColors.blue),
                          const SizedBox(width: 8),
                          Text(
                            '${s.t('total')}: ${o['current_total']} ${o['currency']}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      if (o['scheduled_for'] != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.event_outlined, size: 19, color: AppColors.blue),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(
                                DateTime.parse(o['scheduled_for'].toString()).toLocal(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 14),
                _PriceChangeCard(change: pending.first, onDone: reload),
              ],
              if (status == 'completion_pending') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: .22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.task_alt_rounded,
                            color: AppColors.orange,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Mjeshtri e ka shënuar punën si të përfunduar',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kontrollo punën dhe konfirmoje vetëm pasi të jesh i kënaqur me përfundimin.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  setState(() => busy = true);
                                  try {
                                    await repo.confirmCompletion(widget.orderId);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Puna u konfirmua si e përfunduar.'),
                                        ),
                                      );
                                    }
                                    reload();
                                  } finally {
                                    if (mounted) setState(() => busy = false);
                                  }
                                },
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text('Konfirmo përfundimin'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (status == 'completed') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Kjo punë është përfunduar dhe konfirmuar.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _actionArea(context, status, p, repo, warrantyList),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_rounded),
                label: Text(s.t('backToPanel')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _actionArea(
    BuildContext context,
    String status,
    Map<String, dynamic> provider,
    MarketplaceRepository repo,
    List<Map> warrantyList,
  ) {
    final s = AppStrings.of(context);
    final buttons = <Widget>[];

    if (['confirmed', 'reschedule_pending', 'provider_on_way'].contains(status)) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => context.push('/orders/${widget.orderId}/reschedule'),
          icon: const Icon(Icons.event_repeat_rounded),
          label: Text(s.t('reschedule')),
        ),
      );
      buttons.add(
        OutlinedButton.icon(
          onPressed: _cancel,
          icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
          label: Text(s.t('cancelOrder'), style: const TextStyle(color: AppColors.danger)),
        ),
      );
    }
    if (status == 'provider_on_way') {
      buttons.add(
        FilledButton.icon(
          onPressed: () => context.push('/orders/${widget.orderId}/tracking'),
          icon: const Icon(Icons.navigation_rounded),
          label: Text(s.t('liveTracking')),
        ),
      );
    }
    if (status == 'completed') {
      buttons.add(
        FilledButton.icon(
          onPressed: () => context.push('/orders/${widget.orderId}/payment'),
          icon: const Icon(Icons.payments_outlined),
          label: Text(s.t('payment')),
        ),
      );
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => context.push('/orders/${widget.orderId}/review?providerId=${provider['id']}'),
          icon: const Icon(Icons.star_outline_rounded),
          label: Text(s.t('review')),
        ),
      );
      if (warrantyList.isNotEmpty) {
        buttons.add(
          OutlinedButton.icon(
            onPressed: () => context.push('/orders/${widget.orderId}/warranty'),
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(s.t('warranty')),
          ),
        );
      }
    }

    buttons.add(
      OutlinedButton.icon(
        onPressed: () async {
          final id = await repo.conversationForProvider(provider['id'].toString(), orderId: widget.orderId);
          if (context.mounted) context.push('/chat/$id');
        },
        icon: const Icon(Icons.forum_outlined),
        label: Text(s.t('message')),
      ),
    );
    buttons.add(
      TextButton.icon(
        onPressed: () => context.push('/report/new?orderId=${widget.orderId}'),
        icon: const Icon(Icons.report_problem_outlined),
        label: Text(s.t('reportProblem')),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: buttons
          .map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: SizedBox(height: 50, child: b),
              ))
          .toList(),
    );
  }
}

class _PriceChangeCard extends ConsumerWidget {
  const _PriceChangeCard({required this.change,required this.onDone});final Map change;final VoidCallback onDone;
  @override Widget build(BuildContext context,WidgetRef ref){final s=AppStrings.of(context);return Card(color:AppColors.orange.withValues(alpha:.05),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(s.t('priceChange'),style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:8),Row(children:[Text('${s.t('oldPrice')}: ${change['old_total']}'),const Spacer(),Text('${s.t('newPrice')}: ${change['new_total']}',style:const TextStyle(fontWeight:FontWeight.w800,color:AppColors.orange))]),const SizedBox(height:8),Text((change['reason']??'').toString(),style:const TextStyle(color:AppColors.muted)),const SizedBox(height:12),Row(children:[Expanded(child:OutlinedButton(onPressed:()async{await ref.read(marketplaceRepositoryProvider).respondPriceChange(change['id'].toString(),false);onDone();},child:Text(s.t('reject')))),const SizedBox(width:10),Expanded(child:FilledButton(onPressed:()async{await ref.read(marketplaceRepositoryProvider).respondPriceChange(change['id'].toString(),true);onDone();},child:Text(s.t('accept'))))])])));}
}

class RescheduleScreen extends ConsumerStatefulWidget {const RescheduleScreen({super.key,required this.orderId});final String orderId;@override ConsumerState<RescheduleScreen> createState()=>_RescheduleScreenState();}
class _RescheduleScreenState extends ConsumerState<RescheduleScreen>{DateTime? date;final reason=TextEditingController();bool busy=false;@override void dispose(){reason.dispose();super.dispose();}Future<void> pick()async{final now=DateTime.now();final d=await showDatePicker(context:context,firstDate:now,lastDate:now.add(const Duration(days:180)),initialDate:now);if(d==null||!mounted)return;final t=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(now.add(const Duration(hours:2))));if(t!=null)setState(()=>date=DateTime(d.year,d.month,d.day,t.hour,t.minute));}@override Widget build(BuildContext context){final s=AppStrings.of(context);return Scaffold(appBar:AppBar(title:Text(s.t('reschedule'))),body:ListView(padding:const EdgeInsets.all(20),children:[Card(child:ListTile(leading:const Icon(Icons.event_rounded,color:AppColors.blue),title:Text(date==null?s.t('chooseDate'):DateFormat('dd/MM/yyyy HH:mm').format(date!)),trailing:const Icon(Icons.chevron_right_rounded),onTap:pick)),const SizedBox(height:14),TextField(controller:reason,maxLines:4,decoration:InputDecoration(labelText:s.t('reason'))),const SizedBox(height:24),SizedBox(height:54,child:FilledButton(onPressed:busy||date==null?null:()async{setState(()=>busy=true);try{await ref.read(marketplaceRepositoryProvider).requestReschedule(widget.orderId,date!,reason.text);if(context.mounted)context.pop();}finally{if(mounted)setState(()=>busy=false);}},child:Text(s.t('send'))))]));}}

class LiveTrackingScreen extends ConsumerWidget {
  const LiveTrackingScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final repo = ref.read(marketplaceRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('liveTracking'))),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: repo.liveLocationStream(orderId),
        builder: (context, snap) {
          final location = snap.data;
          final lat = (location?['latitude'] as num?)?.toDouble();
          final lng = (location?['longitude'] as num?)?.toDouble();
          final eta = location?['eta_minutes'];
          final updated = location?['updated_at'] == null
              ? null
              : DateTime.tryParse(location!['updated_at'].toString())?.toLocal();
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _TrackingGridPainter()),
                        ),
                        Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              color: location == null
                                  ? Colors.white
                                  : AppColors.blue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.blue.withValues(alpha: .16),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              location == null
                                  ? Icons.location_searching_rounded
                                  : Icons.navigation_rounded,
                              size: 38,
                              color: location == null
                                  ? AppColors.blue
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.navigation_rounded, color: AppColors.orange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                location == null ? s.t('trackingWaiting') : s.t('onTheWay'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        if (location != null) ...[
                          const SizedBox(height: 12),
                          if (eta != null)
                            Text('${s.t('etaLabel')}: $eta ${s.t('minutes')}'),
                          if (lat != null && lng != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                          if (updated != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${s.t('trackingUpdated')}: ${DateFormat('HH:mm:ss').format(updated)}',
                              style: const TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          ],
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
}

class _TrackingGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.blue.withValues(alpha: .06)
      ..strokeWidth = 1;
    const gap = 34.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.orderId});
  final String orderId;
  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool busy = false;
  String? paymentId;
  Map<String, dynamic>? receipt;

  Future<void> _confirm() async {
    setState(() => busy = true);
    try {
      final repo = ref.read(marketplaceRepositoryProvider);
      final id = await repo.confirmCashPayment(widget.orderId);
      final r = await repo.receiptForPayment(id);
      if (mounted) setState(() { paymentId = id; receipt = r; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('payment'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.read(marketplaceRepositoryProvider).order(widget.orderId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text(s.t('errorGeneric')));
          final o = snap.data!;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_rounded, color: AppColors.blue, size: 32),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.t('cash'), style: Theme.of(context).textTheme.titleMedium),
                              Text(
                                '${o['current_total']} ${o['currency']}',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (receipt != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: AppColors.success),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.t('receipt'), style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  (receipt!['receipt_number'] ?? paymentId ?? '').toString(),
                                  style: const TextStyle(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle_rounded, color: AppColors.success),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: busy ? null : receipt != null ? () => context.pop() : _confirm,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(receipt == null ? s.t('confirmPayment') : s.t('done')),
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

class ReviewScreen extends ConsumerStatefulWidget {const ReviewScreen({super.key,required this.orderId,required this.providerId});final String orderId,providerId;@override ConsumerState<ReviewScreen> createState()=>_ReviewScreenState();}
class _ReviewScreenState extends ConsumerState<ReviewScreen>{int rating=5;final comment=TextEditingController();bool busy=false;@override void dispose(){comment.dispose();super.dispose();}@override Widget build(BuildContext context){final s=AppStrings.of(context);return Scaffold(appBar:AppBar(title:Text(s.t('review'))),body:ListView(padding:const EdgeInsets.all(20),children:[Text(s.t('rating'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(5,(i)=>IconButton(onPressed:()=>setState(()=>rating=i+1),icon:Icon(i<rating?Icons.star_rounded:Icons.star_border_rounded,color:AppColors.orange,size:38)))),const SizedBox(height:18),TextField(controller:comment,maxLines:5,decoration:InputDecoration(labelText:s.t('comment'))),const SizedBox(height:22),SizedBox(height:54,child:FilledButton(onPressed:busy?null:()async{setState(()=>busy=true);try{await ref.read(marketplaceRepositoryProvider).createReview(orderId:widget.orderId,providerId:widget.providerId,rating:rating,comment:comment.text);if(context.mounted)context.pop();}finally{if(mounted)setState(()=>busy=false);}},child:Text(s.t('submitReview'))))]));}}

class WarrantyScreen extends ConsumerWidget {const WarrantyScreen({super.key,required this.orderId});final String orderId;@override Widget build(BuildContext context,WidgetRef ref){final s=AppStrings.of(context);return Scaffold(appBar:AppBar(title:Text(s.t('warranty'))),body:FutureBuilder<Map<String,dynamic>>(future:ref.read(marketplaceRepositoryProvider).order(orderId),builder:(context,snap){if(snap.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());final w=((snap.data?['warranties'] as List?)??const[]).cast<Map>();if(w.isEmpty)return EmptyState(icon:Icons.verified_user_outlined,title:s.t('noWarranty'));final x=w.first;return Padding(padding:const EdgeInsets.all(20),child:Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.verified_user_rounded,color:AppColors.success,size:44),const SizedBox(height:14),Text(s.t('warrantyValid'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),Text('${DateFormat('dd/MM/yyyy').format(DateTime.parse(x['starts_at'].toString()).toLocal())} – ${DateFormat('dd/MM/yyyy').format(DateTime.parse(x['expires_at'].toString()).toLocal())}'),if((x['terms']??'').toString().isNotEmpty)...[const SizedBox(height:12),Text(x['terms'].toString())],const SizedBox(height:18),OutlinedButton.icon(onPressed:()=>context.push('/support/new?orderId=$orderId'),icon:const Icon(Icons.report_problem_outlined),label:Text(s.t('reportProblem')))]))));}));}}