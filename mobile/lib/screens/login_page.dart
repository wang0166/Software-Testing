import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../data/mock_repository.dart';
import '../widgets/ui.dart';

class LoginPage extends StatefulWidget {
  final AppState app;
  const LoginPage({super.key,required this.app});
  @override State<LoginPage> createState()=>_LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final _form=GlobalKey<FormState>();
  final _user=TextEditingController(),_pass=TextEditingController();
  bool _obscure=true,_busy=false;
  @override void dispose(){_user.dispose();_pass.dispose();super.dispose();}
  Future<void> _login() async {
    if(_busy||!_form.currentState!.validate())return;
    setState(()=>_busy=true);
    try {await widget.app.login(_user.text.trim(),_pass.text);}catch(e){if(mounted)toast(context,'$e');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    body:Stack(children:[
      Positioned(top:-110,right:-100,child:Container(width:300,height:330,decoration:const BoxDecoration(color:Color(0xFFDDF5EB),shape:BoxShape.circle))),
      Positioned(top:130,left:-130,child:Container(width:240,height:240,decoration:const BoxDecoration(color:Color(0xFFFBEEDA),shape:BoxShape.circle))),
      SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.symmetric(horizontal:28,vertical:30),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Center(child:Container(width:78,height:78,decoration:BoxDecoration(color:Palette.primary,borderRadius:BorderRadius.circular(26),boxShadow:[BoxShadow(color:Palette.primary.withValues(alpha:.23),blurRadius:25,offset:const Offset(0,12))]),child:const Icon(Icons.auto_stories_rounded,color:Colors.white,size:40))),
        const SizedBox(height:20),const Text('PANDORA  ·  潘多拉',textAlign:TextAlign.center,style:TextStyle(color:Palette.deep,fontWeight:FontWeight.w900,letterSpacing:1.2,fontSize:26)),
        const SizedBox(height:7),const Text('把日常点滴，写成成长轨迹',textAlign:TextAlign.center,style:TextStyle(color:Palette.muted,fontSize:13)),
        const SizedBox(height:32),SoftCard(padding:const EdgeInsets.all(24),child:Form(key:_form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('欢迎回来 👋',style:TextStyle(color:Palette.deep,fontSize:23,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),const Text('使用管理员分配的账号登录',style:TextStyle(color:Palette.muted,fontSize:13)),
          const SizedBox(height:25),const Text('登录账号',style:TextStyle(fontWeight:FontWeight.w700,color:Palette.deep)),const SizedBox(height:8),
          TextFormField(key:const Key('login_username'),controller:_user,autofillHints:const [AutofillHints.username],textInputAction:TextInputAction.next,decoration:const InputDecoration(hintText:'请输入用户名',prefixIcon:Icon(Icons.person_outline_rounded)),validator:(s)=>s==null||s.trim().isEmpty?'请填写账号':null),
          const SizedBox(height:19),const Text('登录密码',style:TextStyle(fontWeight:FontWeight.w700,color:Palette.deep)),const SizedBox(height:8),
          TextFormField(key:const Key('login_password'),controller:_pass,obscureText:_obscure,autofillHints:const [AutofillHints.password],onFieldSubmitted:(_)=>_login(),decoration:InputDecoration(hintText:'请输入密码',prefixIcon:const Icon(Icons.lock_outline_rounded),suffixIcon:IconButton(tooltip:_obscure?'显示密码':'隐藏密码',onPressed:()=>setState(()=>_obscure=!_obscure),icon:Icon(_obscure?Icons.visibility_off_outlined:Icons.visibility_outlined))),validator:(s)=>s==null||s.isEmpty?'请填写密码':null),
          const SizedBox(height:25),FilledButton(key:const Key('login_button'),onPressed:_busy?null:_login,child:_busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Text('登 录',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800))),
          const SizedBox(height:13),const Text('忘记账号或密码？请联系系统管理员',textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Palette.muted)),
        ]))),
        if(pandoraDemo)...[const SizedBox(height:20),SoftCard(color:const Color(0xFFFFF8EB),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(children:[Icon(Icons.science_outlined,color:Color(0xFFA97930),size:18),SizedBox(width:7),Text('演示模式 · 无需连接后端',style:TextStyle(color:Color(0xFF8A6539),fontWeight:FontWeight.w700,fontSize:13))]),
          const SizedBox(height:8),const Text('选择演示身份，体验不同角色权限与完整流程。',style:TextStyle(fontSize:12,color:Palette.muted)),
          const SizedBox(height:12),Wrap(spacing:7,runSpacing:7,children:[for(final u in MockRepository.users)ActionChip(label:Text(u.roleLabel),onPressed:(){_user.text=u.username;_pass.text=MockRepository.demoPassword;setState((){});})]),
          const SizedBox(height:7),const Text('统一演示密码：demo123456（仅 Mock 有效）',style:TextStyle(fontSize:11,color:Palette.muted)),
        ]))],
        const SizedBox(height:23),const Center(child:Text('用心记录 · 轻松协作 · 每天进步一点点',style:TextStyle(fontSize:11,color:Palette.muted))),
      ])))))
    ]),
  );
}
