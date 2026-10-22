import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// 只有创始人、部门负责人、团队负责人拥有派发入口。
/// 派发成功后，每个接收者的进度独立保存，检查只能由派发人处理。
class DispatchPage extends StatefulWidget {
  final AppState app;
  const DispatchPage({super.key,required this.app});
  @override State<DispatchPage> createState()=>_DispatchPageState();
}
class _DispatchPageState extends State<DispatchPage> {
  late Future<List<DispatchedTask>> _items;
  @override void initState(){super.initState();_reload();}
  void _reload(){_items=widget.app.repo.dispatchedTasks();}
  Future<void> _newDispatch() async {
    final title=TextEditingController(),detail=TextEditingController();
    final start=DateTime(chinaNow.year,chinaNow.month,chinaNow.day);
    DateTime from=start,to=start.add(const Duration(days:7));
    String urgency='NOT_URGENT';
    final ids=<int>{};
    try {
      final people=await widget.app.repo.recipients();
      if(!mounted)return;
      final created=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(ctx,rebuild)=>AlertDialog(
        title:const Text('派发新任务'),
        content:SizedBox(width:460,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          TextField(controller:title,maxLength:200,decoration:const InputDecoration(labelText:'任务名称')),
          const SizedBox(height:9),TextField(controller:detail,maxLines:3,decoration:const InputDecoration(labelText:'任务详情')),
          const SizedBox(height:12),Text('开始 ${dayString(from)} / 截止 ${dayString(to)}',style:const TextStyle(color:Palette.deep,fontSize:12)),
          Wrap(spacing:8,children:[OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:from,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null)rebuild((){from=d;if(to.isBefore(from))to=from;});},icon:const Icon(Icons.today_rounded,size:16),label:const Text('开始日期')),OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:to.isBefore(from)?from:to,firstDate:from,lastDate:DateTime(2100));if(d!=null)rebuild(()=>to=d);},icon:const Icon(Icons.event_rounded,size:16),label:const Text('截止日期'))]),
          const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:urgency,items:const [DropdownMenuItem(value:'NOT_URGENT',child:Text('普通任务')),DropdownMenuItem(value:'URGENT',child:Text('紧急任务'))],onChanged:(v)=>rebuild(()=>urgency=v??urgency),decoration:const InputDecoration(labelText:'紧急程度')),
          const SizedBox(height:15),const Text('选择直属下级（可多选）',style:TextStyle(fontWeight:FontWeight.w800)),
          if(people.isEmpty)const Padding(padding:EdgeInsets.all(10),child:Text('暂无可派发的直属下级')),
          for(final p in people)CheckboxListTile(dense:true,contentPadding:EdgeInsets.zero,value:ids.contains(p.id),title:Text(p.name),subtitle:Text(p.roleLabel),onChanged:(v)=>rebuild((){if(v==true){ids.add(p.id);}else{ids.remove(p.id);}})),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('确认派发'))],
      )));
      if(created!=true||!mounted)return;
      if(title.text.trim().isEmpty||detail.text.trim().isEmpty||ids.isEmpty){toast(context,'请填写名称、详情并选择接收人');return;}
      await widget.app.repo.dispatchTask(name:title.text.trim(),details:detail.text.trim(),startDate:dayString(from),deadline:dayString(to),urgency:urgency,assigneeIds:ids.toList());
      if(mounted){toast(context,'任务已派发');setState(_reload);}
    } catch(e) {if(mounted)toast(context,'$e');}
    finally {title.dispose();detail.dispose();}
  }
  Future<void> _detail(DispatchedTask task) async {
    await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>_DispatchDetail(app:widget.app,task:task)));
    if(mounted)setState(_reload);
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('我派发的任务')),
    floatingActionButton:FloatingActionButton.extended(onPressed:_newDispatch,label:const Text('派发新任务'),icon:const Icon(Icons.add_rounded)),
    body:RefreshIndicator(onRefresh:()async{setState(_reload);await _items;},child:ListView(padding:const EdgeInsets.fromLTRB(20,10,20,100),children:[
      const PageHeading(overline:'TEAM COLLABORATION',title:'任务派发',description:'仅向直属下级派发，每名接收人的进度相互独立'),const SizedBox(height:19),
      FutureBuilder<List<DispatchedTask>>(future:_items,builder:(context,s){
        if(s.connectionState!=ConnectionState.done)return const Padding(padding:EdgeInsets.all(25),child:Center(child:CircularProgressIndicator()));
        if(s.hasError)return ErrorPanel(error:s.error!,onRetry:()=>setState(_reload));
        final items=s.data??[];
        if(items.isEmpty)return const EmptyPanel(title:'还没有派发任务',subtitle:'点击右下角，为直属下级安排工作');
        return Column(children:[for(final task in items)Padding(padding:const EdgeInsets.only(bottom:12),child:SoftCard(child:InkWell(onTap:()=>_detail(task),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text(task.name,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16,color:Palette.deep))),if(task.urgency=='URGENT')const Pill(text:'紧急',color:Color(0xFFBE6446),background:Color(0xFFFDEDE7))]),
          const SizedBox(height:9),Text('${task.startDate}  →  ${task.deadline}',style:const TextStyle(color:Palette.muted,fontSize:12)),
          const SizedBox(height:12),Wrap(spacing:8,runSpacing:7,children:[Pill(text:'接收 ${task.assigneeCount} 人'),Pill(text:'完成 ${task.completedCount} 人'),Pill(text:'待检查 ${task.pendingReviewCount} 人',color:const Color(0xFFA67539),background:Palette.pastel)]),
          const SizedBox(height:8),const Align(alignment:Alignment.centerRight,child:Icon(Icons.chevron_right_rounded,color:Palette.muted)),
        ]))))]);
      }),
    ])),
  );
}

