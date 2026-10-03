import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../data/admin_modules_repository.dart';

class AdminModuleScreen extends StatefulWidget {
  final String moduleKey;
  final String title;
  final String subtitle;
  final IconData icon;

  const AdminModuleScreen({
    super.key,
    required this.moduleKey,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  State<AdminModuleScreen> createState() => _AdminModuleScreenState();
}

class _AdminModuleScreenState extends State<AdminModuleScreen> {
  AdminModuleSnapshot? _snapshot;
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
      final data = await AdminModulesRepository.instance.load(widget.moduleKey);
      if (!mounted) return;
      setState(() => _snapshot = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AdminModuleItem> get _visibleItems {
    final q = _query.trim().toLowerCase();
    final source = _snapshot?.items ?? const <AdminModuleItem>[];
    return source.where((item) {
      final statusOk = _status == 'all' || item.status == _status;
      final haystack =
          '${item.title} ${item.subtitle} ${item.detail} ${item.kind} ${item.metric ?? ''}'
              .toLowerCase();
      return statusOk && (q.isEmpty || haystack.contains(q));
    }).toList();
  }

  List<String> get _statuses {
    final values = <String>{
      for (final item in _snapshot?.items ?? const <AdminModuleItem>[])
        if (item.status.trim().isNotEmpty) item.status,
    }.toList()
      ..sort();
    return values;
  }

  bool get _canWriteCurrentModule {
    final role = _snapshot?.adminRole ?? '';
    if (role == 'super_admin') return true;
    if (role == 'admin') return widget.moduleKey != 'admins';
    if (role == 'support') {
      return {
        'requests',
        'offers',
        'orders',
        'reviews',
        'reports',
        'disputes',
        'notifications',
        'support',
      }.contains(widget.moduleKey);
    }
    if (role == 'finance') {
      return {'finance', 'subscriptions'}.contains(widget.moduleKey);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          icon: widget.icon,
          title: widget.title,
          subtitle: widget.subtitle,
          actions: _headerActions(),
        ),
        const SizedBox(height: 18),
        if (widget.moduleKey == 'subscriptions') ...[
          const _SubscriptionPricingCard(),
          const SizedBox(height: 16),
        ],
        if ((_snapshot?.summary ?? const {}).isNotEmpty)
          _SummaryGrid(values: _snapshot!.summary),
        if ((_snapshot?.summary ?? const {}).isNotEmpty)
          const SizedBox(height: 16),
        _Filters(
          query: _query,
          status: _status,
          statuses: _statuses,
          onQueryChanged: (value) => setState(() => _query = value),
          onStatusChanged: (value) => setState(() => _status = value),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const _StateCard(
            icon: Icons.sync_rounded,
            title: 'Po ngarkohen të dhënat...',
            spinning: true,
          )
        else if (_error != null)
          _StateCard(
            icon: Icons.error_outline_rounded,
            title: _error!,
            actionLabel: 'Provo përsëri',
            onAction: _reload,
          )
        else if (items.isEmpty)
          _StateCard(
            icon: widget.icon,
            title: 'Nuk ka ende të dhëna në këtë modul.',
            subtitle:
                'Faqja është funksionale dhe do t’i shfaqë automatikisht sapo të krijohen të dhëna.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 850) {
                return Column(
                  children: [
                    for (final item in items) ...[
                      _MobileItemCard(
                        item: item,
                        actions: _actionsFor(item),
                        onAction: (action) => _handleAction(item, action),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return _DesktopTable(
                items: items,
                actionsFor: _actionsFor,
                onAction: _handleAction,
              );
            },
          ),
      ],
    );
  }

  List<Widget> _headerActions() {
    final buttons = <Widget>[
      OutlinedButton.icon(
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Rifresko'),
      ),
    ];

    if (widget.moduleKey == 'categories' && _canWriteCurrentModule) {
      buttons.insert(
        0,
        FilledButton.icon(
          onPressed: _createCategory,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Shto kategori'),
        ),
      );
    } else if (widget.moduleKey == 'notifications' && _canWriteCurrentModule) {
      buttons.insert(
        0,
        FilledButton.icon(
          onPressed: _broadcastNotification,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Dërgo njoftim'),
        ),
      );
    } else if (widget.moduleKey == 'admins' &&
        _snapshot?.adminRole == 'super_admin') {
      buttons.insert(
        0,
        FilledButton.icon(
          onPressed: _addAdmin,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Shto admin'),
        ),
      );
    }

    return buttons;
  }

  List<_Action> _actionsFor(AdminModuleItem item) {
    final actions = <_Action>[
      const _Action('view', 'Shiko detajet', Icons.visibility_rounded),
    ];

    if (widget.moduleKey == 'verifications' && item.kind == 'document') {
      actions.add(const _Action(
        'open_document_local',
        'Hap dokumentin',
        Icons.open_in_new_rounded,
      ));
    }
    if (widget.moduleKey == 'subscriptions' &&
        item.kind == 'subscription_payment') {
      actions.add(const _Action(
        'open_payment_proof_local',
        'Hap provën e pagesës',
        Icons.receipt_long_rounded,
      ));
    }

    if (!_canWriteCurrentModule) return actions;

    switch (widget.moduleKey) {
      case 'verifications':
        if (item.kind == 'document' && item.status == 'pending') {
          actions.addAll(const [
            _Action('approve_document', 'Aprovo dokumentin',
                Icons.check_circle_rounded),
            _Action(
                'reject_document', 'Refuzo dokumentin', Icons.cancel_rounded,
                destructive: true),
          ]);
        } else if (item.kind == 'provider' && item.status == 'pending') {
          actions.addAll(const [
            _Action(
                'approve_provider', 'Aprovo mjeshtrin', Icons.verified_rounded),
            _Action('reject_provider', 'Refuzo mjeshtrin', Icons.block_rounded,
                destructive: true),
          ]);
        }
        break;
      case 'categories':
        actions.addAll([
          const _Action('edit_local', 'Ndrysho', Icons.edit_rounded),
          _Action(
            'toggle',
            item.status == 'active' ? 'Çaktivizo' : 'Aktivizo',
            item.status == 'active'
                ? Icons.pause_circle_rounded
                : Icons.play_circle_rounded,
          ),
        ]);
        break;
      case 'requests':
        if (!{'closed', 'cancelled', 'expired'}.contains(item.status)) {
          actions.addAll(const [
            _Action('close', 'Mbyll kërkesën', Icons.task_alt_rounded),
            _Action('cancel', 'Anulo kërkesën', Icons.cancel_rounded,
                destructive: true),
            _Action('expire', 'Shëno të skaduar', Icons.timer_off_rounded,
                destructive: true),
          ]);
        }
        break;
      case 'offers':
        if (item.status == 'submitted') {
          actions.addAll(const [
            _Action('reject', 'Refuzo ofertën', Icons.cancel_rounded,
                destructive: true),
            _Action('expire', 'Skado ofertën', Icons.timer_off_rounded,
                destructive: true),
          ]);
        }
        break;
      case 'orders':
        if (!{'completed', 'cancelled'}.contains(item.status)) {
          actions.addAll(const [
            _Action('complete', 'Shëno të përfunduar', Icons.task_alt_rounded),
            _Action('cancel', 'Anulo punën', Icons.cancel_rounded,
                destructive: true),
          ]);
        }
        break;
      case 'reviews':
        if (item.status != 'published') {
          actions.add(
              const _Action('publish', 'Publiko', Icons.visibility_rounded));
        }
        if (item.status != 'hidden') {
          actions.add(
              const _Action('hide', 'Fshih', Icons.visibility_off_rounded));
        }
        if (item.status != 'removed') {
          actions.add(const _Action(
              'remove', 'Hiq review', Icons.delete_outline_rounded,
              destructive: true));
        }
        break;
      case 'reports':
        if (item.status == 'open') {
          actions.add(const _Action(
              'review', 'Nis shqyrtimin', Icons.manage_search_rounded));
        }
        if (!{'actioned', 'dismissed', 'closed'}.contains(item.status)) {
          actions.addAll(const [
            _Action('action', 'Shëno veprim të marrë', Icons.gavel_rounded),
            _Action('dismiss', 'Hidh poshtë',
                Icons.do_not_disturb_alt_rounded,
                destructive: true),
            _Action('close', 'Mbyll', Icons.task_alt_rounded),
          ]);
        }
        break;
      case 'disputes':
        if (item.status == 'open' || item.status == 'evidence') {
          actions.add(const _Action(
              'review', 'Kalo në shqyrtim', Icons.manage_search_rounded));
        }
        if (!{'resolved_client', 'resolved_provider', 'closed'}
            .contains(item.status)) {
          actions.addAll(const [
            _Action(
                'resolve_client', 'Vendim për klientin', Icons.person_rounded),
            _Action('resolve_provider', 'Vendim për mjeshtrin',
                Icons.handyman_rounded),
            _Action('close', 'Mbyll pa vendim', Icons.task_alt_rounded),
          ]);
        }
        break;
      case 'finance':
        if (item.kind == 'commission' &&
            item.status != 'paid' &&
            item.status != 'waived') {
          actions.addAll(const [
            _Action('commission_paid', 'Shëno komisionin të paguar',
                Icons.paid_rounded),
            _Action('commission_waive', 'Hiq komisionin',
                Icons.money_off_csred_rounded,
                destructive: true),
          ]);
        } else if (item.kind == 'refund' &&
            !{'completed', 'cancelled'}.contains(item.status)) {
          actions.addAll(const [
            _Action(
                'refund_complete', 'Konfirmo refund manual', Icons.task_alt_rounded),
            _Action('refund_cancel', 'Anulo refund', Icons.cancel_rounded,
                destructive: true),
          ]);
        } else if (item.kind == 'payment' && item.status == 'pending') {
          actions.add(
              const _Action('payment_paid', 'Shëno manualisht të paguar', Icons.paid_rounded));
        }
        break;
      case 'subscriptions':
        if (item.kind == 'subscription_payment') {
          if (item.status == 'pending') {
            final rawFee = item.data['blue_tick_fee_amount'];
            final fee = rawFee is num
                ? rawFee.toDouble()
                : double.tryParse(rawFee?.toString() ?? '') ?? 0;
            final included = item.data['blue_tick_included'] == true;
            final approveLabel = included
                ? 'Aprovo 20,000 ALL + Tick blu falas'
                : fee >= 500
                    ? 'Aprovo 2,500 ALL + Tick blu'
                    : 'Aprovo 2,000 ALL pa Tick blu';
            actions.add(
              _Action(
                'approve_payment',
                approveLabel,
                Icons.verified_rounded,
              ),
            );
            actions.add(
              const _Action(
                'reject_payment',
                'Refuzo pagesën',
                Icons.cancel_rounded,
                destructive: true,
              ),
            );
          }
        } else if (item.kind == 'subscription') {
          if (item.status == 'active') {
            actions.addAll(const [
              _Action(
                'past_due',
                'Shëno pagesë të vonuar',
                Icons.warning_amber_rounded,
              ),
              _Action(
                'cancel',
                'Anulo abonimin',
                Icons.cancel_rounded,
                destructive: true,
              ),
              _Action(
                'expire',
                'Skado abonimin',
                Icons.timer_off_rounded,
                destructive: true,
              ),
            ]);
          } else if (item.status == 'past_due') {
            actions.addAll(const [
              _Action(
                'cancel',
                'Anulo abonimin',
                Icons.cancel_rounded,
                destructive: true,
              ),
              _Action(
                'expire',
                'Skado abonimin',
                Icons.timer_off_rounded,
                destructive: true,
              ),
            ]);
          }
        }
        break;
      case 'support':
        if (item.status == 'open') {
          actions.add(
              const _Action('start', 'Merr në punë', Icons.play_arrow_rounded));
        }
        if (!{'resolved', 'closed'}.contains(item.status)) {
          actions.addAll(const [
            _Action('wait', 'Në pritje të përdoruesit',
                Icons.hourglass_bottom_rounded),
            _Action('resolve', 'Shëno të zgjidhur', Icons.task_alt_rounded),
            _Action('close', 'Mbyll ticket', Icons.cancel_rounded),
          ]);
        }
        break;
      case 'admins':
        if (_snapshot?.adminRole == 'super_admin') {
          actions.add(const _Action(
              'role_local', 'Ndrysho rol', Icons.manage_accounts_rounded));
          actions.add(_Action(
            item.status == 'active' ? 'deactivate' : 'activate',
            item.status == 'active' ? 'Çaktivizo adminin' : 'Aktivizo adminin',
            item.status == 'active'
                ? Icons.person_off_rounded
                : Icons.person_rounded,
            destructive: item.status == 'active',
          ));
        }
        break;
      case 'settings':
        actions.add(
            const _Action('setting_local', 'Ndrysho vlerën', Icons.edit_rounded));
        break;
    }

    return actions;
  }

  Future<void> _handleAction(AdminModuleItem item, _Action action) async {
    if (action.key == 'view') {
      if (widget.moduleKey == 'support') {
        await _showSupportThread(item);
      } else {
        await _showDetails(item);
      }
      return;
    }
    if (action.key == 'edit_local') {
      await _editCategory(item);
      return;
    }
    if (action.key == 'role_local') {
      await _editAdminRole(item);
      return;
    }
    if (action.key == 'setting_local') {
      await _editSetting(item);
      return;
    }
    if (action.key == 'open_document_local') {
      await _openProviderDocument(item.detail);
      return;
    }
    if (action.key == 'open_payment_proof_local') {
      await _openProviderDocument(
        (item.data['proof_storage_path'] ?? '').toString(),
      );
      return;
    }

    Map<String, dynamic> payload = const {};

    if ({'cancel'}.contains(action.key) &&
        {'requests', 'orders'}.contains(widget.moduleKey)) {
      final reason = await _askText(
        title: 'Arsyeja',
        label: 'Shkruaj arsyen',
        requiredValue: true,
      );
      if (reason == null) return;
      payload = {'reason': reason};
    } else if (widget.moduleKey == 'verifications' &&
        {'reject_document', 'reject_provider'}.contains(action.key)) {
      final reason = await _askText(
        title: 'Arsyeja e refuzimit',
        label: 'Shkruaj arsyen',
        requiredValue: true,
      );
      if (reason == null) return;
      payload = {'reason': reason};
    } else if (widget.moduleKey == 'offers' &&
        {'reject', 'expire'}.contains(action.key)) {
      final reason = await _askText(
        title: action.key == 'reject' ? 'Arsyeja e refuzimit' : 'Arsyeja e skadimit',
        label: 'Shkruaj arsyen',
        requiredValue: true,
      );
      if (reason == null) return;
      payload = {'reason': reason};
    } else if (widget.moduleKey == 'reviews' &&
        {'hide', 'remove'}.contains(action.key)) {
      final reason = await _askText(
        title: 'Arsyeja e moderimit',
        label: 'Shkruaj arsyen',
        requiredValue: true,
      );
      if (reason == null) return;
      payload = {'reason': reason};
    } else if (widget.moduleKey == 'reports' &&
        {'action', 'dismiss', 'close'}.contains(action.key)) {
      final note = await _askText(
        title: 'Shënim i raportimit',
        label: 'Shkruaj vendimin / arsyen',
        requiredValue: true,
      );
      if (note == null) return;
      payload = {'note': note};
    } else if (widget.moduleKey == 'disputes' &&
        {'resolve_client', 'resolve_provider', 'close'}.contains(action.key)) {
      final note = await _askText(
        title: 'Shënim vendimi',
        label: 'Shkruaj vendimin / arsyen',
        requiredValue: true,
      );
      if (note == null) return;
      payload = {'note': note};
    } else if (widget.moduleKey == 'finance' &&
        action.key != 'view') {
      final note = await _askText(
        title: 'Konfirmim financiar',
        label: 'Shënim / referencë e transaksionit',
        requiredValue: true,
      );
      if (note == null) return;
      payload = {'note': note};
    } else if (widget.moduleKey == 'subscriptions' &&
        action.key == 'reject_payment') {
      final reason = await _askText(
        title: 'Refuzo pagesën',
        label: 'Arsyeja e refuzimit',
        requiredValue: true,
      );
      if (reason == null) return;
      payload = {'reason': reason};
    } else if (widget.moduleKey == 'subscriptions' &&
        item.kind == 'subscription' &&
        action.key != 'view') {
      final note = await _askText(
        title: 'Ndryshim abonimi',
        label: 'Shënim / arsye',
        requiredValue: true,
      );
      if (note == null) return;
      payload = {'note': note};
    }

    final confirmed = !action.destructive ||
        await _confirm(
          title: action.label,
          message: 'Je i sigurt që dëshiron të vazhdosh?',
        );
    if (!confirmed) return;

    await _runRemote(
      () => AdminModulesRepository.instance.action(
        widget.moduleKey,
        item.id,
        action.key,
        payload,
      ),
      success: 'Veprimi u krye me sukses.',
    );
  }

  Future<void> _runRemote(
    Future<void> Function() request, {
    required String success,
  }) async {
    try {
      await request();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  Future<void> _openProviderDocument(String storagePath) async {
    final path = storagePath.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dokumenti nuk ka një file të vlefshëm.')),
      );
      return;
    }

    try {
      final url =
          await AdminModulesRepository.instance.signedProviderDocumentUrl(path);
      html.window.open(url, '_blank');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  Future<void> _showDetails(AdminModuleItem item) async {
    final fields = <MapEntry<String, dynamic>>[
      if (item.subtitle.trim().isNotEmpty)
        MapEntry('Përmbledhje', item.subtitle),
      if (item.detail.trim().isNotEmpty)
        MapEntry('Detaje', item.detail),
      if (item.metric != null && item.metric!.trim().isNotEmpty)
        MapEntry('Vlera', item.metric),
      if (item.status.trim().isNotEmpty)
        MapEntry('Status', _statusLabel(item.status)),
      ...item.data.entries.where((entry) {
        final value = entry.value;
        if (value == null) return false;
        if (value is String && value.trim().isEmpty) return false;
        return true;
      }),
    ];

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final field in fields)
                  Container(
                    width: 330,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _humanizeKey(field.key),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        SelectableText(
                          _formatDetailValue(field.value),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
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

  Future<void> _showSupportThread(AdminModuleItem item) async {
    Map<String, dynamic> data;
    try {
      data = await AdminModulesRepository.instance.supportThread(item.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
      return;
    }

    if (!mounted) return;
    final rawTicket = data['ticket'];
    final ticket = rawTicket is Map
        ? Map<String, dynamic>.from(rawTicket)
        : <String, dynamic>{};
    final messages = data['messages'] is List
        ? (data['messages'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final reply = TextEditingController();
    final canReply = _canWriteCurrentModule &&
        (ticket['status'] ?? '').toString() != 'closed';

    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text((ticket['subject'] ?? item.title).toString()),
        content: SizedBox(
          width: 720,
          height: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    icon: Icons.person_outline_rounded,
                    text: (ticket['user_name'] ?? 'Përdorues').toString(),
                  ),
                  _InfoPill(
                    icon: Icons.flag_outlined,
                    text: (ticket['priority'] ?? 'normal').toString(),
                  ),
                  _InfoPill(
                    icon: Icons.info_outline_rounded,
                    text: _statusLabel((ticket['status'] ?? '').toString()),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Nuk ka mesazhe në këtë ticket.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.separated(
                        itemCount: messages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isAdmin =
                              (message['sender_type'] ?? '').toString() == 'admin';
                          return Align(
                            alignment: isAdmin
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 520),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: .09)
                                    : const Color(0xFFF4F6F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (message['sender_name'] ??
                                            (isAdmin ? 'Admin' : 'Përdorues'))
                                        .toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text((message['body'] ?? '').toString()),
                                  if ((message['attachment_path'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Bashkëngjitje: ' +
                                          message['attachment_path'].toString(),
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (canReply) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: reply,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Përgjigju përdoruesit',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mbyll'),
          ),
          if (canReply)
            FilledButton.icon(
              onPressed: () {
                final text = reply.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(context, text);
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Dërgo'),
            ),
        ],
      ),
    );

    reply.dispose();
    if (body == null || body.trim().isEmpty) return;

    await _runRemote(
      () => AdminModulesRepository.instance.replySupport(item.id, body),
      success: 'Përgjigjja u dërgua.',
    );
  }
  Future<void> _createCategory() async {
    final result = await _categoryDialog();
    if (result == null) return;
    await _runRemote(
      () => AdminModulesRepository.instance
          .action('categories', '', 'create', result),
      success: 'Kategoria u shtua.',
    );
  }

  Future<void> _editCategory(AdminModuleItem item) async {
    final result = await _categoryDialog(
      initialName: item.title,
      initialDescription: item.detail,
      initialIcon: (item.data['icon_key'] ?? '').toString(),
      initialSort: (item.data['sort_order'] ?? 100).toString(),
      initialTranslations: item.data['translations'] is Map
          ? Map<String, dynamic>.from(item.data['translations'] as Map)
          : const <String, dynamic>{},
    );
    if (result == null) return;
    await _runRemote(
      () => AdminModulesRepository.instance
          .action('categories', item.id, 'rename', result),
      success: 'Kategoria u përditësua.',
    );
  }

  Future<Map<String, dynamic>?> _categoryDialog({
    String initialName = '',
    String initialDescription = '',
    String initialIcon = '',
    String initialSort = '100',
    Map<String, dynamic> initialTranslations = const <String, dynamic>{},
  }) async {
    const languages = <(String, String)>[
      ('sq', 'Shqip'),
      ('en', 'English'),
      ('fr', 'Français'),
      ('de', 'Deutsch'),
      ('it', 'Italiano'),
    ];

    final names = <String, TextEditingController>{};
    final descriptions = <String, TextEditingController>{};

    for (final language in languages) {
      final raw = initialTranslations[language.$1];
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      names[language.$1] = TextEditingController(
        text: language.$1 == 'sq'
            ? (map['name'] ?? initialName).toString()
            : (map['name'] ?? '').toString(),
      );
      descriptions[language.$1] = TextEditingController(
        text: language.$1 == 'sq'
            ? (map['description'] ?? initialDescription).toString()
            : (map['description'] ?? '').toString(),
      );
    }

    final icon = TextEditingController(text: initialIcon);
    final sort = TextEditingController(text: initialSort);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialName.isEmpty ? 'Shto kategori' : 'Ndrysho kategori'),
        content: SizedBox(
          width: 620,
          height: 560,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final language in languages) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      language.$2,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: names[language.$1],
                    decoration: InputDecoration(
                      labelText: 'Emri (' + language.$1.toUpperCase() + ')',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptions[language.$1],
                    decoration: InputDecoration(
                      labelText: 'Përshkrimi (' + language.$1.toUpperCase() + ')',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: icon,
                  decoration: const InputDecoration(labelText: 'Icon key'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sort,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Renditja'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulo'),
          ),
          FilledButton(
            onPressed: () {
              final sqName = names['sq']!.text.trim();
              if (sqName.isEmpty) return;

              final translations = <String, dynamic>{};
              for (final language in languages) {
                translations[language.$1] = {
                  'name': names[language.$1]!.text.trim(),
                  'description': descriptions[language.$1]!.text.trim(),
                };
              }

              Navigator.pop(context, {
                'name': sqName,
                'description': descriptions['sq']!.text.trim(),
                'icon_key': icon.text.trim(),
                'sort_order': int.tryParse(sort.text.trim()) ?? 100,
                'translations': translations,
              });
            },
            child: const Text('Ruaj'),
          ),
        ],
      ),
    );

    for (final controller in names.values) {
      controller.dispose();
    }
    for (final controller in descriptions.values) {
      controller.dispose();
    }
    icon.dispose();
    sort.dispose();
    return result;
  }
  Future<void> _broadcastNotification() async {
    final title = TextEditingController();
    final body = TextEditingController();
    String target = 'all';

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Dërgo njoftim'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: target,
                  decoration: const InputDecoration(labelText: 'Marrësit'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Të gjithë')),
                    DropdownMenuItem(
                        value: 'citizens', child: Text('Vetëm qytetarët')),
                    DropdownMenuItem(
                        value: 'providers', child: Text('Vetëm mjeshtrat')),
                  ],
                  onChanged: (value) =>
                      setLocalState(() => target = value ?? 'all'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Titulli'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: body,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Mesazhi'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Anulo')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(context, {
                  'target': target,
                  'title': title.text.trim(),
                  'body': body.text.trim(),
                });
              },
              child: const Text('Dërgo'),
            ),
          ],
        ),
      ),
    );

    if (payload == null) return;
    await _runRemote(
      () => AdminModulesRepository.instance
          .action('notifications', '', 'broadcast', payload),
      success: 'Njoftimi u krijua për marrësit e zgjedhur.',
    );
  }

  Future<void> _addAdmin() async {
    final email = TextEditingController();
    final name = TextEditingController();
    String role = 'admin';

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Shto administrator'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  decoration: const InputDecoration(
                      labelText: 'Email i përdoruesit ekzistues'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'Emri i shfaqur'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Roli'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'support', child: Text('Support')),
                    DropdownMenuItem(value: 'finance', child: Text('Finance')),
                    DropdownMenuItem(
                        value: 'super_admin', child: Text('Super Admin')),
                  ],
                  onChanged: (value) =>
                      setLocalState(() => role = value ?? 'admin'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Anulo')),
            FilledButton(
              onPressed: () {
                if (!email.text.contains('@')) return;
                Navigator.pop(context, {
                  'email': email.text.trim(),
                  'display_name': name.text.trim(),
                  'role': role,
                });
              },
              child: const Text('Shto'),
            ),
          ],
        ),
      ),
    );

