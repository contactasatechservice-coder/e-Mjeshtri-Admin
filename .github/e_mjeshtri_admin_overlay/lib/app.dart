import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'data/admin_repository.dart';
import 'screens/admin_module_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/list_screens.dart';
import 'screens/login_screen.dart';
import 'screens/market_screen.dart';
import 'screens/market_backoffice_screen.dart';
import 'screens/market_seller_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/admin_shell.dart';

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final path = state.matchedLocation;
    final sellerPath = path == '/seller' || path.startsWith('/seller/');
    final sellerLogin = path == '/seller/login';

    if (sellerPath) {
      if (!loggedIn) return sellerLogin ? null : '/seller/login';
      if (sellerLogin) return '/seller';
      return null;
    }

    final onLogin = path == '/login';
    if (!loggedIn) return onLogin ? null : '/login';

    final admin = await AdminRepository.instance.currentAdmin();
    final isAdmin = admin != null && admin['is_active'] == true;
    if (!isAdmin) {
      if (!onLogin) return '/login';
      return null;
    }

    if (onLogin) return '/dashboard';

    final role = admin['role']?.toString();
    if (!_canAccessAdminPath(role, path)) {
      return '/dashboard';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
    GoRoute(
      path: '/seller/login',
      builder: (c, s) => const MarketSellerLoginScreen(),
    ),
    GoRoute(
      path: '/seller',
      builder: (c, s) => const MarketSellerGateScreen(),
    ),
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

bool _canAccessAdminPath(String? role, String path) {
  if (role == 'super_admin' || role == 'admin') return true;

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

  if (role == 'support') return supportPaths.contains(path);
  if (role == 'finance') return financePaths.contains(path);
  return path == '/dashboard';
}
final _moduleRoutes = <RouteBase>[
  GoRoute(
    path: '/market',
    builder: (c, s) => const MarketAdminScreen(),
  ),
  GoRoute(
    path: '/market/backoffice',
    builder: (c, s) => const MarketBackofficeScreen(),
  ),
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
      title: 'Vlerësimet',
      subtitle: 'Vlerësime reale, moderim dhe histori',
      icon: Icons.star_rounded,
    ),
  ),
  GoRoute(
    path: '/reports',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'reports',
      title: 'Raportimet',
      subtitle: 'Raportime për përdorues, punë dhe përmbajtje',
      icon: Icons.flag_rounded,
    ),
  ),
  GoRoute(
    path: '/disputes',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'disputes',
      title: 'Mosmarrëveshjet',
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
      subtitle: 'Kërkesa suporti, prioritete, biseda dhe statuse',
      icon: Icons.support_agent_rounded,
    ),
  ),
  GoRoute(
    path: '/analytics',
    builder: (c, s) => const AdminModuleScreen(
      moduleKey: 'analytics',
      title: 'Analitika',
      subtitle: 'Aktivitet, përdorues aktivë, kërkesa dhe punë',
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
      title: 'Regjistri i Auditit',
      subtitle: 'Historik i veprimeve të administratorëve',
      icon: Icons.history_rounded,
    ),
  ),
  GoRoute(
    path: '/settings',
    builder: (c, s) => const SettingsScreen(),
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
