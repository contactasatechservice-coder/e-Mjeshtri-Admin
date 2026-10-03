import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'auth_repository.dart';
import 'widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {const ForgotPasswordScreen({super.key});@override ConsumerState<ForgotPasswordScreen> createState()=>_ForgotPasswordScreenState();}
class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>{final email=TextEditingController();bool loading=false;String? error;@override void dispose(){email.dispose();super.dispose();}Future<void> send()async{if(!email.text.contains('@')){setState(()=>error=AppStrings.of(context).t('invalidEmail'));return;}setState(()=>loading=true);try{await ref.read(authRepositoryProvider).sendEmailOtp(email.text);if(mounted)context.push('/reset-otp?email=${Uri.encodeComponent(email.text.trim())}');}catch(_){if(mounted)setState(()=>error=AppStrings.of(context).t('errorGeneric'));}finally{if(mounted)setState(()=>loading=false);}}@override Widget build(BuildContext context){final s=AppStrings.of(context);return AuthScaffold(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(s.t('resetPassword'),style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:10),Text(s.t('resetBody'),style:Theme.of(context).textTheme.bodyLarge?.copyWith(color:AppColors.muted)),const SizedBox(height:28),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:InputDecoration(labelText:s.t('email'),prefixIcon:const Icon(Icons.alternate_email_rounded))),if(error!=null)...[const SizedBox(height:14),Text(error!,style:const TextStyle(color:AppColors.danger))],const SizedBox(height:20),AuthPrimaryButton(label:s.t('sendCode'),loading:loading,onPressed:send)]));}}