    if (payload == null) return;
    await _runRemote(
      () =>
          AdminModulesRepository.instance.action('admins', '', 'add', payload),
      success: 'Administratori u shtua.',
    );
  }

  Future<void> _editAdminRole(AdminModuleItem item) async {
    String role = (item.data['role'] ?? 'admin').toString();
    final next = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Ndrysho rolin'),
          content: DropdownButtonFormField<String>(
            initialValue: role,
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'support', child: Text('Support')),
              DropdownMenuItem(value: 'finance', child: Text('Finance')),
              DropdownMenuItem(
                  value: 'super_admin', child: Text('Super Admin')),
            ],
            onChanged: (value) =>
                setLocalState(() => role = value ?? 'admin'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Anulo')),
            FilledButton(
                onPressed: () => Navigator.pop(context, role),
                child: const Text('Ruaj')),
          ],
        ),
      ),
    );
    if (next == null) return;
    await _runRemote(
      () => AdminModulesRepository.instance
          .action('admins', item.id, 'set_role', {'role': next}),
      success: 'Roli u përditësua.',
    );
  }

  Future<void> _editSetting(AdminModuleItem item) async {
    final controller =
        TextEditingController(text: _settingText(item.data['value']));
    bool isPublic = item.data['is_public'] == true;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('Ndrysho ${item.title}'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Vlera JSON ose tekst',
                    alignLabelWithHint: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isPublic,
                  title: const Text('Konfigurim publik'),
                  onChanged: (value) =>
                      setLocalState(() => isPublic = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Anulo')),
            FilledButton(
              onPressed: () {
                dynamic value;
                final text = controller.text.trim();
                try {
                  value = jsonDecode(text);
                } catch (_) {
                  value = text;
                }
                Navigator.pop(context, {
                  'value': value,
                  'is_public': isPublic,
                });
              },
              child: const Text('Ruaj'),
            ),
          ],
        ),
      ),
    );

    if (payload == null) return;
    await _runRemote(
      () => AdminModulesRepository.instance
          .action('settings', item.id, 'update', payload),
      success: 'Konfigurimi u përditësua.',
    );
  }

  String _settingText(dynamic value) {
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value?.toString() ?? '';
  }

  Future<String?> _askText({
    required String title,
    required String label,
    required bool requiredValue,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anulo')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (requiredValue && value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: const Text('Vazhdo'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Jo')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Po, vazhdo')),
            ],
          ),
        ) ??
        false;
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.black54),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
class _PageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const _PageHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final heading = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.4)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54)),
                ],
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 18),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        );
      },
    );
  }
}

