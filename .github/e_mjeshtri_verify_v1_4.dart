import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/auth_scaffold.dart';

class SignupVerificationScreen extends StatelessWidget {const SignupVerificationScreen({super.key,required this.email});final String email;@override Widget build(BuildContext context){final s=AppStrings.of(context);final role=GoRouterState.of(context).uri.queryParameters['role']=='provider'?'provider':'citizen';return AuthScaffold(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Icon(Icons.mark_email_read_rounded,size:72,color:AppColors.blue),const SizedBox(height:24),Text(s.t('checkEmail'),textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:12),Text(email,textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodyLarge?.copyWith(color:AppColors.muted)),const SizedBox(height:30),AuthPrimaryButton(label:s.t('backToLogin'),onPressed:()=>context.go('/login?role=$role'))]));}}