import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/admin_repository.dart';

class NavItem {
  final String label;
  final String path;
  final IconData icon;
  const NavItem(this.label, this.path, this.icon);
}

const navItems = <NavItem>[
  NavItem('Dashboard', '/dashboard', Icons.space_dashboard_rounded),
  NavItem('Qytetarët', '/citizens', Icons.people_alt_rounded),
  NavItem('Mjeshtrat', '/providers', Icons.handyman_rounded),
  NavItem('Verifikime', '/verifications', Icons.verified_user_rounded),
  NavItem('Kategori & Shërbime', '/categories', Icons.grid_view_rounded),
  NavItem('Kërkesat', '/requests', Icons.assignment_rounded),
  NavItem('Ofertat', '/offers', Icons.local_offer_rounded),
  NavItem('Punët', '/orders', Icons.work_rounded),
  NavItem('Vlerësimet', '/reviews', Icons.star_rounded),
  NavItem('Raportimet', '/reports', Icons.flag_rounded),
  NavItem('Mosmarrëveshjet', '/disputes', Icons.gavel_rounded),
  NavItem('Financat', '/finance', Icons.account_balance_wallet_rounded),
  NavItem('Abonimet', '/subscriptions', Icons.workspace_premium_rounded),
  NavItem('Njoftimet', '/notifications', Icons.notifications_active_rounded),
  NavItem('Support', '/support', Icons.support_agent_rounded),
  NavItem('Analitika', '/analytics', Icons.query_stats_rounded),
  NavItem('Administratorët', '/admins', Icons.admin_panel_settings_rounded),
  NavItem('Regjistri i Auditit', '/audit', Icons.history_rounded),
  NavItem('Cilësimet', '/settings', Icons.settings_rounded),
];

List<NavItem> _allowedNavItems(String? role) {
  if (role == null || role == 'super_admin' || role == 'admin') {
    return navItems;
  }

  const supportPaths = <String>{
    '/dashboard',
    '/citizens',
    '/providers',
    '/verifications',
    '/requests',
    '/offers',
    '/orders',
    '/reviews',
    '/reports',
    '/disputes',
    '/notifications',
    '/support',
    '/analytics',
  };
  const financePaths = <String>{
    '/dashboard',
    '/providers',
    '/finance',
    '/subscriptions',
    '/analytics',
  };

  final allowed = role == 'support'
      ? supportPaths
      : role == 'finance'
          ? financePaths
          : const <String>{'/dashboard'};
  return navItems.where((item) => allowed.contains(item.path)).toList();
}

