import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../theme/app_colors.dart';
import '../../features/home/home_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/messages/messages_screen.dart';
import '../../features/market/market_screen.dart';
import '../../features/profile/profile_screen.dart';

class AppShell extends StatefulWidget { const AppShell({super.key}); @override State<AppShell> createState()=>_AppShellState(); }
class _AppShellState extends State<AppShell> {
  int index=0;
  static const screens=[HomeScreen(),OrdersScreen(),MarketScreen(audience:'citizen'),MessagesScreen(),ProfileScreen()];
  @override Widget build(BuildContext context){ final s=AppStrings.of(context); final items=[(Icons.home_rounded,s.t('home')),(Icons.assignment_rounded,s.t('serviceRequests')),(Icons.storefront_rounded,'e-Market'),(Icons.forum_rounded,s.t('messages')),(Icons.person_rounded,s.t('profile'))]; return Scaffold(body:IndexedStack(index:index,children:screens),extendBody:true,bottomNavigationBar:SafeArea(minimum:const EdgeInsets.fromLTRB(14,0,14,10),child:Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:8),decoration:BoxDecoration(color:Theme.of(context).cardColor,borderRadius:BorderRadius.circular(24),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.08),blurRadius:24,offset:const Offset(0,8))]),child:Row(children:List.generate(items.length,(i){final selected=i==index;return Expanded(child:InkWell(borderRadius:BorderRadius.circular(18),onTap:(){if(index!=i)setState(()=>index=i);},child:AnimatedContainer(duration:const Duration(milliseconds:90),padding:const EdgeInsets.symmetric(vertical:10,horizontal:4),decoration:BoxDecoration(color:selected?AppColors.blue.withValues(alpha:.08):Colors.transparent,borderRadius:BorderRadius.circular(18)),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(items[i].$1,color:selected?AppColors.blue:AppColors.muted,size:23),const SizedBox(height:4),Text(items[i].$2,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:10.5,fontWeight:selected?FontWeight.w700:FontWeight.w500,color:selected?AppColors.blue:AppColors.muted))]))));}))))); }
}