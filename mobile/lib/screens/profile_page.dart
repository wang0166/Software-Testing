import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'calendar_page.dart';
import 'task_map_page.dart';

class ProfilePage extends StatelessWidget {
  final AppState app;
  const ProfilePage({super.key,required this.app});

  @override Widget build(BuildContext context) {
    final user=app.user!;
    return ListView(padding:const EdgeInsets.fromLTRB(20,17,20,35),children:[
      const PageHeading(overline:'MY WORKSPACE',title:'个人中心',description:'随时了解自己的工作状态与账号信息'),
      const SizedBox(height:21),
      Container(padding:const EdgeInsets.all(23),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF258F82),Color(0xFF72BEA8)]),borderRadius:BorderRadius.circular(24)),child:Row(children:[CircleAvatar(radius:32,backgroundColor:Colors.white.withValues(alpha:.25),child:Text(user.name.isEmpty?'我':user.name.substring(0,1),style:const TextStyle(fontSize:29,fontWeight:FontWeight.w800,color:Colors.white))),const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(user.name,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:23)),const SizedBox(height:6),Text('${user.roleLabel} · ${user.username}',style:const TextStyle(color:Color(0xFFE4F9F1)))]))])),
      const SizedBox(height:22),const Headline(title:'我的工作台',subtitle:'常用功能，便捷直达'),const SizedBox(height:13),
      SoftCard(child:Column(children:[
        _entry(Icons.calendar_month_outlined,'日历视图','月 / 周 / 日工作安排',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CalendarPage(app:app)))),
        const Divider(height:18),
        _entry(Icons.hub_outlined,'任务数据地图','汇总收到和自建的任务',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>TaskMapPage(app:app)))),
        const Divider(height:18),
        _entry(Icons.shield_outlined,'数据与权限','日志范围由服务端强制校验',()=>showAboutDialog(context:context,applicationName:'潘多拉智能掌上日志',children:[Text('当前身份：${user.roleLabel}\n账号：${user.username}\n隐私与权限由后端统一控制，移动端不会越权读取。')])),
      ])),
      const SizedBox(height:22),SoftCard(color:const Color(0xFFFFF8EC),child:Row(children:[const Icon(Icons.lightbulb_outline_rounded,color:Color(0xFFC4893C)),const SizedBox(width:12),Expanded(child:Text(pandoraDemo?'当前是演示模式，数据保存在本机，退出后仍可保留演示记录。':'当前连接团队后端，操作将按真实账号权限处理。',style:const TextStyle(color:Palette.deep,height:1.5,fontSize:12)))])),
      const SizedBox(height:24),OutlinedButton.icon(onPressed:()async{
        final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('退出登录？'),content:const Text('退出后需要重新登录账号。'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('确认退出'))]));
        if(ok!=true)return;
        try{await app.logout();}catch(e){if(context.mounted)toast(context,'退出异常：$e');}
      },icon:const Icon(Icons.logout_rounded),label:const Text('退出当前账号')),
      const SizedBox(height:24),const Center(child:Text('PANDORA · 用心记录每一天',style:TextStyle(fontSize:11,letterSpacing:1,color:Palette.muted))),
    ]);
  }
  Widget _entry(IconData icon,String title,String subtitle,VoidCallback onTap)=>ListTile(onTap:onTap,contentPadding:EdgeInsets.zero,leading:Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:Palette.sage,borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:Palette.primary,size:20)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800,color:Palette.deep)),subtitle:Text(subtitle,style:const TextStyle(fontSize:11,color:Palette.muted)),trailing:const Icon(Icons.chevron_right_rounded,color:Palette.muted));
}