class _SubscriptionPricingCard extends StatelessWidget {
  const _SubscriptionPricingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final monthly = _PlanBox(
              title: 'Abonim Mujor',
              price: '2,000 ALL / muaj',
              detail: 'Tick blu: +500 ALL, vetëm 1 herë në 12 muaj.',
              icon: Icons.calendar_month_rounded,
            );
            final yearly = _PlanBox(
              title: 'Abonim Vjetor',
              price: '20,000 ALL / vit',
              detail: 'Tick blu përfshihet falas për 12 muaj.',
              icon: Icons.workspace_premium_rounded,
            );
            if (constraints.maxWidth < 760) {
              return Column(
                children: [
                  monthly,
                  const SizedBox(height: 10),
                  yearly,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: monthly),
                const SizedBox(width: 10),
                Expanded(child: yearly),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanBox extends StatelessWidget {
  final String title;
  final String price;
  final String detail;
  final IconData icon;

  const _PlanBox({
    required this.title,
    required this.price,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(price,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(detail,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final Map<String, dynamic> values;
  const _SummaryGrid({required this.values});

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 580
            ? 2
            : constraints.maxWidth < 950
                ? 3
                : 4;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                        const SizedBox(height: 7),
                        Text(
                          _formatValue(entry.value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 22),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  final String query;
  final String status;
  final List<String> statuses;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusChanged;

  const _Filters({
    required this.query,
    required this.status,
    required this.statuses,
    required this.onQueryChanged,
    required this.onStatusChanged,
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
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Kërko...',
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
                const DropdownMenuItem(value: 'all', child: Text('Të gjitha')),
                for (final value in statuses)
                  DropdownMenuItem(
                    value: value,
                    child: Text(_statusLabel(value)),
                  ),
              ],
              onChanged: (value) => onStatusChanged(value ?? 'all'),
            );

            if (constraints.maxWidth < 650) {
              return Column(
                children: [search, const SizedBox(height: 10), filter],
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

class _DesktopTable extends StatelessWidget {
  final List<AdminModuleItem> items;
  final List<_Action> Function(AdminModuleItem) actionsFor;
  final Future<void> Function(AdminModuleItem, _Action) onAction;

  const _DesktopTable({
    required this.items,
    required this.actionsFor,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Emri', style: _headStyle)),
                Expanded(flex: 3, child: Text('Info', style: _headStyle)),
                Expanded(flex: 2, child: Text('Status', style: _headStyle)),
                Expanded(flex: 2, child: Text('Vlera', style: _headStyle)),
                SizedBox(width: 48),
              ],
            ),
          ),
          for (final item in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: Color(0xFFF0F2F6))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        if (item.detail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(item.detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(item.subtitle.isEmpty ? '—' : item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: _StatusChip(value: item.status)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(item.metric ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  SizedBox(
                    width: 48,
                    child: _ActionMenu(
                      actions: actionsFor(item),
                      onSelected: (action) => onAction(item, action),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileItemCard extends StatelessWidget {
  final AdminModuleItem item;
  final List<_Action> actions;
  final Future<void> Function(_Action) onAction;

  const _MobileItemCard({
    required this.item,
    required this.actions,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.subtitle,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12.5)),
                  ],
                  if (item.detail.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(item.detail,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5)),
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusChip(value: item.status),
                      if (item.metric != null)
                        Text(item.metric!,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
            _ActionMenu(actions: actions, onSelected: onAction),
          ],
        ),
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  final List<_Action> actions;
  final ValueChanged<_Action> onSelected;

  const _ActionMenu({required this.actions, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Action>(
      tooltip: 'Veprime',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem(
            value: action,
            child: Row(
              children: [
                Icon(action.icon,
                    size: 18,
                    color: action.destructive ? Colors.red : null),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(action.label,
                      style: TextStyle(
                          color: action.destructive ? Colors.red : null)),
                ),
              ],
            ),
          ),
      ],
      icon: const Icon(Icons.more_vert_rounded),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String value;
  const _StatusChip({required this.value});

  @override
  Widget build(BuildContext context) {
    final normalized = value.toLowerCase();
    final positive = {
      'active',
      'approved',
      'paid',
      'completed',
      'published',
      'resolved',
      'resolved_client',
      'resolved_provider',
      'actioned',
      'read',
    }.contains(normalized);
    final warning = {
      'pending',
      'reviewing',
      'in_progress',
      'past_due',
      'trialing',
      'open',
      'unread',
      'evidence',
      'waiting_user',
      'needs_attention',
      'unverified',
      'reschedule_pending',
      'completion_pending',
    }.contains(normalized);

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
        _statusLabel(value),
        style: TextStyle(
            color: color, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool spinning;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.spinning = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
        child: Center(
          child: Column(
            children: [
              if (spinning)
                const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
              else
                Icon(icon, size: 38, color: Colors.black38),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54)),
              ],
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                    onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Action {
  final String key;
  final String label;
  final IconData icon;
  final bool destructive;

  const _Action(this.key, this.label, this.icon, {this.destructive = false});
}

const _headStyle =
    TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black54);

String _statusLabel(String value) {
  return switch (value) {
    'active' => 'Aktiv',
    'inactive' => 'Jo aktiv',
    'pending' => 'Në pritje',
    'approved' => 'Aprovuar',
    'rejected' => 'Refuzuar',
    'suspended' => 'Pezulluar',
    'published' => 'Publikuar',
    'hidden' => 'Fshehur',
    'removed' => 'Hequr',
    'open' => 'Hapur',
    'reviewing' => 'Në shqyrtim',
    'actioned' => 'Vepruar',
    'dismissed' => 'Hedhur poshtë',
    'closed' => 'Mbyllur',
    'submitted' => 'Dërguar',
    'accepted' => 'Pranuar',
    'withdrawn' => 'Tërhequr',
    'expired' => 'Skaduar',
    'completed' => 'Përfunduar',
    'cancelled' => 'Anuluar',
    'paid' => 'Paguar',
    'waived' => 'Hequr',
    'processing' => 'Në proces',
    'past_due' => 'Past due',
    'trialing' => 'Trial',
    'resolved' => 'Zgjidhur',
    'waiting_user' => 'Pritet përdoruesi',
    'resolved_client' => 'Për klientin',
    'resolved_provider' => 'Për mjeshtrin',
    'unread' => 'Pa lexuar',
    'read' => 'Lexuar',
    'public' => 'Publik',
    'private' => 'Privat',
    'logged' => 'Regjistruar',
    'needs_attention' => 'Kërkon vëmendje',
    'unverified' => 'Pa verifikuar',
    'searching' => 'Në kërkim',
    'offers_received' => 'Ka oferta',
    'booked' => 'Rezervuar',
    'reschedule_pending' => 'Riplanifikim pending',
    'provider_on_way' => 'Mjeshtri në rrugë',
    'arrived' => 'Mbërritur',
    'completion_pending' => 'Pret përfundimin',
    'disputed' => 'Në mosmarrëveshje',
    'authorized' => 'Autorizuar',
    'failed' => 'Dështuar',
    'partially_refunded' => 'Rimbursuar pjesërisht',
    'refunded' => 'Rimbursuar',
    'deletion_requested' => 'Kërkon fshirje',
    _ => value.isEmpty ? '—' : value,
  };
}

String _formatValue(dynamic value) {
  if (value == null) return '0';
  if (value is num) {
    if (value is double && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
  return value.toString();
}

String _humanizeKey(String key) {
  const labels = <String, String>{
    'provider_id': 'Mjeshtri',
    'client_id': 'Qytetari',
    'request_id': 'Kërkesa',
    'order_id': 'Puna',
    'payment_id': 'Pagesa',
    'document_type': 'Lloji i dokumentit',
    'expires_at': 'Skadon',
    'reviewed_at': 'Shqyrtuar më',
    'created_at': 'Krijuar më',
    'updated_at': 'Përditësuar më',
    'scheduled_for': 'Planifikuar për',
    'cancel_reason': 'Arsye anulimi',
    'resolution_note': 'Shënim vendimi',
    'external_reference': 'Referencë e jashtme',
    'plan_code': 'Plani',
    'monthly_price': 'Vlera mujore për MRR',
    'price_amount': 'Çmimi i planit',
    'base_amount': 'Abonimi',
    'verification_fee': 'Verifikimi / Tick blu',
    'total_amount': 'Totali',
    'billing_cycle': 'Periudha',
    'proof_storage_path': 'Prova e pagesës',
    'bank_reference': 'Referenca bankare',
    'wants_blue_tick': 'Kërkon tick blu',
    'blue_tick_included': 'Tick blu i përfshirë',
    'blue_tick_active': 'Tick blu aktiv',
    'blue_tick_expires_at': 'Tick blu skadon',
    'blue_tick_fee_amount': 'Pagesa për Tick blu',
    'blue_tick_fee_paid_declared': '500 ALL të përfshira në pagesë',
    'blue_tick_fee_status': 'Statusi i 500 ALL / Tick blu',
    'approved_subscription_id': 'Abonimi i aktivizuar',
    'is_verified': 'I verifikuar',
    'is_active': 'Aktiv',
    'sort_order': 'Renditja',
    'icon_key': 'Ikona',
    'notification_type': 'Lloji i njoftimit',
  };
  return labels[key] ??
      key
          .replaceAll('_', ' ')
          .split(' ')
          .map((part) => part.isEmpty
              ? part
              : part.substring(0, 1).toUpperCase() + part.substring(1))
          .join(' ');
}

String _formatDetailValue(dynamic value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Po' : 'Jo';
  if (value is Map || value is List) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }
  final text = value.toString();
  final date = DateTime.tryParse(text);
  if (date != null && text.contains('-')) {
    final local = date.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} • $h:$min';
  }
  return text.trim().isEmpty ? '—' : text;
}

String _friendlyError(Object error) {
  final text = error.toString();
  final lower = text.toLowerCase();
  if (text.contains('42501') ||
      lower.contains('authorized') ||
      lower.contains('insufficient admin')) {
    return 'Nuk ke leje për këtë veprim.';
  }
  if (text.contains('23514')) {
    if (lower.contains('super admin')) {
      return 'Duhet të mbetet të paktën një Super Admin aktiv.';
    }
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
  if (text.contains('23505') || lower.contains('duplicate')) {
    return 'Ekziston tashmë një rekord me këto të dhëna.';
  }
  if (text.contains('P0002')) {
    return 'Rekordi nuk u gjet, është mbyllur ose është ndryshuar.';
  }
  if (lower.contains('invalid') || text.contains('22023')) {
    return 'Veprimi ose vlera e zgjedhur nuk është e vlefshme.';
  }
  return 'Ndodhi një gabim. Rifresko faqen dhe provo përsëri.';
}
