import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import 'auth_repository.dart';
import 'widgets/auth_scaffold.dart';

class NewPasswordScreen extends ConsumerStatefulWidget {const NewPasswordScreen({super.key});@override ConsumerState<NewPasswordScreen> createState()=>_NewPasswordScreenState();}
class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen>{final pass=TextEditingController(),confirm=TextEditingController();bool loading=false;@override void dispose(){pass.dispose();confirm.dispose();super.dispose();}Future<void> save()async{if(pass.text.length<8||pass.text!=confirm.text)return;setState(()=>loading=true);try{await ref.read(authRepositoryProvider).updatePassword(pass.text);if(mounted)context.go('/home');}finally{if(mounted)setState(()=>loading=false);}}@override Widget build(BuildContext context){final s=AppStrings.of(context);return AuthScaffold(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(s.t('newPassword'),style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:24),TextField(controller:pass,obscureText:true,decoration:InputDecoration(labelText:s.t('newPassword'))),const SizedBox(height:14),TextField(controller:confirm,obscureText:true,decoration:InputDecoration(labelText:s.t('repeatPassword'))),const SizedBox(height:20),AuthPrimaryButton(label:s.t('saveNewPassword'),loading:loading,onPressed:save)]));}}