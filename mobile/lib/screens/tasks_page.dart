import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'dispatch_page.dart';
import 'calendar_page.dart';

class TasksPage extends StatefulWidget {
  final AppState app;
  const TasksPage({super.key,required this.app});
  @override State<TasksPage> createState()=>_TasksPageState();
}
class _TasksPageState extends State<TasksPage> {
  bool _personal=false;
  late Future<List<TaskItem>> _future;
  @override void initState(){super.initState();_reload();}
  void _reload(){_future=widget.app.repo.tasks(personal:_personal);}
  // Use a dedicated route for task creation. It owns and disposes its text
  // controllers after the route is removed, avoiding dialog-exit races.
  Future<void> _createTask() async {
    final draft = await Navigator.of(context).push<_PersonalTaskDraft>(
      MaterialPageRoute<_PersonalTaskDraft>(
        builder: (_) => const _NewPersonalTaskPage(),
      ),
    );
    if (!mounted || draft == null) return;
    try {
      await widget.app.repo.createPersonalTask(draft.name, draft.details);
      if (!mounted) return;
      toast(context, '任务创建成功');
      setState(_reload);
    } catch (error) {
      if (mounted) toast(context, '$error');
    }
  }

  Future<void> _advance(TaskItem item) async {
    final options=item.source=='RECEIVED'?
      (item.status=='NOT_STARTED'?['IN_PROGRESS']:item.status=='IN_PROGRESS'?['COMPLETED']:<String>[]):
      ['NOT_STARTED','IN_PROGRESS','COMPLETED'];
    if(options.isEmpty){toast(context,'此任务暂无可执行的进度变更');return;}
    final selected=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(context)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,8,20,28),child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('更新任务进度',style:TextStyle(fontWeight:FontWeight.w800,fontSize:19)),const SizedBox(height:12),for(final status in options)ListTile(title:Text(const {'NOT_STARTED':'待开始','IN_PROGRESS':'进行中','COMPLETED':'已完成'}[status]??status),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.pop(context,status))]))));
    if(selected==null)return;
    try{await widget.app.repo.updateTask(item,selected);if(mounted){toast(context,'任务状态已更新');setState(_reload);}}catch(e){if(mounted)toast(context,'$e');}
  }
  @override Widget build(BuildContext context){
    if(!widget.app.user!.canUseTasks)return const Center(child:EmptyPanel(title:'当前角色仅可查看日志',subtitle:'管理员无权操作个人任务或接收任务',icon:Icons.lock_outline));
    return Scaffold(body:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(20,17,20,12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const PageHeading(overline:'YOUR WORKFLOW',title:'任务清单',description:'有序推进每一项计划，轻松掌握进度'),const SizedBox(height:12), Align(
        alignment:Alignment.centerRight,
        child:TextButton.icon(
          key:const ValueKey('open_gantt_from_tasks'),
          icon:const Icon(Icons.view_timeline_rounded,size:18),
          label:const Text('日历 · 甘特图'),
          onPressed:()=>Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:(_)=>CalendarPage(app:widget.app,initialMode:3),
            ),
          ),
        ),
      ), const SizedBox(height:9), Row(children:[Expanded(child:_tab('收到的任务',false)),const SizedBox(width:10),Expanded(child:_tab('我的自建任务',true))]),if(const ['TEAM_LEADER','DEPT_MANAGER','FOUNDER'].contains(widget.app.user!.role))Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>DispatchPage(app:widget.app))),icon:const Icon(Icons.send_outlined,size:16),label:const Text('管理我派发的任务')))])),
      Expanded(child:FutureBuilder<List<TaskItem>>(future:_future,builder:(context,s){
        if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
        if(s.hasError)return ErrorPanel(error:s.error!,onRetry:()=>setState(_reload));
        final data=s.data??[];
        if(data.isEmpty)return ListView(children:[EmptyPanel(title:_personal?'还没有个人任务':'还没有收到任务',subtitle:_personal?'点右下角加号，创建你的第一条个人计划':'上级派发的任务会显示在这里',icon:Icons.task_alt_rounded)]);
        final complete=data.where((t)=>t.status=='COMPLETED').length;
        return RefreshIndicator(onRefresh:()async{setState(_reload);await _future;},child:ListView(padding:const EdgeInsets.fromLTRB(20,6,20,100),children:[
          SoftCard(color:Palette.sage,child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('本组任务进度',style:TextStyle(fontSize:13,color:Palette.muted)),const SizedBox(height:6),Text('$complete / ${data.length} 项已完成',style:const TextStyle(fontSize:21,color:Palette.deep,fontWeight:FontWeight.w900))])),SizedBox(width:75,height:75,child:ProgressDonut(value:complete/data.length,size:75))])),
          const SizedBox(height:15),...data.map((item)=>Padding(padding:const EdgeInsets.only(bottom:12),child:SoftCard(child:InkWell(onTap:()=>_showDetail(item),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text(item.name,style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w900,fontSize:16))),StatusBadge(status:item.status)]),
            const SizedBox(height:9),Text(item.details,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Palette.muted,height:1.6,fontSize:13)),
            const SizedBox(height:15),Row(children:[Icon(item.source=='PERSONAL'?Icons.person_outline:Icons.people_alt_outlined,color:Palette.primary,size:16),const SizedBox(width:5),Text(item.source=='PERSONAL'?'个人任务':'上级派发',style:const TextStyle(color:Palette.muted,fontSize:11)),if(item.urgency=='URGENT')...[const SizedBox(width:8),const Pill(text:'紧急',color:Color(0xFFC3654A),background:Color(0xFFFCECE6))],const Spacer(),if(item.deadline!=null)Text('截止 ${friendlyDate(item.deadline!)}',style:const TextStyle(color:Palette.muted,fontSize:11)),const SizedBox(width:6),const Icon(Icons.chevron_right,color:Palette.muted)]),
          ]))))),
        ]));
      })),
    ]),floatingActionButton:_personal?FloatingActionButton.extended(onPressed:_createTask,backgroundColor:Palette.primary,foregroundColor:Colors.white,icon:const Icon(Icons.add),label:const Text('新建任务')):null);
  }
  Widget _tab(String label,bool value)=>InkWell(onTap:()=>setState((){_personal=value;_reload();}),child:Container(alignment:Alignment.center,padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(color:_personal==value?Palette.primary:Colors.white,borderRadius:BorderRadius.circular(15)),child:Text(label,style:TextStyle(fontWeight:FontWeight.w800,color:_personal==value?Colors.white:Palette.muted))));
  Future<void> _showDetail(TaskItem item) async {
    await showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,builder:(ctx)=>SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(22,12,22,24+MediaQuery.of(ctx).viewInsets.bottom),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('任务详情',style:TextStyle(color:Palette.muted,fontSize:12)),const SizedBox(height:7),Text(item.name,style:Theme.of(ctx).textTheme.titleLarge),const SizedBox(height:14),Text(item.details,style:const TextStyle(height:1.65,color:Palette.deep)),const SizedBox(height:15),StatusBadge(status:item.status),if(item.deadline!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text('截止日期：${item.deadline}',style:const TextStyle(color:Palette.muted))),const SizedBox(height:12),if(item.source=='RECEIVED')Pill(text:const {'NONE':'未邀约','PENDING':'待检查','APPROVED':'已通过','RETURNED':'已退回'}[item.reviewStatus]??item.reviewStatus),const SizedBox(height:20),if(item.reviewStatus!='PENDING'&&item.reviewStatus!='APPROVED')FilledButton(onPressed:(){Navigator.pop(ctx);_advance(item);},child:const Text('更新进度')),if(item.source=='RECEIVED'&&item.status=='COMPLETED'&&(item.reviewStatus=='NONE'||item.reviewStatus=='RETURNED'))Padding(padding:const EdgeInsets.only(top:9),child:OutlinedButton(onPressed:()async{Navigator.pop(ctx);try{await widget.app.repo.inviteReview(item.id);if(mounted){toast(context,'已邀请上级检查');setState(_reload);}}catch(e){if(mounted)toast(context,'$e');}},child:const Text('邀请上级检查'))),
    ]))));
  }
}

