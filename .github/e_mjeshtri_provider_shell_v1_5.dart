import 'package:flutter/material.dart';

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
