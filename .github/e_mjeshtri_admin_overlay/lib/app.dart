import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'data/admin_repository.dart';
import 'screens/admin_module_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/list_screens.dart';
import 'screens/login_screen.dart';
import 'widgets/admin_shell.dart';

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final onLogin = state.matchedLocation == '/login';

    if (!loggedIn) return onLogin ? null : '/login';

    final isAdmin = await AdminRepository.instance.isCurrentUserAdmin();
    if (!isAdmin) {
      if (!onLogin) return '/login';
      return null;
    }

    if (onLogin) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
    ShellRoute(
      builder: (c, s, child) => AdminShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
        GoRoute(path: '/citizens', builder: (c, s) => const CitizensScreen()),
        GoRoute(path: '/providers', builder: (c, s) => const ProvidersScreen()),
        ..._moduleRoutes,
      ],
    ),
  ],
);

final _moduleRoutes = <RouteBase>[
  GoRoute(
    path: '/verifications',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'verifications',
      title: 'Verifikime',
      subtitle: 'Aplikime, dokumente dhe aprovime të mjeshtrave',
      icon: Icons.verified_user_rounded,
    ),
  ),
  GoRoute(
    path: '/categories',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'categories',
      title: 'Kategori & Shërbime',
      subtitle: 'Kategori, përkthime, renditje dhe aktivizim',
      icon: Icons.grid_view_rounded,
    ),
  ),
  GoRoute(
    path: '/requests',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'requests',
      title: 'Kërkesat',
      subtitle: 'Kërkesat reale të qytetarëve dhe lifecycle i tyre',
      icon: Icons.assignment_rounded,
    ),
  ),
  GoRoute(
    path: '/offers',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'offers',
      title: 'Ofertat',
      subtitle: 'Oferta, çmime, materiale, transport dhe status',
      icon: Icons.local_offer_rounded,
    ),
  ),
  GoRoute(
    path: '/orders',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'orders',
      title: 'Punët',
      subtitle: 'Punët, statuset, pagesat dhe anulimet',
      icon: Icons.work_rounded,
    ),
  ),
  GoRoute(
    path: '/reviews',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'reviews',
      title: 'Reviews',
      subtitle: 'Vlerësime reale, moderim dhe histori',
      icon: Icons.star_rounded,
    ),
  ),
  GoRoute(
    path: '/reports',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'reports',
      title: 'Reports',
      subtitle: 'Raportime për përdorues, punë dhe përmbajtje',
      icon: Icons.flag_rounded,
    ),
  ),
  GoRoute(
    path: '/disputes',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'disputes',
      title: 'Disputes',
      subtitle: 'Mosmarrëveshje, shqyrtim dhe vendime admin',
      icon: Icons.gavel_rounded,
    ),
  ),
  GoRoute(
    path: '/finance',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'finance',
      title: 'Financat',
      subtitle: 'Pagesa, refunds, komisione dhe të ardhura',
      icon: Icons.account_balance_wallet_rounded,
    ),
  ),
  GoRoute(
    path: '/subscriptions',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'subscriptions',
      title: 'Abonimet',
      subtitle: 'Planet, statuset dhe të ardhurat mujore',
      icon: Icons.workspace_premium_rounded,
    ),
  ),
  GoRoute(
    path: '/notifications',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'notifications',
      title: 'Njoftimet',
      subtitle: 'Historiku dhe dërgimi i njoftimeve',
      icon: Icons.notifications_active_rounded,
    ),
  ),
  GoRoute(
    path: '/support',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'support',
      title: 'Support',
      subtitle: 'Tickets, prioritete dhe statuset e suportit',
      icon: Icons.support_agent_rounded,
    ),
  ),
  GoRoute(
    path: '/analytics',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'analytics',
      title: 'Analytics',
      subtitle: 'Events, përdorues aktivë, kërkesa dhe punë',
      icon: Icons.query_stats_rounded,
    ),
  ),
  GoRoute(
    path: '/admins',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'admins',
      title: 'Administratorët',
      subtitle: 'Role, akses dhe statuset e stafit admin',
      icon: Icons.admin_panel_settings_rounded,
    ),
  ),
  GoRoute(
    path: '/audit',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'audit',
      title: 'Audit Logs',
      subtitle: 'Historik i veprimeve të administratorëve',
      icon: Icons.history_rounded,
    ),
  ),
  GoRoute(
    path: '/settings',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'settings',
      title: 'Settings',
      subtitle: 'Konfigurimi real i platformës',
      icon: Icons.settings_rounded,
    ),
  ),
];

class EMjeshtriAdminApp extends StatelessWidget {
  const EMjeshtriAdminApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'e-Mjeshtri Admin',
        theme: buildTheme(),
        routerConfig: _router,
      );
}
