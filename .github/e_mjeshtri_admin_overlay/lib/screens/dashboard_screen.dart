import 'package:flutter/material.dart';

import '../data/admin_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AdminRepository.instance.loadDashboard();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        setState(() => _error = AdminRepository.instance.friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _DashboardState(
        icon: Icons.sync_rounded,
        title: 'Po ngarkohet dashboard...',
        loading: true,
      );
    }
    if (_error != null) {
      return _DashboardState(
        icon: Icons.error_outline_rounded,
        title: _error!,
        action: _reload,
      );
    }

    final data = _data ?? const <String, dynamic>{};
    final kpis = _map(data['kpis']);
    final operational = _map(data['operational']);
    final verifications = _map(data['verifications']);
    final activity = _list(data['recent_activity']);
    final trend = _list(data['request_trend']);

    final cards = [
      _Kpi('Qytetarë', kpis['citizens_total'] ?? 0, Icons.people_alt_rounded),
      _Kpi('Mjeshtra', kpis['providers_total'] ?? 0, Icons.handyman_rounded),
      _Kpi(
        'Verifikime pending',
        kpis['pending_verifications'] ?? 0,
        Icons.verified_user_rounded,
      ),
      _Kpi('Punë aktive', kpis['active_orders'] ?? 0, Icons.work_rounded),
      _Kpi('Kërkesa sot', kpis['requests_today'] ?? 0, Icons.assignment_rounded),
      _Kpi(
        'Komisione',
        kpis['commissions_total'] ?? 0,
        Icons.account_balance_wallet_rounded,
        suffix: ' ALL',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(onRefresh: _reload),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 620
                ? 2
                : constraints.maxWidth < 1050
                    ? 3
                    : 6;
            final width =
                (constraints.maxWidth - ((columns - 1) * 10)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final card in cards)
                  SizedBox(width: width, child: _KpiCard(data: card)),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final left = _OperationalCard(
              operational: operational,
              verifications: verifications,
            );
            final right = _ActivityCard(activity: activity);
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  left,
                  const SizedBox(height: 12),
                  right,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 12),
                Expanded(child: right),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _TrendCard(items: trend),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pamja reale e aktivitetit të e-Mjeshtri.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Rifresko'),
        ),
      ],
    );
  }
}

class _Kpi {
  final String label;
  final dynamic value;
  final IconData icon;
  final String suffix;
  const _Kpi(this.label, this.value, this.icon, {this.suffix = ''});
}

class _KpiCard extends StatelessWidget {
  final _Kpi data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              data.icon,
              size: 21,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '${_num(data.value)}${data.suffix}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              data.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationalCard extends StatelessWidget {
  final Map<String, dynamic> operational;
  final Map<String, dynamic> verifications;

  const _OperationalCard({
    required this.operational,
    required this.verifications,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Kërkesa me oferta', operational['requests_with_offers_pct']),
      ('Punë të përfunduara', operational['completed_orders_pct']),
      ('Mjeshtra aktivë', operational['active_providers_pct']),
    ];
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Operacional',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 16),
            for (final row in rows) ...[
              Row(
                children: [
                  Expanded(child: Text(row.$1)),
                  Text(
                    '${_num(row.$2)}%',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (_double(row.$2) / 100).clamp(0, 1),
                minHeight: 7,
                borderRadius: BorderRadius.circular(99),
              ),
              const SizedBox(height: 14),
            ],
            const Divider(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Mini('Identitet', verifications['identity'] ?? 0),
                _Mini('Biznes', verifications['business'] ?? 0),
                _Mini('Licenca', verifications['licenses'] ?? 0),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final dynamic value;
  const _Mini(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: ${_num(value)}',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aktiviteti i fundit',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (activity.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text(
                    'Nuk ka aktivitet të regjistruar.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              for (final item in activity)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(
                          Icons.circle,
                          size: 8,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item['text'] ?? 'Aktivitet').toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _date(item['at']),
                              style: const TextStyle(
                                color: Colors.black45,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _TrendCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<double>(
      1,
      (max, item) =>
          _double(item['count']) > max ? _double(item['count']) : max,
    );
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kërkesat – 7 ditët e fundit',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const Text(
                'Nuk ka të dhëna.',
                style: TextStyle(color: Colors.black54),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final item in items)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            Text(
                              _num(item['count']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              height: 24 +
                                  72 * (_double(item['count']) / maxValue),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: .75),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _shortDate(item['date']),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardState extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool loading;
  final VoidCallback? action;

  const _DashboardState({
    required this.icon,
    required this.title,
    this.loading = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
        child: Center(
          child: Column(
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                Icon(icon, size: 42, color: Colors.black38),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (action != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: action,
                  child: const Text('Provo përsëri'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _num(dynamic value) {
  if (value == null) return '0';
  if (value is num) {
    if (value.toDouble() == value.toDouble().roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
  return value.toString();
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _date(dynamic raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (d == null) return '—';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm/' + d.year.toString() + ' • $hh:$mi';
}

String _shortDate(dynamic raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '');
  if (d == null) return '—';
  return d.day.toString() + '/' + d.month.toString();
}
