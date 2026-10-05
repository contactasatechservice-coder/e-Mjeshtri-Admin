import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../market/market_screen.dart';
import 'core.dart';
import 'home.dart';
import 'requests.dart';
import 'jobs.dart';
import 'messages.dart';
import 'profile.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({
    super.key,
    required this.providerId,
  });

  final String providerId;

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int index = 0;
  int workTab = 0;
  Timer? _locationTimer;
  bool _locationTickBusy = false;

  @override
  void initState() {
    super.initState();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _syncLiveLocation(),
    );
    Future<void>.delayed(const Duration(seconds: 1), _syncLiveLocation);
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncLiveLocation() async {
    if (_locationTickBusy || !mounted) return;
    _locationTickBusy = true;
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('service_orders')
          .select('id,status')
          .eq('provider_id', widget.providerId)
          .eq('status', 'provider_on_way')
          .limit(1);

      if (rows is! List || rows.isEmpty) return;
      final order = Map<String, dynamic>.from(rows.first as Map);
      final orderId = order['id']?.toString();
      if (orderId == null || orderId.isEmpty) return;

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      await client.from('order_live_locations').upsert(
        {
          'order_id': orderId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading.isFinite ? position.heading : null,
          'speed_kph':
              position.speed.isFinite ? position.speed * 3.6 : null,
          'accuracy_meters':
              position.accuracy.isFinite ? position.accuracy : null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'order_id',
      );
    } catch (_) {
      // Live location retries automatically on the next foreground tick.
    } finally {
      _locationTickBusy = false;
    }
  }

  void _openProviderTab(int requestedIndex) {
    setState(() {
      if (requestedIndex == 1) {
        workTab = 0;
        index = 1;
      } else if (requestedIndex == 2) {
        workTab = 1;
        index = 1;
      } else if (requestedIndex == 3) {
        index = 3;
      } else if (requestedIndex == 4) {
        index = 4;
      } else {
        index = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);

    final pages = [
      ProviderHome(
        providerId: widget.providerId,
        onTab: _openProviderTab,
      ),
      _ProviderWorkHub(
        key: ValueKey(workTab),
        providerId: widget.providerId,
        initialTab: workTab,
      ),
      const MarketScreen(audience: 'provider'),
      MessagesScreen(providerId: widget.providerId),
      ProviderProfileScreen(providerId: widget.providerId),
    ];

    final items = [
      (Icons.dashboard_rounded, t('home')),
      (Icons.work_rounded, t('jobs')),
      (Icons.storefront_rounded, 'e-Market'),
      (Icons.forum_rounded, t('messages')),
      (Icons.person_rounded, t('profile')),
    ];

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .075),
                blurRadius: 28,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == index;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => index = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.navy.withValues(alpha: .08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          items[i].$1,
                          color: selected ? AppColors.navy : AppColors.muted,
                          size: 23,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.2,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500,
                            color:
                                selected ? AppColors.navy : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ProviderWorkHub extends StatefulWidget {
  const _ProviderWorkHub({
    super.key,
    required this.providerId,
    required this.initialTab,
  });

  final String providerId;
  final int initialTab;

  @override
  State<_ProviderWorkHub> createState() => _ProviderWorkHubState();
}

class _ProviderWorkHubState extends State<_ProviderWorkHub> {
  late int selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initialTab.clamp(0, 1).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment<int>(
                  value: 0,
                  icon: const Icon(Icons.inbox_rounded),
                  label: Text(t('requests')),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: const Icon(Icons.work_rounded),
                  label: Text(t('jobs')),
                ),
              ],
              selected: {selected},
              onSelectionChanged: (value) {
                setState(() => selected = value.first);
              },
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: selected,
            children: [
              RequestsScreen(providerId: widget.providerId),
              JobsScreen(providerId: widget.providerId),
            ],
          ),
        ),
      ],
    );
  }
}
