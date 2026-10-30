import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'logs_page.dart';

class LogDetailPage extends StatefulWidget {
  final AppState app;
  final WorkLog log;
  const LogDetailPage({super.key,required this.app,required this.log});
  @override State<LogDetailPage> createState()=>_LogDetailPageState();
}
class _LogDetailPageState extends State<LogDetailPage> {
  late WorkLog _log;
  Future<List<LogComment>>? _comments;
  final _text=TextEditingController();
  bool _sending=false;
  int? _replyTo;
  @override void initState(){super.initState();_log=widget.log;_reload();}
  @override void dispose(){_text.dispose();super.dispose();}
  bool get _directManager {
    final me = widget.app.user!;
    if (_log.authorRole.isEmpty) return false;
    return switch (me.role) {
      'TEAM_LEADER' => _log.authorRole == 'EMPLOYEE' && me.teamId != null && me.teamId == _log.teamId,
      'DEPT_MANAGER' => _log.authorRole == 'TEAM_LEADER' && me.departmentId != null && me.departmentId == _log.departmentId,
      'FOUNDER' => _log.authorRole == 'DEPT_MANAGER',
      _ => false,
    };
  }
  void _reload(){
    _comments = widget.app.user!.id == _log.authorId || _directManager
      ? widget.app.repo.comments(_log.id)
      : Future.value(<LogComment>[]);
  }
  Future<void> _send() async {
    if(_sending||_text.text.trim().isEmpty)return;
    setState(()=>_sending=true);
    try{await widget.app.repo.addComment(_log.id,_text.text.trim(),parentId:_replyTo);_text.clear();if(mounted)setState((){_replyTo=null;_reload();});}
    catch(e){if(mounted)toast(context,'$e');}
    finally{if(mounted)setState(()=>_sending=false);}
  }
  @override Widget build(BuildContext context){
    final me=widget.app.user!;
    final own=_log.authorId==me.id;
    final canReply=own;
    final canInitial=_directManager;
    final canEdit=own&&!_log.submitted&&_log.logDate==todayChina&&chinaNow.hour<22;
    return Scaffold(appBar:AppBar(title:const Text('日志详情'),actions:[if(canEdit)IconButton(tooltip:'编辑草稿',onPressed:()async{
      final result=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>LogEditorPage(app:widget.app,draft:_log)));
      if(result==true&&mounted){final data=await widget.app.repo.logs(date:_log.logDate);final newer=data.where((e)=>e.id==_log.id);if(newer.isNotEmpty&&mounted)setState(()=>_log=newer.first);}
    },icon:const Icon(Icons.edit_outlined))]),
    body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(20,8,20,30),children:[
      SoftCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[CircleAvatar(backgroundColor:Palette.sage,child:Text(_log.authorName.isEmpty?'日':_log.authorName.substring(0,1),style:const TextStyle(color:Palette.primary,fontWeight:FontWeight.w800))),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_log.authorName,style:const TextStyle(fontWeight:FontWeight.w900,color:Palette.deep,fontSize:16)),Text(_log.logDate,style:const TextStyle(color:Palette.muted,fontSize:12))])),StatusBadge(status:_log.status)]),
        const Divider(height:30),Text(_log.content,style:const TextStyle(height:1.9,fontSize:15,color:Palette.deep)),
        const SizedBox(height:17),const Text('每日一条 · 提交后不可修改',style:TextStyle(color:Palette.muted,fontSize:11)),
      ])),
      const SizedBox(height:22),const Headline(title:'上级点评与回复',subtitle:'对话仅作者与直属上级可见'),const SizedBox(height:13),
      if (!own && !canInitial) const SoftCard(child: Text('你可以阅读这条日志，但无权查看或参与其直属上级点评对话。', style: TextStyle(color: Palette.muted))),
      if (own || canInitial)
      FutureBuilder<List<LogComment>>(future:_comments,builder:(context,s){
        if(s.connectionState!=ConnectionState.done)return const Padding(padding:EdgeInsets.all(20),child:Center(child:CircularProgressIndicator()));
        if(s.hasError)return SoftCard(child:Column(children:[const Icon(Icons.lock_outline,color:Palette.coral),const SizedBox(height:8),Text('${s.error}',style:const TextStyle(color:Palette.muted))]));
        final data=s.data??[];
        return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          if(data.isEmpty)const SoftCard(child:EmptyPanel(title:'还没有点评',subtitle:'直属上级点评后，作者可继续回复',icon:Icons.forum_outlined)),
          ...data.map((c)=>Padding(padding:const EdgeInsets.only(bottom:10),child:SoftCard(color:c.authorId==_log.authorId?const Color(0xFFEDF7F4):Colors.white,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(c.authorId==_log.authorId?Icons.reply_rounded:Icons.record_voice_over_outlined,color:Palette.primary,size:18),const SizedBox(width:6),Expanded(child:Text(c.authorName,style:const TextStyle(fontWeight:FontWeight.w800,color:Palette.deep))),Text(c.createdAt.length>=10?c.createdAt.substring(0,10):c.createdAt,style:const TextStyle(fontSize:10,color:Palette.muted))]),if(c.parentId!=null)Padding(padding:const EdgeInsets.only(top:6),child:Text('回复点评 #${c.parentId}',style:const TextStyle(fontSize:11,color:Palette.muted))),const SizedBox(height:9),Text(c.content,style:const TextStyle(fontSize:14,height:1.55,color:Palette.deep)),if(canReply && c.authorId!=me.id)Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>setState(()=>_replyTo=c.id),icon:const Icon(Icons.reply,size:16),label:const Text('回复')))])))),
          if(canInitial || (canReply && data.any((c)=>c.authorId!=me.id)))...[
            const SizedBox(height:7),if(_replyTo!=null)Row(children:[Text('正在回复 #$_replyTo',style:const TextStyle(color:Palette.primary,fontSize:12)),TextButton(onPressed:()=>setState(()=>_replyTo=null),child:const Text('取消'))]),
            TextField(controller:_text,maxLines:3,minLines:2,decoration:InputDecoration(hintText:canReply?'回复直属上级的点评':'写下反馈与建议…')),
            const SizedBox(height:10),FilledButton.icon(onPressed:_sending?null:()=>_sendWithValidation(data,canReply),icon:const Icon(Icons.send_rounded,size:18),label:Text(_sending?'正在发送…':'发送点评')),
          ],
        ]);
      }),
    ])));
  }
  void _sendWithValidation(List<LogComment> data,bool reply){
    if(reply && _replyTo==null){toast(context,'请先点击上级点评下方的“回复”');return;}
    if(!reply && _replyTo!=null){toast(context,'直属上级不能回复现有点评');return;}
    _send();
  }
}
