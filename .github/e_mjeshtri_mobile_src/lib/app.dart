import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/localization/app_strings.dart';
import 'core/localization/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/app_shell.dart';
import 'features/auth/auth_welcome_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/new_password_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/reset_otp_screen.dart';
import 'features/auth/signup_verification_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/permissions/location_permission_screen.dart';
import 'features/permissions/manual_address_screen.dart';
import 'features/permissions/notification_permission_screen.dart';
import 'features/providers/provider_screens.dart';
import 'features/requests/request_flow.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screens.dart';
import 'features/subscriptions/subscription_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path:'/',builder:(_,__)=>const SplashScreen()),
    GoRoute(path:'/onboarding',builder:(_,__)=>const OnboardingScreen()),
    GoRoute(path:'/auth',builder:(_,__)=>const AuthWelcomeScreen()),
    GoRoute(path:'/login',builder:(_,__)=>const LoginScreen()),
    GoRoute(path:'/register',builder:(_,__)=>const RegisterScreen()),
    GoRoute(path:'/forgot-password',builder:(_,__)=>const ForgotPasswordScreen()),
    GoRoute(path:'/verify-signup',builder:(context,state)=>SignupVerificationScreen(email:state.uri.queryParameters['email']??'')),
    GoRoute(path:'/reset-otp',builder:(context,state)=>ResetOtpScreen(email:state.uri.queryParameters['email']??'')),
    GoRoute(path:'/new-password',builder:(_,__)=>const NewPasswordScreen()),
    GoRoute(path:'/permissions/location',builder:(_,__)=>const LocationPermissionScreen()),
    GoRoute(path:'/manual-address',builder:(_,__)=>const ManualAddressScreen()),
    GoRoute(path:'/permissions/notifications',builder:(_,__)=>const NotificationPermissionScreen()),
    GoRoute(path:'/search',builder:(_,__)=>const SearchScreen()),
    GoRoute(path:'/notifications',builder:(_,__)=>const NotificationsScreen()),
    GoRoute(
      path:'/categories',
      builder:(_,state)=>AllCategoriesScreen(
        requestMode: state.uri.queryParameters['request'] == '1',
      ),
    ),
    GoRoute(path:'/categories/:id',builder:(_,state)=>CategoryDetailScreen(categoryId:state.pathParameters['id']!)),
    GoRoute(path:'/request/new',builder:(_,state)=>CreateRequestScreen(categoryId:state.uri.queryParameters['categoryId']??'')),
    GoRoute(path:'/request/:id/summary',builder:(_,state)=>RequestSummaryScreen(requestId:state.pathParameters['id']!)),
    GoRoute(path:'/request/:id/searching',builder:(_,state)=>RequestSearchingScreen(requestId:state.pathParameters['id']!)),
    GoRoute(path:'/request/:id/offers',builder:(_,state)=>OffersScreen(requestId:state.pathParameters['id']!)),
    GoRoute(path:'/offers/:id',builder:(_,state)=>OfferDetailScreen(offerId:state.pathParameters['id']!)),
    GoRoute(path:'/providers/:id',builder:(_,state)=>ProviderProfileScreen(providerId:state.pathParameters['id']!)),
    GoRoute(path:'/orders/:id',builder:(_,state)=>OrderDetailScreen(orderId:state.pathParameters['id']!)),
    GoRoute(path:'/orders/:id/reschedule',builder:(_,state)=>RescheduleScreen(orderId:state.pathParameters['id']!)),
    GoRoute(path:'/orders/:id/tracking',builder:(_,state)=>LiveTrackingScreen(orderId:state.pathParameters['id']!)),
    GoRoute(path:'/orders/:id/payment',builder:(_,state)=>PaymentScreen(orderId:state.pathParameters['id']!)),
    GoRoute(path:'/orders/:id/review',builder:(_,state)=>ReviewScreen(orderId:state.pathParameters['id']!,providerId:state.uri.queryParameters['providerId']??'')),
    GoRoute(path:'/orders/:id/warranty',builder:(_,state)=>WarrantyScreen(orderId:state.pathParameters['id']!)),
    GoRoute(path:'/chat/:id',builder:(_,state)=>ChatScreen(conversationId:state.pathParameters['id']!)),
    GoRoute(path:'/profile/edit',builder:(_,__)=>const EditProfileScreen()),
    GoRoute(path:'/profile/addresses',builder:(_,__)=>const AddressesScreen()),
    GoRoute(
      path: '/profile/addresses/edit',
      builder: (_, state) => AddressEditScreen(
        initial: state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : null,
      ),
    ),
    GoRoute(path:'/profile/language',builder:(_,__)=>const LanguageScreen()),
    GoRoute(path:'/profile/appearance',builder:(_,__)=>const AppearanceScreen()),
    GoRoute(path:'/profile/notifications',builder:(_,__)=>const NotificationSettingsScreen()),
    GoRoute(path:'/profile/subscription',builder:(_,__)=>const SubscriptionScreen()),
    GoRoute(path:'/profile/privacy',builder:(_,__)=>const PrivacySecurityScreen()),
    GoRoute(path:'/profile/blocked',builder:(_,__)=>const BlockedProvidersScreen()),
    GoRoute(path:'/profile/delete',builder:(_,__)=>const DeleteAccountScreen()),
    GoRoute(path:'/help',builder:(_,__)=>const HelpCenterScreen()),
    GoRoute(path:'/support',builder:(_,__)=>const SupportTicketsScreen()),
    GoRoute(path:'/support/new',builder:(_,state)=>SupportTicketCreateScreen(orderId:state.uri.queryParameters['orderId'])),
    GoRoute(path:'/support/:id',builder:(_,state)=>SupportTicketDetailScreen(ticketId:state.pathParameters['id']!,subject:state.uri.queryParameters['subject'])),
    GoRoute(path:'/report/new',builder:(_,state)=>ReportCreateScreen(providerId:state.uri.queryParameters['providerId'],orderId:state.uri.queryParameters['orderId'],conversationId:state.uri.queryParameters['conversationId'])),
    GoRoute(path:'/terms',builder:(_,__)=>const TermsPrivacyScreen()),
    GoRoute(path:'/about',builder:(_,__)=>const AboutScreen()),
    GoRoute(path:'/home',builder:(_,__)=>const AppShell()),
  ],
);

class EMjeshtriApp extends ConsumerWidget {
  const EMjeshtriApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale=ref.watch(localeProvider);
    final themeMode=ref.watch(themeModeProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner:false,
      title:'e-Mjeshtri',
      theme:AppTheme.light(),
      darkTheme:AppTheme.dark(),
      themeMode:themeMode,
      locale:locale,
      supportedLocales:AppStrings.supported,
      localizationsDelegates:const [AppStringsDelegate(),GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
      routerConfig:_router,
    );
  }
}