class _DispatchDetail extends StatefulWidget {
  final AppState app;final DispatchedTask task;
  const _DispatchDetail({required this.app,required this.task});
  @override State<_DispatchDetail> createState()=>_DispatchDetailState();
}
class _DispatchDetailState extends State<_DispatchDetail> {
  late Future<List<TaskAssignment>> _future;
  @override void initState(){super.initState();_refresh();}
  void _refresh(){_future=widget.app.repo.dispatchedAssignments(widget.task.id);}
  Future<void> _review(TaskAssignment a,String result) async {
    final controller=TextEditingController();
    try {
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(result=='APPROVED'?'检查通过':'退回修改'),content:TextField(controller:controller,maxLines:3,decoration:const InputDecoration(hintText:'填写检查意见（可选）')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('确定'))]));
      if(ok!=true)return;
      await widget.app.repo.reviewAssignment(a.id,result,controller.text.trim());
      if(mounted){toast(context,'检查结果已保存');setState(_refresh);}
    }catch(e){if(mounted)toast(context,'$e');}
    finally{controller.dispose();}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('派发任务详情')),body:ListView(padding:const EdgeInsets.all(20),children:[
    SoftCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.task.name,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),Text(widget.task.details,style:const TextStyle(height:1.6,color:Palette.deep)),const SizedBox(height:12),Text('截止 ${widget.task.deadline}',style:const TextStyle(color:Palette.muted))])),
    const SizedBox(height:20),const Headline(title:'接收人进度',subtitle:'分别检查各成员的完成情况'),const SizedBox(height:12),
    FutureBuilder<List<TaskAssignment>>(future:_future,builder:(context,s){
      if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      if(s.hasError)return ErrorPanel(error:s.error!,onRetry:()=>setState(_refresh));
      final items=s.data??[];
      if(items.isEmpty)return const EmptyPanel(title:'暂无接收人',subtitle:'请稍后重试');
      return Column(children:[for(final a in items)Padding(padding:const EdgeInsets.only(bottom:12),child:SoftCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(a.assigneeName,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:Palette.deep)),const SizedBox(height:8),Wrap(spacing:8,children:[StatusBadge(status:a.status),Pill(text:const {'NONE':'未检查','PENDING':'待检查','APPROVED':'检查通过','RETURNED':'已退回'}[a.reviewStatus]??a.reviewStatus)]),
        if(a.reviewStatus=='PENDING')...[const SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton(onPressed:()=>_review(a,'RETURNED'),child:const Text('退回修改'))),const SizedBox(width:10),Expanded(child:FilledButton(onPressed:()=>_review(a,'APPROVED'),child:const Text('检查通过')))])],
      ])))]);
    }),
  ]));
}
