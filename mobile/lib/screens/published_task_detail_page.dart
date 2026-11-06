import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/business.dart';

/// Read-only dispatch definition and reviewer actions for the issuer.
/// This page never directly changes task metadata; editing/deleting uses
/// the separate administrator approval request workflow.
class PublishedTaskDetailPage extends StatefulWidget {
  final AppState app;
  final IssuedTask issued;
  const PublishedTaskDetailPage({super.key,required this.app,required this.issued});
  @override
  State<PublishedTaskDetailPage> createState()=>_PublishedTaskDetailPageState();
}

class _PublishedTaskDetailPageState extends State<PublishedTaskDetailPage> {
  late Future<List<TaskAssignment>> future;
  bool busy=false;
  @override
  void initState(){super.initState();_load();}
  void _load(){
    future=widget.issued.isRequest?Future.value([]):widget.app.repo.dispatchedAssignments(widget.issued.id);
  }
  Future<void> _refresh() async {
    setState(_load);
    try {await future;}catch(_){}
  }
  String _status(String raw)=>const {
    'NOT_STARTED':'待开始','IN_PROGRESS':'进行中','BLOCKED':'受阻',
    'COMPLETED':'已完成','NONE':'未申请','PENDING':'待完成检查',
    'APPROVED':'检查通过','RETURNED':'已退回',
  }[raw]??raw;

  Future<void> _review(TaskAssignment assignment,String decision) async {
    final note=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(decision=='APPROVED'?'通过任务完成检查？':'退回任务完成检查？'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('${assignment.assigneeName} · ${_status(assignment.status)}',
          style:const TextStyle(color:Palette.muted)),
        const SizedBox(height:12),
        TextField(controller:note,maxLines:3,maxLength:500,
          decoration:InputDecoration(labelText:decision=='RETURNED'?'退回原因（必填）':'检查意见（可选）')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('确认')),
      ],
    ));
    final comment=note.text.trim();note.dispose();
    if(ok!=true || !mounted) { return; }
    if(decision=='RETURNED' && comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('请填写退回原因')));
      return;
    }
    setState(()=>busy=true);
    try {
      await widget.app.repo.reviewAssignment(assignment.id,decision,comment);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(decision=='APPROVED'?'完成检查已通过':'已退回执行人继续处理')));
      }
    } catch(e) {
      if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('操作未成功：$e'))); }
    } finally { if(mounted) { setState(()=>busy=false); } }
  }

  @override
  Widget build(BuildContext context){
    final task=widget.issued;
    return Scaffold(
      appBar:AppBar(title:const Text('我发布的任务')),
      body:RefreshIndicator(onRefresh:_refresh,child:ListView(
        padding:const EdgeInsets.fromLTRB(16,10,16,30),children:[
          Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(
            color:Palette.deep,borderRadius:BorderRadius.circular(12)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('ISSUED TASK / 发布记录',style:TextStyle(color:Color(0xFFB8CAD5),fontSize:11,letterSpacing:1)),
              const SizedBox(height:8),
              Text(task.name,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
              const SizedBox(height:10),
              Text(task.stateLabel,style:const TextStyle(color:Color(0xFFAFE8E2),fontWeight:FontWeight.w700)),
            ])),
          const SizedBox(height:12),
          BusinessPanel(title:'派发内容',child:Padding(
            padding:const EdgeInsets.symmetric(vertical:12),child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(task.details.isEmpty?'暂无说明':task.details),
                const SizedBox(height:10),
                Text('类型：${taskTypeLabel(task.taskType)} · ${task.urgency=='URGENT'?'紧急':'普通'}',
                  style:const TextStyle(color:Palette.muted,fontSize:12)),
                Text('开始：${task.startDate.replaceFirst('T',' ')}',style:const TextStyle(color:Palette.muted,fontSize:12)),
                Text('截止：${task.deadline.replaceFirst('T',' ')}',style:const TextStyle(color:Palette.muted,fontSize:12)),
                Text('接收人数：${task.assigneeCount}',style:const TextStyle(color:Palette.muted,fontSize:12)),
                if(task.changePending) const Padding(padding:EdgeInsets.only(top:10),
                  child:Text('修改或删除申请正在等待管理员审核，已生效任务暂不变更。',
                    style:TextStyle(color:Palette.coral,fontSize:12))),
                if(task.isRequest) const Padding(padding:EdgeInsets.only(top:10),
                  child:Text('派发申请尚未通过审核，未生成接收人执行任务。',
                    style:TextStyle(color:Palette.muted,fontSize:12))),
              ]))),
          if(!task.isRequest) ...[
            const SizedBox(height:12),
            BusinessPanel(title:'接收人执行情况',child:Padding(
              padding:const EdgeInsets.symmetric(vertical:10),
              child:FutureBuilder<List<TaskAssignment>>(
                future:future,builder:(ctx,snap){
                  if(snap.connectionState!=ConnectionState.done) { return const Center(child:CircularProgressIndicator()); }
                  if (snap.hasError) {
                    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      const Text('当前后端未返回接收人执行列表或无权限。',
                        style:TextStyle(color:Palette.muted,fontSize:12)),
                      Text('${snap.error}',style:const TextStyle(color:Palette.coral,fontSize:11)),
                    ]);
                  }
                  final items=snap.data??[];
                  if(items.isEmpty) { return const Text('暂无可查看的执行记录'); }
                  final done=items.where((e)=>e.status=='COMPLETED').length;
                  return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('已完成 $done / ${items.length} · 待检查 ${items.where((e)=>e.reviewStatus=='PENDING').length}',
                      style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w800)),
                    const SizedBox(height:9),
                    for(final item in items) ...[
                      const Divider(color:Palette.divider,height:20),
                      Row(children:[
                        Expanded(child:Text(item.assigneeName,
                          style:const TextStyle(fontWeight:FontWeight.w800,color:Palette.deep))),
                        Text(item.status == 'COMPLETED' ? '已完成' : '进行中',
                          style:const TextStyle(color:Palette.primary,fontSize:12)),
                      ]),
                      if(item.reviewStatus=='PENDING') Padding(
                        padding:const EdgeInsets.only(top:6),child:Wrap(spacing:7,children:[
                          OutlinedButton(onPressed:busy?null:()=>_review(item,'RETURNED'),child:const Text('退回检查')),
                          FilledButton(onPressed:busy?null:()=>_review(item,'APPROVED'),child:const Text('通过检查')),
                        ])),
                      if(item.reviewStatus=='APPROVED' || item.reviewStatus=='RETURNED')
                        Text('完成检查：${_status(item.reviewStatus)}',
                          style:const TextStyle(color:Palette.muted,fontSize:11)),
                    ],
                  ]);
                },
              ),
            )),
          ],
          const SizedBox(height:14),
          const Text('修改任务内容、接收人员或删除任务，请返回“我发布的任务”发起管理员审核。执行进度由接收人填报。',
            style:TextStyle(color:Palette.muted,fontSize:11,height:1.6)),
        ],
      )),
    );
  }
}
