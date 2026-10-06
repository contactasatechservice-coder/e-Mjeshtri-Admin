import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (file == null) return;

    final length = file.lengthSync() ?? await file.length();
    if (length == null || length <= 0) {
      _toast('Nuk u lexua dot skedari. Provo përsëri.', error: true);
      return;
    }

    const maxBytes = 8 * 1024 * 1024;
    if (length > maxBytes) {
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
    if (proof == null) {
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
      final bytes = await proof.readAsBytes();
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
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _providerId == null
              ? const SafeArea(
                  child: _CenteredMessage(
                    icon: Icons.handyman_outlined,
                    title: 'Kjo faqe është vetëm për mjeshtrat',
                    body:
                        'Llogaria jote nuk është e lidhur me një profil aktiv mjeshtri.',
                  ),
                )
              : SafeArea(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
                      children: [
                        const _SubscriptionHeader(),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          _ErrorCard(text: _error!),
                        ],
                        const SizedBox(height: 18),
                        for (final plan in _maps(_overview['plans'])) ...[
                          _PlanCard(
                            plan: plan,
                            selected: _selectedPlan == plan['code'],
                            wantsBlueTick:
                                _wantsBlueTick || _blueTick['active'] == true,
                            blueTickActive: _blueTick['active'] == true,
                            onTap: () =>
                                _selectPlan(plan['code'].toString()),
                            onBlueTickChanged:
                                plan['billing_cycle'] == 'yearly'
                                    ? null
                                    : _toggleBlueTick,
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
                          onPick:
                              _pendingPayment == null ? _pickProof : null,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _bankReference,
                          enabled: _pendingPayment == null,
                          decoration: InputDecoration(
                            labelText: 'Referenca bankare (opsionale)',
                            hintText: 'P.sh. TRX123456',
                            prefixIcon:
                                const Icon(Icons.numbers_rounded),
                            filled: true,
                            fillColor:
                                AppColors.blue.withValues(alpha: .035),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color:
                                    AppColors.blue.withValues(alpha: .12),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color:
                                    AppColors.blue.withValues(alpha: .12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _StatusCard(
                          subscription: _currentSubscription,
                          pendingPayment: _pendingPayment,
                          blueTick: _blueTick,
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: .035),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.blue.withValues(alpha: .14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Color(0xFFEAF3FF),
                                    child: Icon(
                                      Icons.support_agent_rounded,
                                      color: AppColors.blue,
                                    ),
                                  ),
                                  SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ke problem me abonimin?',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.blueDark,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Na shkruaj direkt nga aplikacioni.',
                                          style: TextStyle(
                                            color: AppColors.muted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('/support/new'),
                                  icon: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                  ),
                                  label: const Text('Kontakto Suportin'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.blue,
                                    side: BorderSide(
                                      color: AppColors.blue
                                          .withValues(alpha: .28),
                                    ),
                                    minimumSize:
                                        const Size.fromHeight(50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(
                            _pendingPayment != null
                                ? 'Pagesa është në pritje'
                                : _sending
                                    ? 'Po dërgohet...'
                                    : 'Dërgo për verifikim',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
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

class _SubscriptionHeader extends StatelessWidget {
  const _SubscriptionHeader();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Image.asset(
            'assets/branding/e_mjeshtri_logo.png',
            height: 88,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 10),
          const Text(
            'Abonimi i Mjeshtrit',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: AppColors.blueDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Për të aktivizuar llogarinë, zgjidh një plan dhe ngarko provën e pagesës.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      );
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool selected;
  final bool wantsBlueTick;
  final bool blueTickActive;
  final VoidCallback onTap;
  final ValueChanged<bool>? onBlueTickChanged;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.wantsBlueTick,
    required this.blueTickActive,
    required this.onTap,
    required this.onBlueTickChanged,
  });

  @override
  Widget build(BuildContext context) {
    final yearly = plan['billing_cycle'] == 'yearly';
    final accent = yearly ? AppColors.orange : AppColors.blue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: yearly
                ? AppColors.orange.withValues(alpha: .055)
                : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? accent
                  : accent.withValues(alpha: yearly ? .28 : .14),
              width: selected ? 1.7 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .045),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: accent,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                yearly ? 'Plani Vjetor' : 'Plani Mujor',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.blueDark,
                                ),
                              ),
                            ),
                            if (yearly)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.orange
                                      .withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 15,
                                      color: AppColors.orange,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Më i leverdishëm',
                                      style: TextStyle(
                                        color: AppColors.orange,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_money(plan['price_amount'])} Lek / ${yearly ? 'vit' : 'muaj'}',
                          style: const TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? accent : AppColors.muted,
                    size: 27,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _FeatureLine(text: 'Përdorim i panelit të Mjeshtrit'),
              const _FeatureLine(text: 'Shfaqje në platformë'),
              const _FeatureLine(
                text: 'Menaxhim kërkesash dhe punësh',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              if (yearly)
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tick Blu falas',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.blueDark,
                            ),
                          ),
                          Text(
                            'Përfshihet në planin vjetor',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Falas',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tick Blu',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.blueDark,
                            ),
                          ),
                          Text(
                            '+500 Lek / vit',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: wantsBlueTick,
                      onChanged: blueTickActive
                          ? null
                          : (value) {
                              onBlueTickChanged?.call(value ?? false);
                            },
                    ),
                    const Text(
                      'Shto',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
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

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.blue.withValues(alpha: .12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFEAF3FF),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.blue,
                ),
              ),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Si bëhet pagesa?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.blueDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pagesa bëhet me transfertë bankare.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (!configured)
            const Text(
              'Administratori nuk i ka vendosur ende të dhënat bankare.',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: .10),
                ),
              ),
              child: Column(
                children: [
                  _KeyValue('Banka', _text(details['bank_name'])),
                  _KeyValue(
                    'Përfituesi',
                    _text(details['account_name']),
                  ),
                  _KeyValue(
                    'IBAN',
                    _text(details['iban']),
                    selectable: true,
                  ),
                  _KeyValue(
                    'Përshkrimi',
                    _text(details['note']) == '—'
                        ? 'Emri i biznesit / Abonimi e-Mjeshtri'
                        : _text(details['note']),
                  ),
                ],
              ),
            ),
        ],
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
  const _ProofCard({
    required this.proof,
    required this.pending,
    this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (pending != null) {
      final fee = _number(pending!['verification_fee']);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.orange.withValues(alpha: .24),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              color: AppColors.orange,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pagesa është në verifikim',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.blueDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fee >= 500
                        ? 'Admini do të kontrollojë abonimin dhe Tick-un Blu.'
                        : 'Admini po kontrollon provën e abonimit.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 19,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.blue.withValues(alpha: .34),
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_upload_rounded,
              color: AppColors.blue,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              proof?.name ?? 'Ngarko provën e pagesës',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'JPG, PNG ose PDF • maksimumi 8 MB',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
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
    final approved = subscription != null && pendingPayment == null;
    final pending = pendingPayment != null;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.orange.withValues(alpha: .12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFFFF1E4),
                child: Icon(
                  Icons.schedule_rounded,
                  color: AppColors.orange,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Statusi i aktivizimit',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.blueDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Llogaria juaj do të aktivizohet vetëm pas miratimit nga admini.',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatusStep(
                  icon: Icons.schedule_rounded,
                  label: 'Në pritje të\nverifikimit',
                  active: pending,
                  color: AppColors.orange,
                ),
              ),
              Expanded(
                child: _StatusStep(
                  icon: Icons.check_rounded,
                  label: 'Aprovuar\nnga Admini',
                  active: approved,
                  color: AppColors.success,
                ),
              ),
              const Expanded(
                child: _StatusStep(
                  icon: Icons.close_rounded,
                  label: 'Refuzuar\n(me arsye)',
                  active: false,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          if (approved) ...[
            const SizedBox(height: 12),
            Text(
              'Abonimi është aktiv deri më ${_date(subscription!['renews_at'])}.',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;

  const _StatusStep({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? color
                  : AppColors.muted.withValues(alpha: .14),
            ),
            child: Icon(
              icon,
              size: 20,
              color: active ? Colors.white : AppColors.muted,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.2,
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              color: active ? color : AppColors.muted,
            ),
          ),
        ],
      );
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