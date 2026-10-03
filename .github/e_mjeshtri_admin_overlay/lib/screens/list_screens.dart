import 'package:flutter/material.dart';

import '../data/admin_repository.dart';

class CitizensScreen extends StatefulWidget {
  const CitizensScreen({super.key});

  @override
  State<CitizensScreen> createState() => _CitizensScreenState();
}

class _CitizensScreenState extends State<CitizensScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _status = 'all';

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
      final rows = await AdminRepository.instance.loadCitizens();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) {
        setState(() => _error = AdminRepository.instance.friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    return _rows.where((row) {
      final status = (row['status'] ?? '').toString();
      if (_status != 'all' && status != _status) return false;
      if (q.isEmpty) return true;
      final haystack = [
        row['first_name'],
        row['last_name'],
        row['email'],
        row['phone'],
        row['city'],
        row['language'],
      ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Future<void> _changeStatus(Map<String, dynamic> row, String status) async {
    final name = _citizenName(row);
    String? reason;

    if (status == 'suspended') {
      reason = await _askReason(
        context,
        'Arsyeja e pezullimit',
        'Shkruaj pse po pezullohet $name.',
      );
      if (reason == null) return;
    } else {
      final ok = await _confirm(
        'Riaktivizo qytetarin',
        'Je i sigurt që dëshiron të riaktivizosh $name?',
      );
      if (!ok) return;
    }

    try {
      await AdminRepository.instance.setCitizenStatus(
        row['id'].toString(),
        status,
        reason: reason,
      );
      if (!mounted) return;
      _toast('Statusi u përditësua.');
      await _reload();
    } catch (e) {
      if (mounted) {
        _toast(AdminRepository.instance.friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ListHeader(
          icon: Icons.people_alt_rounded,
          title: 'Qytetarët',
          subtitle: 'Përdoruesit që përdorin e-Mjeshtri si klientë.',
          count: _rows.length,
          onRefresh: _reload,
        ),
        const SizedBox(height: 16),
        _Filters(
          queryHint: 'Kërko emër, email, telefon ose qytet...',
          status: _status,
          statuses: const ['active', 'suspended', 'deletion_requested', 'deleted'],
          onQuery: (value) => setState(() => _query = value),
          onStatus: (value) => setState(() => _status = value),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const _StateCard('Po ngarkohen qytetarët...', loading: true)
        else if (_error != null)
          _StateCard(_error!, onRetry: _reload)
        else if (rows.isEmpty)
          const _StateCard(
            'Nuk u gjet asnjë qytetar.',
            subtitle:
                'Llogaritë e mjeshtrave dhe administratorëve nuk numërohen si qytetarë në këtë listë.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 850) {
                return Column(
                  children: [
                    for (final row in rows) ...[
                      _CitizenCard(
                        row: row,
                        onDetails: () => _showCitizen(row),
                        onStatus: (status) => _changeStatus(row, status),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return _CitizensTable(
                rows: rows,
                onDetails: _showCitizen,
                onStatus: _changeStatus,
              );
            },
          ),
      ],
    );
  }

  Future<void> _showCitizen(Map<String, dynamic> row) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_citizenName(row)),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: _DetailsGrid(
              entries: [
                ('Email', _text(row['email'])),
                ('Telefon', _text(row['phone'])),
                ('Qytet', _text(row['city'])),
                ('Status', _statusLabel(_text(row['status']))),
                ('Gjuha', _text(row['language'])),
                ('Timezone', _text(row['timezone'])),
                ('Monedha', _text(row['currency'])),
                ('Kërkesa', _text(row['request_count'])),
                ('Kërkesa aktive', _text(row['active_request_count'])),
                ('Punë', _text(row['orders_count'])),
                ('Punë të përfunduara', _text(row['completed_orders'])),
                ('Shpenzuar', _money(row['paid_total'], row['currency'])),
                ('Regjistruar', _date(row['created_at'])),
                ('Hyrja e fundit', _date(row['last_sign_in_at'])),
                ('ID', _text(row['id'])),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mbyll'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Jo'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Po, vazhdo'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }
}

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _status = 'all';

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
      final rows = await AdminRepository.instance.loadProviders();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) {
        setState(() => _error = AdminRepository.instance.friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    return _rows.where((row) {
      final status = (row['status'] ?? '').toString();
      if (_status != 'all' && status != _status) return false;
      if (q.isEmpty) return true;
      final haystack = [
        row['display_name'],
        row['legal_name'],
        row['owner_name'],
        row['email'],
        row['owner_email'],
        row['phone'],
        row['city'],
        row['categories'],
        row['plan'],
      ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Future<void> _action(Map<String, dynamic> row, String action) async {
    final labels = {
      'approve': 'Aprovo mjeshtrin',
      'reject': 'Refuzo mjeshtrin',
      'suspend': 'Pezullo mjeshtrin',
      'reactivate': 'Riaktivizo mjeshtrin',
    };

    String? reason;
    if (action == 'reject' || action == 'suspend') {
      reason = await _askReason(
        context,
        action == 'reject' ? 'Arsyeja e refuzimit' : 'Arsyeja e pezullimit',
        'Shkruaj arsyen për “${_text(row['display_name'])}”.',
      );
      if (reason == null) return;
    } else {
      final ok = await _confirm(
        labels[action] ?? 'Veprimi',
        'Je i sigurt që dëshiron të vazhdosh me “${_text(row['display_name'])}”?',
      );
      if (!ok) return;
    }

    try {
      await AdminRepository.instance.setProviderStatus(
        row['id'].toString(),
        action,
        reason: reason,
      );
      if (!mounted) return;
      _toast('Statusi i mjeshtrit u përditësua.');
      await _reload();
    } catch (e) {
      if (mounted) {
        _toast(AdminRepository.instance.friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    final incomplete = _rows.where((e) => e['profile_complete'] != true).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ListHeader(
          icon: Icons.handyman_rounded,
          title: 'Mjeshtrat',
          subtitle: 'Profile, verifikim, kategori, punë dhe abonime.',
          count: _rows.length,
          onRefresh: _reload,
        ),
        if (!_loading && incomplete > 0) ...[
          const SizedBox(height: 12),
          _WarningBanner(
            text:
                '$incomplete mjeshtër/mjeshtra kanë profil të paplotë dhe nuk mund të aprovohen pa kategori, kontakt, qytet dhe dokument të aprovuar.',
          ),
        ],
        const SizedBox(height: 16),
        _Filters(
          queryHint: 'Kërko mjeshtër, pronar, email, kategori ose qytet...',
          status: _status,
          statuses: const ['pending', 'active', 'suspended', 'rejected'],
          onQuery: (value) => setState(() => _query = value),
          onStatus: (value) => setState(() => _status = value),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const _StateCard('Po ngarkohen mjeshtrat...', loading: true)
        else if (_error != null)
          _StateCard(_error!, onRetry: _reload)
        else if (rows.isEmpty)
          const _StateCard('Nuk u gjet asnjë mjeshtër.')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    for (final row in rows) ...[
                      _ProviderCard(
                        row: row,
                        onDetails: () => _showProvider(row),
                        onAction: (action) => _action(row, action),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return _ProvidersTable(
                rows: rows,
                onDetails: _showProvider,
                onAction: _action,
              );
            },
          ),
      ],
    );
  }

  Future<void> _showProvider(Map<String, dynamic> row) async {
    final complete = row['profile_complete'] == true;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text(row['display_name'])),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!complete) ...[
                  const _WarningBanner(
                    text:
                        'Ky profil nuk është gati për aprovim. Kontrollo kategorinë, kontaktin, qytetin dhe dokumentet.',
                  ),
                  const SizedBox(height: 14),
                ],
                _DetailsGrid(
                  entries: [
                    ('Emri ligjor', _text(row['legal_name'])),
                    ('Pronari', _text(row['owner_name'])),
                    ('Email biznesi', _text(row['email'])),
                    ('Email pronari', _text(row['owner_email'])),
                    ('Telefon', _text(row['phone'])),
                    ('Qytet', _text(row['city'])),
                    ('Adresë', _address(row)),
                    ('Status', _statusLabel(_text(row['status']))),
                    ('Aprovim platforme', row['is_verified'] == true ? 'Aprovuar' : 'Jo'),
                    ('Tick blu', row['blue_tick_active'] == true ? 'AKTIV' : 'Jo aktiv'),
                    ('500 ALL Tick blu', _text(row['blue_tick_500_status'])),
                    ('Tick blu skadon', _date(row['blue_tick_expires_at'])),
                    ('Kategori', _text(row['categories'])),
                    ('Nr. kategorive', _text(row['category_count'])),
                    ('Dokumente', _text(row['document_count'])),
                    ('Dokumente aprovuar', _text(row['approved_document_count'])),
                    ('Dokumente pending', _text(row['pending_document_count'])),
                    ('Koordinata', row['has_coordinates'] == true ? 'Po' : 'Jo'),
                    ('Eksperiencë', _years(row['years_experience'])),
                    ('Rating', '${_text(row['rating_avg'])} (${_text(row['rating_count'])})'),
                    ('Punë të përfunduara', _text(row['jobs_count'])),
                    ('Punë aktive', _text(row['active_jobs_count'])),
                    ('Abonimi', _text(row['plan'])),
                    ('ASAP', row['accepts_asap'] == true ? 'Po' : 'Jo'),
                    ('Vacation mode', row['vacation_mode'] == true ? 'Po' : 'Jo'),
                    ('Regjistruar', _date(row['created_at'])),
                    ('ID', _text(row['id'])),
                  ],
                ),
                if ((_text(row['bio'])) != '—') ...[
                  const SizedBox(height: 14),
                  const Text('Përshkrimi',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(_text(row['bio'])),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mbyll'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Jo'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Po, vazhdo'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onRefresh;

  const _ListHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleBlock = Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .05),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Rifresko'),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleBlock),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Rifresko'),
            ),
          ],
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  final String queryHint;
  final String status;
  final List<String> statuses;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onStatus;

  const _Filters({
    required this.queryHint,
    required this.status,
    required this.statuses,
    required this.onQuery,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final search = TextField(
              onChanged: onQuery,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: queryHint,
                isDense: true,
              ),
            );
            final filter = DropdownButtonFormField<String>(
              initialValue: status,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Statusi',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('Të gjitha'),
                ),
                for (final value in statuses)
                  DropdownMenuItem(
                    value: value,
                    child: Text(_statusLabel(value)),
                  ),
              ],
              onChanged: (value) => onStatus(value ?? 'all'),
            );
            if (constraints.maxWidth < 650) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  filter,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: search),
                const SizedBox(width: 10),
                Expanded(child: filter),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CitizensTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Future<void> Function(Map<String, dynamic>) onDetails;
  final Future<void> Function(Map<String, dynamic>, String) onStatus;

  const _CitizensTable({
    required this.rows,
    required this.onDetails,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Qytetari')),
            DataColumn(label: Text('Kontakt')),
            DataColumn(label: Text('Qytet')),
            DataColumn(label: Text('Kërkesa')),
            DataColumn(label: Text('Punë')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Veprime')),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: Text(
                        _citizenName(row),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    onTap: () => onDetails(row),
                  ),
                  DataCell(
                    SizedBox(
                      width: 190,
                      child: Text(
                        [_text(row['email']), _text(row['phone'])]
                            .where((e) => e != '—')
                            .join('\n'),
                      ),
                    ),
                  ),
                  DataCell(Text(_text(row['city']))),
                  DataCell(Text(_text(row['request_count']))),
                  DataCell(Text(_text(row['completed_orders']))),
                  DataCell(_StatusChip(_text(row['status']))),
                  DataCell(
                    _CitizenActions(
                      row: row,
                      onDetails: () => onDetails(row),
                      onStatus: (status) => onStatus(row, status),
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

class _ProvidersTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Future<void> Function(Map<String, dynamic>) onDetails;
  final Future<void> Function(Map<String, dynamic>, String) onAction;

  const _ProvidersTable({
    required this.rows,
    required this.onDetails,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Mjeshtri')),
            DataColumn(label: Text('Kategori')),
            DataColumn(label: Text('Qytet')),
            DataColumn(label: Text('Dok.')),
            DataColumn(label: Text('Rating')),
            DataColumn(label: Text('Abonim')),
            DataColumn(label: Text('Tick blu')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Veprime')),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(row['display_name']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            _text(row['email']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () => onDetails(row),
                  ),
                  DataCell(
                    SizedBox(
                      width: 190,
                      child: Text(
                        _text(row['categories']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(_text(row['city']))),
                  DataCell(
                    Text(
                      '${_text(row['approved_document_count'])}/${_text(row['document_count'])}',
                    ),
                  ),
                  DataCell(
                    Text(
                      '${_text(row['rating_avg'])} ★',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  DataCell(Text(_text(row['plan']))),
                  DataCell(
                    Text(
                      row['blue_tick_active'] == true
                          ? '✓ Aktiv'
                          : _text(row['blue_tick_500_status']),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: row['blue_tick_active'] == true
                            ? Colors.blue
                            : Colors.black54,
                      ),
                    ),
                  ),
                  DataCell(_StatusChip(_text(row['status']))),
                  DataCell(
                    _ProviderActions(
                      row: row,
                      onDetails: () => onDetails(row),
                      onAction: (action) => onAction(row, action),
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

class _CitizenCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onDetails;
  final ValueChanged<String> onStatus;

  const _CitizenCard({
    required this.row,
    required this.onDetails,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(_initials(_citizenName(row))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _citizenName(row),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [_text(row['email']), _text(row['phone']), _text(row['city'])]
                        .where((e) => e != '—')
                        .join(' • '),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusChip(_text(row['status'])),
                ],
              ),
            ),
            _CitizenActions(
              row: row,
              onDetails: onDetails,
              onStatus: onStatus,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onDetails;
  final ValueChanged<String> onAction;

  const _ProviderCard({
    required this.row,
    required this.onDetails,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final complete = row['profile_complete'] == true;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Text(_initials(_text(row['display_name']))),
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
                          _text(row['display_name']),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (row['blue_tick_active'] == true) ...[
                        const SizedBox(width: 5),
                        const Tooltip(
                          message: 'Tick blu aktiv',
                          child: Icon(
                            Icons.verified_rounded,
                            size: 17,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      _text(row['city']),
                      _text(row['categories']),
                      _text(row['plan']),
                    ].where((e) => e != '—').join(' • '),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusChip(_text(row['status'])),
                      if (row['blue_tick_active'] == true)
                        const _SmallInfo(text: 'Tick blu aktiv'),
                      if (!complete)
                        const _SmallWarning(text: 'Profil i paplotë'),
                    ],
                  ),
                ],
              ),
            ),
            _ProviderActions(
              row: row,
              onDetails: onDetails,
              onAction: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

class _CitizenActions extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onDetails;
  final ValueChanged<String> onStatus;

  const _CitizenActions({
    required this.row,
    required this.onDetails,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = _text(row['status']);
    return PopupMenuButton<String>(
      tooltip: 'Veprime',
      onSelected: (value) {
        if (value == 'details') {
          onDetails();
        } else {
          onStatus(value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'details',
          child: _MenuLine(Icons.visibility_rounded, 'Shiko detajet'),
        ),
        if (status == 'active')
          const PopupMenuItem(
            value: 'suspended',
            child: _MenuLine(
              Icons.person_off_rounded,
              'Pezullo',
              destructive: true,
            ),
          ),
        if (status == 'suspended')
          const PopupMenuItem(
            value: 'active',
            child: _MenuLine(Icons.person_rounded, 'Riaktivizo'),
          ),
      ],
    );
  }
}

class _ProviderActions extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onDetails;
  final ValueChanged<String> onAction;

  const _ProviderActions({
    required this.row,
    required this.onDetails,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final status = _text(row['status']);
    final complete = row['profile_complete'] == true;

    return PopupMenuButton<String>(
      tooltip: 'Veprime',
      onSelected: (value) {
        if (value == 'details') {
          onDetails();
        } else {
          onAction(value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'details',
          child: _MenuLine(Icons.visibility_rounded, 'Shiko detajet'),
        ),
        if (status == 'pending' && complete)
          const PopupMenuItem(
            value: 'approve',
            child: _MenuLine(Icons.verified_rounded, 'Aprovo'),
          ),
        if (status == 'pending')
          const PopupMenuItem(
            value: 'reject',
            child: _MenuLine(
              Icons.block_rounded,
              'Refuzo',
              destructive: true,
            ),
          ),
        if (status == 'active')
          const PopupMenuItem(
            value: 'suspend',
            child: _MenuLine(
              Icons.pause_circle_rounded,
              'Pezullo',
              destructive: true,
            ),
          ),
        if (status == 'suspended' && complete)
          const PopupMenuItem(
            value: 'reactivate',
            child: _MenuLine(Icons.play_circle_rounded, 'Riaktivizo'),
          ),
        if (status == 'rejected' && complete)
          const PopupMenuItem(
            value: 'approve',
            child: _MenuLine(Icons.verified_rounded, 'Aprovo'),
          ),
        if (!complete && status != 'active')
          const PopupMenuItem(
            enabled: false,
            value: 'blocked',
            child: _MenuLine(
              Icons.warning_amber_rounded,
              'Plotëso profilin para aprovimit',
            ),
          ),
      ],
    );
  }
}

class _MenuLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool destructive;

  const _MenuLine(
    this.icon,
    this.text, {
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red : null;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 9),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  final List<(String, String)> entries;
  const _DetailsGrid({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in entries)
          Container(
            width: 285,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  item.$2,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final positive = normalized == 'active';
    final warning = normalized == 'pending' ||
        normalized == 'deletion_requested' ||
        normalized == 'suspended';
    final color = positive
        ? Colors.green
        : warning
            ? Colors.orange
            : Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String text;
  const _WarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  final String text;
  const _SmallInfo({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _SmallWarning extends StatelessWidget {
  final String text;
  const _SmallWarning({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool loading;
  final VoidCallback? onRetry;

  const _StateCard(
    this.title, {
    this.subtitle,
    this.loading = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 58, horizontal: 24),
        child: Center(
          child: Column(
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                const Icon(
                  Icons.info_outline_rounded,
                  size: 40,
                  color: Colors.black38,
                ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: onRetry,
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

Future<String?> _askReason(
  BuildContext context,
  String title,
  String subtitle,
) async {
  final controller = TextEditingController();
  String? errorText;

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 5,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Arsyeja',
                  alignLabelWithHint: true,
                  errorText: errorText,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Anulo'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length < 4) {
                setState(() => errorText = 'Shkruaj një arsye të qartë.');
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Vazhdo'),
          ),
        ],
      ),
    ),
  );

  controller.dispose();
  return result;
}

String _citizenName(Map<String, dynamic> row) {
  final first = (row['first_name'] ?? '').toString().trim();
  final last = (row['last_name'] ?? '').toString().trim();
  final full = '$first $last'.trim();
  return full.isEmpty ? 'Qytetar pa emër' : full;
}

String _text(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? '—' : text;
}

String _statusLabel(String status) {
  return switch (status) {
    'active' => 'Aktiv',
    'suspended' => 'Pezulluar',
    'pending' => 'Në pritje',
    'rejected' => 'Refuzuar',
    'deletion_requested' => 'Kërkon fshirje',
    'deleted' => 'Fshirë',
    _ => status == '—' ? status : status,
  };
}

String _date(dynamic raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (d == null) return '—';
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  final hour = d.hour.toString().padLeft(2, '0');
  final minute = d.minute.toString().padLeft(2, '0');
  return '$day/$month/' + d.year.toString() + ' • $hour:$minute';
}

String _money(dynamic raw, dynamic currency) {
  final value = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
  if (value == null) return '—';
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2) +
      ' ' +
      _text(currency);
}

String _years(dynamic raw) {
  final value = int.tryParse(raw?.toString() ?? '');
  if (value == null) return '—';
  return '$value vjet';
}

String _address(Map<String, dynamic> row) {
  final parts = [
    _text(row['street']),
    _text(row['city']),
    _text(row['postal_code']),
  ].where((e) => e != '—').toList();
  return parts.isEmpty ? '—' : parts.join(', ');
}

String _initials(String text) {
  final parts = text
      .split(RegExp(r'\s+'))
      .where((e) => e.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
