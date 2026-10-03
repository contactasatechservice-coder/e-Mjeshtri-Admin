import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _client = Supabase.instance.client;
  final _bankReference = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _providerId;
  String? _selectedPlan;
  bool _wantsBlueTick = false;
  Map<String, dynamic> _overview = const {};
  Map<String, dynamic>? _quote;
  PlatformFile? _proof;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bankReference.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Duhet të jesh i identifikuar.');
      }

      final membership = await _client
          .from('provider_members')
          .select('provider_id')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      if (membership == null) {
        if (mounted) {
          setState(() {
            _providerId = null;
            _overview = const {};
          });
        }
        return;
      }

      final providerId = membership['provider_id'].toString();
      final raw = await _client.rpc(
        'provider_subscription_overview',
        params: {'p_provider_id': providerId},
      );
      final overview = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      final plans = _maps(overview['plans']);
      final defaultPlan = plans.any((p) => p['code'] == 'monthly')
          ? 'monthly'
          : plans.isNotEmpty
              ? plans.first['code']?.toString()
              : null;

      if (mounted) {
        setState(() {
          _providerId = providerId;
          _overview = overview;
          _selectedPlan ??= defaultPlan;
        });
      }
      await _refreshQuote();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshQuote() async {
    final providerId = _providerId;
    final plan = _selectedPlan;
    if (providerId == null || plan == null) return;
    try {
      final raw = await _client.rpc(
        'provider_subscription_quote',
        params: {
          'p_provider_id': providerId,
          'p_plan_code': plan,
          'p_wants_blue_tick': plan == 'yearly' ? true : _wantsBlueTick,
        },
      );
      if (mounted) {
        setState(() {
          _quote = raw is Map ? Map<String, dynamic>.from(raw) : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    }
  }

  Future<void> _selectPlan(String code) async {
    setState(() {
      _selectedPlan = code;
      if (code == 'yearly') _wantsBlueTick = true;
      _quote = null;
    });
    await _refreshQuote();
  }

  Future<void> _toggleBlueTick(bool value) async {
    setState(() {
      _wantsBlueTick = value;
      _quote = null;
    });
    await _refreshQuote();
  }

  Future<void> _pickProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      _toast('Nuk u lexua dot skedari. Provo përsëri.', error: true);
      return;
    }
    const maxBytes = 8 * 1024 * 1024;
    if (file.bytes!.length > maxBytes) {
      _toast('Prova e pagesës duhet të jetë më e vogël se 8 MB.', error: true);
      return;
    }
    setState(() => _proof = file);
  }

  Future<void> _submit() async {
    if (_sending) return;
    final providerId = _providerId;
    final plan = _selectedPlan;
    final proof = _proof;
    if (providerId == null || plan == null) return;
    if (_pendingPayment != null) {
      _toast('Ke një pagesë në pritje të aprovimit.', error: true);
      return;
    }
    if (proof?.bytes == null) {
      _toast('Ngarko provën e pagesës.', error: true);
      return;
    }
    if (!_hasBankDetails) {
      _toast('Të dhënat bankare nuk janë konfiguruar ende.', error: true);
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    String? uploadedPath;
    try {
      final safeName = _safeFileName(proof!.name);
      final path = '$providerId/subscriptions/'
          '${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final bytes = proof.bytes as Uint8List;
      await _client.storage.from('provider-documents').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(safeName),
              upsert: false,
            ),
          );
      uploadedPath = path;

      await _client.rpc(
        'provider_request_subscription',
        params: {
          'p_provider_id': providerId,
          'p_plan_code': plan,
          'p_wants_blue_tick': plan == 'yearly' ? true : _wantsBlueTick,
          'p_proof_storage_path': path,
          'p_bank_reference': _bankReference.text.trim().isEmpty
              ? null
              : _bankReference.text.trim(),
        },
      );

      _proof = null;
      _bankReference.clear();
      if (mounted) {
        _toast('Pagesa u dërgua. Pret aprovimin e Adminit.');
      }
      await _load();
    } catch (e) {
      if (uploadedPath != null) {
        try {
          await _client.storage
              .from('provider-documents')
              .remove([uploadedPath]);
        } catch (_) {}
      }
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : const <Map<String, dynamic>>[];

  Map<String, dynamic>? get _currentSubscription {
    final raw = _overview['current_subscription'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Map<String, dynamic>? get _pendingPayment {
    final raw = _overview['pending_payment'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Map<String, dynamic> get _blueTick {
    final raw = _overview['blue_tick'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  Map<String, dynamic> get _bankDetails {
    final raw = _overview['bank_details'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  bool get _hasBankDetails =>
      _text(_bankDetails['bank_name']) != '—' &&
      _text(_bankDetails['account_name']) != '—' &&
      _text(_bankDetails['iban']) != '—';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abonimi i Mjeshtrit')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _providerId == null
              ? const _CenteredMessage(
                  icon: Icons.handyman_outlined,
                  title: 'Kjo faqe është vetëm për mjeshtrat',
                  body:
                      'Llogaria jote nuk është e lidhur me një profil aktiv mjeshtri.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                    children: [
                      _StatusCard(
                        subscription: _currentSubscription,
                        pendingPayment: _pendingPayment,
                        blueTick: _blueTick,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorCard(text: _error!),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        'Zgjidh planin',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final plan in _maps(_overview['plans'])) ...[
                        _PlanCard(
                          plan: plan,
                          selected: _selectedPlan == plan['code'],
                          onTap: () => _selectPlan(plan['code'].toString()),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_selectedPlan == 'monthly') ...[
                        Card(
                          child: SwitchListTile.adaptive(
                            value: _wantsBlueTick || _blueTick['active'] == true,
                            onChanged: _blueTick['active'] == true
                                ? null
                                : _toggleBlueTick,
                            secondary: const Icon(
                              Icons.verified_rounded,
                              color: Colors.blue,
                            ),
                            title: const Text(
                              'Tick blu për 12 muaj',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              _blueTick['active'] == true
                                  ? 'Tick-u është tashmë aktiv deri ${_date(_blueTick['expires_at'])}. Nuk paguan 500 Lek përsëri.'
                                  : '+500 Lek vetëm një herë në 12 muaj.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_quote != null) ...[
                        _QuoteCard(quote: _quote!),
                        const SizedBox(height: 14),
                      ],
                      _BankCard(details: _bankDetails),
                      const SizedBox(height: 14),
                      _ProofCard(
                        proof: _proof,
                        pending: _pendingPayment,
                        onPick: _pendingPayment == null ? _pickProof : null,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bankReference,
                        enabled: _pendingPayment == null,
                        decoration: const InputDecoration(
                          labelText: 'Referenca bankare (opsionale)',
                          hintText: 'P.sh. TRX123456',
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _pendingPayment != null ||
                                !_hasBankDetails ||
                                _sending
                            ? null
                            : _submit,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(
                          _pendingPayment != null
                              ? 'Pagesa është në pritje'
                              : _sending
                                  ? 'Po dërgohet...'
                                  : 'Dërgo provën për aprovim',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      if (!_hasBankDetails) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Pagesa nuk mund të dërgohet derisa administratori të vendosë të dhënat bankare.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final yearly = plan['billing_cycle'] == 'yearly';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.blue : Colors.transparent,
              width: selected ? 2 : 0,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (yearly ? AppColors.orange : AppColors.blue)
                          .withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      yearly
                          ? Icons.workspace_premium_rounded
                          : Icons.calendar_month_rounded,
                      color: yearly ? AppColors.orange : AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (plan['name'] ?? '').toString(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          yearly ? '12 muaj' : '1 muaj',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? AppColors.blue : AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${_money(plan['price_amount'])} Lek${yearly ? '/vit' : '/muaj'}',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              _FeatureLine(
                text: yearly
                    ? 'Tick blu falas për 12 muaj'
                    : 'Tick blu opsional +500 Lek / 12 muaj',
                highlighted: yearly,
              ),
              const _FeatureLine(text: 'Aktivizohet pasi Admini verifikon pagesën'),
              const _FeatureLine(text: 'Pagesa me transfertë bankare'),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final String text;
  final bool highlighted;
  const _FeatureLine({required this.text, this.highlighted = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          children: [
            Icon(
              highlighted ? Icons.verified_rounded : Icons.check_circle_rounded,
              size: 18,
              color: highlighted ? Colors.blue : AppColors.success,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _QuoteCard extends StatelessWidget {
  final Map<String, dynamic> quote;
  const _QuoteCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    final verificationFee = _number(quote['verification_fee']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.blue.withValues(alpha: .16)),
      ),
      child: Column(
        children: [
          _AmountRow('Abonimi', quote['base_amount']),
          _AmountRow(
            'Tick blu',
            verificationFee,
            suffix: verificationFee > 0
                ? ' Lek'
                : quote['blue_tick_included'] == true
                    ? 'FALAS'
                    : '0 Lek',
          ),
          const Divider(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Totali për transfertë',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${_money(quote['total_amount'])} Lek',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final dynamic value;
  final String? suffix;
  const _AmountRow(this.label, this.value, {this.suffix});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              suffix ?? '${_money(value)} Lek',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

class _BankCard extends StatelessWidget {
  final Map<String, dynamic> details;
  const _BankCard({required this.details});

  @override
  Widget build(BuildContext context) {
    final configured = _text(details['bank_name']) != '—' &&
        _text(details['account_name']) != '—' &&
        _text(details['iban']) != '—';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_rounded, color: AppColors.blue),
                SizedBox(width: 9),
                Text(
                  'Të dhënat bankare',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!configured)
              const Text(
                'Administratori nuk i ka vendosur ende të dhënat bankare.',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              )
            else ...[
              _KeyValue('Banka', _text(details['bank_name'])),
              _KeyValue('Përfituesi', _text(details['account_name'])),
              _KeyValue('IBAN', _text(details['iban']), selectable: true),
              if (_text(details['note']) != '—')
                _KeyValue('Shënim', _text(details['note'])),
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;
  final bool selectable;
  const _KeyValue(this.label, this.value, {this.selectable = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            Expanded(
              child: selectable
                  ? SelectableText(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    )
                  : Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      );
}

class _ProofCard extends StatelessWidget {
  final PlatformFile? proof;
  final Map<String, dynamic>? pending;
  final VoidCallback? onPick;
  const _ProofCard({required this.proof, required this.pending, this.onPick});

  @override
  Widget build(BuildContext context) {
    if (pending != null) {
      final fee = _number(pending!['verification_fee']);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.orange.withValues(alpha: .25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.hourglass_top_rounded, color: AppColors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pagesa është në verifikim',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fee >= 500
                        ? 'Admini do të kontrollojë edhe 500 Lek për Tick-un blu.'
                        : 'Admini po kontrollon provën e abonimit.',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.receipt_long_rounded, color: AppColors.blue),
        title: Text(
          proof?.name ?? 'Ngarko provën e pagesës',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('JPG, PNG ose PDF • maksimumi 8 MB'),
        trailing: const Icon(Icons.upload_file_rounded),
        onTap: onPick,
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Map<String, dynamic>? subscription;
  final Map<String, dynamic>? pendingPayment;
  final Map<String, dynamic> blueTick;

  const _StatusCard({
    required this.subscription,
    required this.pendingPayment,
    required this.blueTick,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubscription = subscription != null;
    final tickActive = blueTick['active'] == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.blueDark, AppColors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Statusi i abonimit',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            pendingPayment != null
                ? 'Në pritje të aprovimit'
                : hasSubscription
                    ? _subscriptionLabel(subscription!)
                    : 'Pa abonim aktiv',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (hasSubscription) ...[
            const SizedBox(height: 5),
            Text(
              'Rinovim / skadim: ${_date(subscription!['renews_at'])}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: tickActive ? Colors.lightBlueAccent : Colors.white60,
                ),
                const SizedBox(width: 6),
                Text(
                  tickActive
                      ? 'Tick blu aktiv deri ${_date(blueTick['expires_at'])}'
                      : 'Tick blu jo aktiv',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
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

class _ErrorCard extends StatelessWidget {
  final String text;
  const _ErrorCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: AppColors.muted),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
}

String _safeFileName(String input) {
  final lower = input.trim().toLowerCase();
  final safe = lower.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
  return safe.isEmpty ? 'payment-proof.jpg' : safe;
}

String _contentType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.png')) return 'image/png';
  return 'image/jpeg';
}

String _friendlyError(Object error) {
  final text = error.toString();
  final lower = text.toLowerCase();
  if (lower.contains('provider must be approved')) {
    return 'Profili i mjeshtrit duhet të aprovohet para aktivizimit të abonimit.';
  }
  if (lower.contains('already pending')) {
    return 'Ke tashmë një pagesë në pritje të aprovimit.';
  }
  if (lower.contains('not authorized') || lower.contains('42501')) {
    return 'Nuk ke leje për këtë veprim.';
  }
  if (lower.contains('payment proof')) {
    return 'Prova e pagesës nuk u gjet ose nuk është e vlefshme.';
  }
  return 'Ndodhi një gabim. Provo përsëri.';
}

String _subscriptionLabel(Map<String, dynamic> sub) {
  final cycle = (sub['billing_cycle'] ?? '').toString();
  final status = (sub['status'] ?? '').toString();
  if (status == 'past_due') return 'Pagesë e vonuar';
  if (cycle == 'yearly') return 'Abonim Vjetor aktiv';
  return 'Abonim Mujor aktiv';
}

String _date(dynamic raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (d == null) return '—';
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '$day/$month/${d.year}';
}

String _text(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty || value == 'null' ? '—' : value;
}

double _number(dynamic raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0;
}

String _money(dynamic raw) {
  final value = _number(raw);
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}