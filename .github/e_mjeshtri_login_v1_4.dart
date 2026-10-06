import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'auth_repository.dart';
import 'widgets/auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState()=>_LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final formKey=GlobalKey<FormState>();
  final email=TextEditingController();
  final password=TextEditingController();
  bool obscure=true,loading=false;
  String? error;
  String get _role => GoRouterState.of(context).uri.queryParameters['role'] == 'provider' ? 'provider' : 'citizen';

  @override void dispose(){email.dispose();password.dispose();super.dispose();}

  Future<void> _submit() async {
    if(!(formKey.currentState?.validate()??false))return;
    setState(()=>{loading=true,error=null});
    try{
      final auth = ref.read(authRepositoryProvider);
      await auth.signIn(email:email.text,password:password.text);
      final role=_role;
      await Supabase.instance.client.rpc('set_my_app_role',params:{'p_role':role});
      final route = role == 'provider'
          ? await auth.providerLandingRoute()
          : '/permissions/location';
      if(mounted)context.go(route);
    }catch(_){
      if(mounted)setState(()=>error=AppStrings.of(context).t('loginFailed'));
    }finally{if(mounted)setState(()=>loading=false);}
  }

  @override
  Widget build(BuildContext context){
    final s=AppStrings.of(context);
    return AuthScaffold(child:Form(key:formKey,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(s.t('loginTitle'),style:Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height:10),
      Text(s.t('loginBody'),style:Theme.of(context).textTheme.bodyLarge?.copyWith(color:AppColors.muted)),
      const SizedBox(height:30),
      TextFormField(controller:email,keyboardType:TextInputType.emailAddress,textInputAction:TextInputAction.next,autofillHints:const[AutofillHints.email],decoration:InputDecoration(labelText:s.t('email'),prefixIcon:const Icon(Icons.alternate_email_rounded)),validator:(v)=>(v==null||!v.contains('@'))?s.t('invalidEmail'):null),
      const SizedBox(height:14),
      TextFormField(controller:password,obscureText:obscure,textInputAction:TextInputAction.done,onFieldSubmitted:(_)=>_submit(),autofillHints:const[AutofillHints.password],decoration:InputDecoration(labelText:s.t('password'),prefixIcon:const Icon(Icons.lock_outline_rounded),suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility_rounded:Icons.visibility_off_rounded))),validator:(v)=>(v==null||v.length<8)?s.t('passwordMin'):null),
      Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>context.push('/forgot-password'),child:Text(s.t('forgotPassword')))),
      if(error!=null)...[Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppColors.danger.withValues(alpha:.07),borderRadius:BorderRadius.circular(16)),child:Text(error!,style:const TextStyle(color:AppColors.danger))),const SizedBox(height:14)],
      AuthPrimaryButton(label:s.t('signIn'),loading:loading,onPressed:_submit),
      const SizedBox(height:14),
      TextButton(onPressed:()=>context.push('/register?role=$_role'),child:Text(s.t('noAccount'))),
    ])));
  }
}