// Personal task entry is a full route so the Android back button and
// AppBar back arrow both work without relying on an AlertDialog overlay.
class _PersonalTaskDraft {
  final String name;
  final String details;
  const _PersonalTaskDraft(this.name, this.details);
}

class _NewPersonalTaskPage extends StatefulWidget {
  const _NewPersonalTaskPage();

  @override
  State<_NewPersonalTaskPage> createState() => _NewPersonalTaskPageState();
}

class _NewPersonalTaskPageState extends State<_NewPersonalTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _details = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _details.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop<_PersonalTaskDraft>(
      _PersonalTaskDraft(_name.text.trim(), _details.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建个人任务')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            const PageHeading(
              overline: 'MY WORKFLOW',
              title: '给今天一个新计划',
              description: '写下任务和具体安排，让每一步都有迹可循',
            ),
            const SizedBox(height: 20),
            SoftCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '任务名称',
                      style: TextStyle(
                        color: Palette.deep,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 9),
                    TextFormField(
                      controller: _name,
                      maxLength: 200,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: '例如：整理本周测试计划',
                        prefixIcon: Icon(Icons.task_alt_rounded),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? '请输入任务名称'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '任务详情',
                      style: TextStyle(
                        color: Palette.deep,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 9),
                    TextFormField(
                      controller: _details,
                      minLines: 4,
                      maxLines: 7,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '写下任务目标、具体步骤或备注…',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '仅创建自己的任务，不会向其他成员派发。',
                style: TextStyle(color: Palette.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('创建任务'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: Palette.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
