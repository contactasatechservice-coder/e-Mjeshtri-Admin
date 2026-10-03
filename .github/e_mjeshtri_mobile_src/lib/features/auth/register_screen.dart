import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'auth_repository.dart';
import 'widgets/auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override ConsumerState<RegisterScreen> createState()=>_RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>{
  final formKey=GlobalKey<FormState>();
  final firstName=TextEditingController(),lastName=TextEditingController(),phone=TextEditingController(),email=TextEditingController(),password=TextEditingController(),confirm=TextEditingController();
  bool terms=false,obscure=true,loading=false;
  String? error;
  @override void dispose(){for(final c in[firstName,lastName,phone,email,password,confirm]){c.dispose();}super.dispose();}
  Future<void> _submit()async{final s=AppStrings.of(context);if(!(formKey.currentState?.validate()??false))return;if(!terms){setState(()=>error=s.t('acceptTerms'));return;}setState(()=>{loading=true,error=null});try{await ref.read(authRepositoryProvider).signUp(firstName:firstName.text,lastName:lastName.text,email:email.text,phone:phone.text,password:password.text,languageCode:Localizations.localeOf(context).languageCode);if(mounted)context.go('/verify-signup?email=${Uri.encodeComponent(email.text.trim())}');}catch(_){if(mounted)setState(()=>error=AppStrings.of(context).t('registrationFailed'));}finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context){final s=AppStrings.of(context);return AuthScaffold(child:Form(key:formKey,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(s.t('createAccount'),style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:26),
    Row(children:[Expanded(child:TextFormField(controller:firstName,decoration:InputDecoration(labelText:s.t('firstName')),validator:(v)=>v==null||v.trim().isEmpty?'*':null)),const SizedBox(width:12),Expanded(child:TextFormField(controller:lastName,decoration:InputDecoration(labelText:s.t('lastName')),validator:(v)=>v==null||v.trim().isEmpty?'*':null))]),const SizedBox(height:14),
    TextFormField(controller:phone,keyboardType:TextInputType.phone,decoration:InputDecoration(labelText:s.t('phone'),prefixIcon:const Icon(Icons.phone_outlined)),validator:(v)=>v==null||v.trim().length<7?'*':null),const SizedBox(height:14),
    TextFormField(controller:email,keyboardType:TextInputType.emailAddress,decoration:InputDecoration(labelText:s.t('email'),prefixIcon:const Icon(Icons.alternate_email_rounded)),validator:(v)=>v==null||!v.contains('@')?'*':null),const SizedBox(height:14),
    TextFormField(controller:password,obscureText:obscure,decoration:InputDecoration(labelText:s.t('password'),prefixIcon:const Icon(Icons.lock_outline_rounded),suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility_rounded:Icons.visibility_off_rounded))),validator:(v)=>v==null||v.length<8?s.t('passwordMin'):null),const SizedBox(height:14),
    TextFormField(controller:confirm,obscureText:true,decoration:InputDecoration(labelText:s.t('repeatPassword'),prefixIcon:const Icon(Icons.lock_reset_rounded)),validator:(v)=>v!=password.text?'!':null),const SizedBox(height:16),
    CheckboxListTile(contentPadding:EdgeInsets.zero,value:terms,onChanged:(v)=>setState(()=>terms=v??false),controlAffinity:ListTileControlAffinity.leading,title:Wrap(crossAxisAlignment:WrapCrossAlignment.center,children:[Text('${s.t('acceptTerms')}  '),TextButton(onPressed:()=>context.push('/terms'),child:Text(s.t('terms')))])),
    if(error!=null)...[Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppColors.danger.withValues(alpha:.07),borderRadius:BorderRadius.circular(16)),child:Text(error!,style:const TextStyle(color:AppColors.danger))),const SizedBox(height:14)],
    AuthPrimaryButton(label:s.t('createAccount'),loading:loading,onPressed:_submit),
  ])));
  }
}