class AdminShell extends StatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  bool _collapsed = false;
  Map<String, dynamic>? _admin;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    try {
      final data = await AdminRepository.instance.currentAdmin();
      if (mounted) setState(() => _admin = data);
    } catch (_) {
      // Routing already verifies the admin session. Keep the shell usable if
      // the small profile lookup fails temporarily.
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1180;
    final role = _admin?['role']?.toString();

    return Scaffold(
      drawer: compact
          ? Drawer(
              width: 292,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(24)),
              ),
              child: _Sidebar(
                collapsed: false,
                mobile: true,
                role: role,
              ),
            )
          : null,
      body: Row(
        children: [
          if (!compact)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _collapsed ? 88 : 278,
              child: _Sidebar(
                collapsed: _collapsed,
                mobile: false,
                role: role,
                onToggle: () =>
                    setState(() => _collapsed = !_collapsed),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  compact: compact,
                  role: role,
                  displayName: _admin?['display_name']?.toString(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      width < 700 ? 16 : 28,
                      width < 700 ? 18 : 26,
                      width < 700 ? 16 : 28,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1480),
                        child: widget.child,
                      ),
                    ),
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

class _TopBar extends StatelessWidget {
  final bool compact;
  final String? role;
  final String? displayName;

  const _TopBar({
    required this.compact,
    required this.role,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showSearch = width >= 760;
    final allowedItems = _allowedNavItems(role);
    final name = (displayName ?? '').trim();
    final initials = _initials(name.isEmpty ? _roleLabel(role) : name);

    return Container(
      height: compact ? 68 : 74,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F6))),
      ),
      child: Row(
        children: [
          if (compact)
            Builder(
              builder: (innerContext) => IconButton.filledTonal(
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(innerContext).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          if (compact) const SizedBox(width: 10),
          if (compact)
            Expanded(
              child: Image.asset(
                'assets/branding/e_mjeshtri_logo.png',
                height: 35,
                alignment: Alignment.centerLeft,
                fit: BoxFit.contain,
              ),
            )
          else
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'e-Mjeshtri Admin',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      letterSpacing: -.2,
                    ),
                  ),
                  Text(
                    _roleLabel(role),
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (showSearch)
            SizedBox(
              width: width > 1320 ? 340 : 270,
              height: 46,
              child: TextField(
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => _search(context, value, allowedItems),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  hintText: 'Kërko modul...',
                  isDense: true,
                ),
              ),
            ),
          if (showSearch) const SizedBox(width: 10),
          if (allowedItems.any((item) => item.path == '/notifications'))
            IconButton(
              tooltip: 'Njoftimet',
              onPressed: () => context.go('/notifications'),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: 'Llogaria',
            onSelected: (value) async {
              if (value != 'logout') return;
              await AdminRepository.instance.signOut();
              if (context.mounted) context.go('/login');
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Administrator' : name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      _roleLabel(role),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Dil nga paneli'),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFFEAF2FC),
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _search(BuildContext context, String raw, List<NavItem> allowedItems) {
    final query = _normalize(raw);
    if (query.isEmpty) return;

    for (final item in allowedItems) {
      final label = _normalize(item.label);
      final path = _normalize(item.path.replaceAll('/', ''));
      if (label.contains(query) ||
          query.contains(label) ||
          path.contains(query) ||
          query.contains(path)) {
        context.go(item.path);
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nuk u gjet modul me këtë kërkim.')),
    );
  }

  String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('ë', 'e')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}

class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final bool mobile;
  final String? role;
  final VoidCallback? onToggle;

  const _Sidebar({
    required this.collapsed,
    required this.mobile,
    required this.role,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final items = _allowedNavItems(role);

    Future<void> navigate(String path) async {
      if (mobile) {
        Navigator.of(context).pop();
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      if (context.mounted) context.go(path);
    }

    return Container(
      color: AppColors.navy,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                collapsed ? 14 : 18,
                18,
                collapsed ? 14 : 18,
                16,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: collapsed ? 48 : 132,
                    height: 46,
                    child: Image.asset(
                      'assets/branding/e_mjeshtri_logo.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  if (!collapsed) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _roleShort(role),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!collapsed)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: .10),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _NavTile(
                        item: item,
                        selected: location == item.path,
                        collapsed: collapsed,
                        onTap: () => navigate(item.path),
                      ),
                    ),
                ],
              ),
            ),
            if (!mobile && onToggle != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  tooltip: collapsed ? 'Zgjero menunë' : 'Ngushto menunë',
                  onPressed: onToggle,
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_double_arrow_right_rounded
                        : Icons.keyboard_double_arrow_left_rounded,
                    color: Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? item.label : '',
      child: Material(
        color:
            selected ? Colors.white.withValues(alpha: .14) : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 14 : 12,
              vertical: 11,
            ),
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  color: selected ? Colors.white : Colors.white70,
                  size: 21,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _roleLabel(String? role) {
  return switch (role) {
    'super_admin' => 'Super Admin',
    'admin' => 'Admin',
    'support' => 'Support',
    'finance' => 'Finance',
    _ => 'Administrator',
  };
}

String _roleShort(String? role) {
  return switch (role) {
    'super_admin' => 'SUPER',
    'support' => 'SUPPORT',
    'finance' => 'FINANCE',
    _ => 'ADMIN',
  };
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'AD';
  if (words.length == 1) {
    final word = words.first;
    return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (words.first.substring(0, 1) + words.last.substring(0, 1))
      .toUpperCase();
}