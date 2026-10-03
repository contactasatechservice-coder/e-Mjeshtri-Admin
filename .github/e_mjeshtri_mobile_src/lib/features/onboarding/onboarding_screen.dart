import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/storage/local_preferences.dart';
import '../../core/theme/app_colors.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override ConsumerState<OnboardingScreen> createState()=>_OnboardingScreenState();
}
class _OnboardingScreenState extends ConsumerState<OnboardingScreen>{
  final controller=PageController(); int index=0;
  Future<void> finish()async{await LocalPreferences.completeOnboarding();if(mounted)context.go('/auth');}
  @override Widget build(BuildContext context){final s=AppStrings.of(context);final last=index==2;final pages=[(Icons.search_rounded,s.t('onboard1Title'),s.t('onboard1Body')),(Icons.request_quote_rounded,s.t('onboard2Title'),s.t('onboard2Body')),(Icons.verified_user_rounded,s.t('onboard3Title'),s.t('onboard3Body'))];return Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,10,20,24),child:Column(children:[Row(children:[Image.asset('assets/branding/e_mjeshtri_logo.png',height:52),const Spacer(),PopupMenuButton<String>(onSelected:(code)async{final l=Locale(code);ref.read(localeProvider.notifier).state=l;await LocalPreferences.saveLocale(l);},itemBuilder:(_)=>const[PopupMenuItem(value:'sq',child:Text('Shqip')),PopupMenuItem(value:'en',child:Text('English')),PopupMenuItem(value:'fr',child:Text('Français')),PopupMenuItem(value:'de',child:Text('Deutsch')),PopupMenuItem(value:'it',child:Text('Italiano'))],icon:const Icon(Icons.language_rounded)),if(!last)TextButton(onPressed:finish,child:Text(s.t('skip')))]),Expanded(child:PageView.builder(controller:controller,itemCount:pages.length,onPageChanged:(v)=>setState(()=>index=v),itemBuilder:(_,i){final p=pages[i];return Column(mainAxisAlignment:MainAxisAlignment.center,children:[Container(width:164,height:164,decoration:BoxDecoration(color:AppColors.blue.withValues(alpha:.07),borderRadius:BorderRadius.circular(48)),child:Icon(p.$1,size:76,color:AppColors.blue)),const SizedBox(height:42),Text(p.$2,textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:14),Text(p.$3,textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodyLarge?.copyWith(color:AppColors.muted))]);})),Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(pages.length,(i)=>AnimatedContainer(duration:const Duration(milliseconds:180),margin:const EdgeInsets.symmetric(horizontal:4),width:i==index?24:8,height:8,decoration:BoxDecoration(color:i==index?AppColors.blue:AppColors.divider,borderRadius:BorderRadius.circular(99))))),const SizedBox(height:24),SizedBox(width:double.infinity,height:56,child:FilledButton(onPressed:(){if(last){finish();}else{controller.nextPage(duration:const Duration(milliseconds:260),curve:Curves.easeOutCubic);}},child:Text(last?s.t('start'):s.t('next'))))]))));}
}