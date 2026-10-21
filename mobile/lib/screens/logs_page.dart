import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'log_detail_page.dart';

class LogsPage extends StatefulWidget {
  final AppState app;
  const LogsPage({super.key,required this.app});
  @override State<LogsPage> createState()=>_LogsPageState();
}
class _LogsPageState extends State<LogsPage> {
  late Future<List<WorkLog>> _future;
  String _filter='全部';
  final _search=TextEditingController();
  @override void initState(){super.initState();_refresh();}
  @override void dispose(){_search.dispose();super.dispose();}
  void _refresh(){_future=widget.app.repo.logs();}
  Future<void> _edit({WorkLog? draft}) async {
    final ok=await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>LogEditorPage(app:widget.app,draft:draft)));
    if(ok==true&&mounted)setState(_refresh);
  }
  @override Widget build(BuildContext context){
    final me=widget.app.user!;
    return Scaffold(body:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(20,17,20,10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const PageHeading(overline:'WORK JOURNAL',title:'工作日志',description:'记录每日进展，回顾每一步成长'),
        const SizedBox(height:17),TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),hintText:'搜索日志内容或同事姓名')),
        const SizedBox(height:12),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[for(final tab in ['全部','我的','草稿','已提交'])Padding(padding:const EdgeInsets.only(right:9),child:ChoiceChip(label:Text(tab),selected:_filter==tab,onSelected:(_)=>setState(()=>_filter=tab),selectedColor:Palette.sage,showCheckmark:false))])),
      ])),
      Expanded(child:FutureBuilder<List<WorkLog>>(future:_future,builder:(context,s){
        if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
        if(s.hasError)return ErrorPanel(error:s.error!,onRetry:()=>setState(_refresh));
        final data=(s.data??[]).where((e){
          if(_filter=='我的'&&e.authorId!=me.id)return false;
          if(_filter=='草稿'&&e.status!='DRAFT')return false;
          if(_filter=='已提交'&&e.status!='SUBMITTED')return false;
          final q=_search.text.trim().toLowerCase();
          return q.isEmpty||e.content.toLowerCase().contains(q)||e.authorName.toLowerCase().contains(q);
        }).toList();
        if(data.isEmpty)return ListView(children:const [EmptyPanel(title:'暂无匹配日志',subtitle:'调整筛选条件，或开始记录今天的工作',icon:Icons.auto_stories_outlined)]);
        return RefreshIndicator(onRefresh:()async{setState(_refresh);await _future;},child:ListView.separated(padding:const EdgeInsets.fromLTRB(20,8,20,110),itemCount:data.length,separatorBuilder:(_,i)=>const SizedBox(height:12),itemBuilder:(context,i){
          final log=data[i];
          return SoftCard(child:InkWell(onTap:()async{await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LogDetailPage(app:widget.app,log:log)));if(mounted)setState(_refresh);},child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[CircleAvatar(radius:19,backgroundColor:Palette.sage,child:Text(log.authorName.isEmpty?'日':log.authorName.substring(0,1),style:const TextStyle(color:Palette.primary,fontWeight:FontWeight.w800))),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(log.authorName,style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w800)),Text(log.logDate,style:const TextStyle(color:Palette.muted,fontSize:11))])),StatusBadge(status:log.status)]),
            const SizedBox(height:13),Text(log.content,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Palette.deep,fontSize:14,height:1.7)),
            const SizedBox(height:15),Row(children:[const Icon(Icons.chat_bubble_outline_rounded,size:16,color:Palette.muted),const SizedBox(width:5),const Text('查看点评',style:TextStyle(color:Palette.muted,fontSize:12)),const Spacer(),if(log.isImportant)const Pill(text:'重点日志',color:Color(0xFFB77A3B),background:Palette.pastel),const SizedBox(width:5),const Icon(Icons.chevron_right_rounded,color:Palette.muted,size:18)]),
          ])));
        }));
      })),
    ]),floatingActionButton:me.canWriteLog?FloatingActionButton.extended(backgroundColor:Palette.primary,foregroundColor:Colors.white,onPressed:()async{
      try {
        final items=await widget.app.repo.logs(date:todayChina);
        if(!context.mounted)return;
        final own=items.where((e)=>e.authorId==me.id).toList();
        if(own.isNotEmpty && own.first.submitted){toast(context,'今天已提交日志，不能再次创建');return;}
        await _edit(draft:own.isEmpty?null:own.first);
      }catch(e){if(context.mounted)toast(context,'$e');}
    },icon:const Icon(Icons.edit_note),label:const Text('写今日志')):null);
  }
}

class LogEditorPage extends StatefulWidget {
  final AppState app;
  final WorkLog? draft;
  const LogEditorPage({super.key,required this.app,this.draft});
  @override State<LogEditorPage> createState()=>_LogEditorPageState();
}
class _LogEditorPageState extends State<LogEditorPage> {
  late final TextEditingController _controller;
  bool _saving=false;
  @override void initState(){super.initState();_controller=TextEditingController(text:widget.draft?.content??'');}
  @override void dispose(){_controller.dispose();super.dispose();}
  Future<void> _save({required bool submit}) async {
    if(_saving)return;
    if(_controller.text.trim().isEmpty){toast(context,'先写下今天完成的工作吧');return;}
    setState(()=>_saving=true);
    try {
      final saved=await widget.app.repo.saveLog(_controller.text.trim(),id:widget.draft?.id);
      if(submit) await widget.app.repo.submitLog(saved.id);
      if(!mounted)return;
      toast(context,submit?'今日工作日志已提交':'草稿保存成功');
      Navigator.pop(context,true);
    }catch(e){if(mounted)toast(context,'$e');}
    finally {if(mounted)setState(()=>_saving=false);}
  }
  @override Widget build(BuildContext context){final len=_controller.text.trim().length;return Scaffold(
    appBar:AppBar(title:Text(widget.draft==null?'写今日志':'编辑今日草稿')),
    body:SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:Palette.sage,borderRadius:BorderRadius.circular(20)),child:Row(children:[const Icon(Icons.today_rounded,color:Palette.primary),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('今天 · ${friendlyDate(todayChina)}',style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w800)),const SizedBox(height:3),const Text('每日一条 · 22:00 截止 · 提交后不可修改',style:TextStyle(color:Palette.muted,fontSize:11))]))])),
      const SizedBox(height:20),const Text('今天有哪些新进展？',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:Palette.deep)),const SizedBox(height:10),
      Expanded(child:TextField(controller:_controller,onChanged:(_)=>setState((){}),maxLines:null,expands:true,textAlignVertical:TextAlignVertical.top,keyboardType:TextInputType.multiline,decoration:const InputDecoration(hintText:'例如：\n• 今天完成了哪些任务\n• 遇到了哪些问题与解决方案\n• 明天计划推进什么\n\n写下真实的工作记录就好。'))),
      const SizedBox(height:8),Text('$len 字 · 内容不能为空',textAlign:TextAlign.right,style:const TextStyle(color:Palette.muted,fontSize:11)),
      const SizedBox(height:13),Row(children:[Expanded(child:OutlinedButton(onPressed:_saving?null:()=>_save(submit:false),style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(50),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),child:const Text('保存草稿'))),const SizedBox(width:10),Expanded(child:FilledButton(onPressed:_saving?null:()=>_confirmSubmit(),child:_saving?const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Text('正式提交')))]),
    ]))));
  }
  Future<void> _confirmSubmit() async {
    final confirm=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('确认提交日志？'),content:const Text('正式提交后内容不可修改，确定要提交吗？'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('再检查一下')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('确定提交'))]));
    if(confirm==true)await _save(submit:true);
  }
}
