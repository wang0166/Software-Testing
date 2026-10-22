import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import '../widgets/redesign.dart';
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
  @override Widget build(BuildContext context) {
    if (!widget.app.user!.canUseTasks) return const Center(child: EmptyPanel(title: '当前角色仅可查看日志', subtitle: '管理员无权操作个人任务或接收任务', icon: Icons.lock_outline));
    return Scaffold(
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(22, 19, 22, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CanvasHeader(eyebrow: 'PANDORA  /  PLANNER', title: '我的任务', subtitle: '事情有轻重，进展有节奏', icon: Icons.task_alt_rounded),
          Row(children: [
            Expanded(child: _tab('收到的任务', false)), const SizedBox(width: 9), Expanded(child: _tab('我的自建任务', true)),
          ]),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: TextButton.icon(
              key: const ValueKey('open_gantt_from_tasks'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CalendarPage(app: widget.app, initialMode: 3))),
              icon: const Icon(Icons.calendar_month_rounded, size: 17), label: const Text('日历甘特图'),
            )),
            if (const ['TEAM_LEADER', 'DEPT_MANAGER', 'FOUNDER'].contains(widget.app.user!.role))
              Expanded(child: TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DispatchPage(app: widget.app))), icon: const Icon(Icons.send_rounded, size: 17), label: const Text('管理派发任务'))),
          ]),
        ])),
        Expanded(child: FutureBuilder<List<TaskItem>>(future: _future, builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorPanel(error: snap.error!, onRetry: () => setState(_reload));
          final data = snap.data ?? [];
          if (data.isEmpty) return ListView(children: [EmptyPanel(title: _personal ? '创建第一个计划' : '暂无收到的任务', subtitle: _personal ? '点击新建任务，把计划安排起来' : '上级派发的任务会显示在这里', icon: Icons.task_alt_rounded)]);
          final complete = data.where((task) => task.status == 'COMPLETED').length;
          return RefreshIndicator(onRefresh: () async { setState(_reload); await _future; }, child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 3, 22, 115),
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF184C50), Color(0xFF218B81)]), borderRadius: BorderRadius.circular(26)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('YOUR PROGRESS', style: TextStyle(color: Palette.gold, letterSpacing: 1.8, fontWeight: FontWeight.w900, fontSize: 10)),
                const SizedBox(height: 11),
                Row(children: [Expanded(child: Text('已完成 $complete / ${data.length} 项', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900))),
                  Text('${(complete / data.length * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 23))]),
                const SizedBox(height: 14),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: complete / data.length, minHeight: 8, backgroundColor: Colors.white.withValues(alpha: .23), color: Palette.gold)),
                const SizedBox(height: 9), const Text('持续推进，一件件完成', style: TextStyle(color: Color(0xFFC3E3DE), fontSize: 11)),
              ])),
              const SizedBox(height: 21),
              TinyLabel(title: _personal ? '我的自建计划' : '待办事项', action: '共 ${data.length} 项'),
              const SizedBox(height: 10),
              for (var i = 0; i < data.length; i++) Padding(padding: const EdgeInsets.only(bottom: 11), child: _taskTile(data[i], i)),
            ],
          ));
        })),
      ]),
      floatingActionButton: _personal ? FloatingActionButton.extended(
        onPressed: _createTask, backgroundColor: Palette.deep, foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded), label: const Text('新建任务', style: TextStyle(fontWeight: FontWeight.w900)),
      ) : null,
    );
  }
  Widget _taskTile(TaskItem task, int i) => StoryCard(padding: EdgeInsets.zero, child: Material(color: Colors.transparent, child: InkWell(
    onTap: () => _showDetail(task), borderRadius: BorderRadius.circular(24),
    child: Padding(padding: const EdgeInsets.all(17), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: task.status == 'COMPLETED' ? Palette.sage : i.isEven ? Palette.pastel : Palette.lavender, borderRadius: BorderRadius.circular(13)),
        child: Text('${i + 1}'.padLeft(2, '0'), style: const TextStyle(fontSize: 15, color: Palette.deep, fontWeight: FontWeight.w900))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(task.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Palette.deep))), const SizedBox(width: 5), StatusBadge(status: task.status)]),
        const SizedBox(height: 6),
        Text(task.details.isEmpty ? '暂无详细说明' : task.details, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.muted, fontSize: 12, height: 1.5)),
        const SizedBox(height: 14), const DottedDivider(), const SizedBox(height: 10),
        Row(children: [
          Icon(task.source == 'PERSONAL' ? Icons.person_outline : Icons.people_outline_rounded, size: 15, color: Palette.primary),
          const SizedBox(width: 5), Text(task.source == 'PERSONAL' ? '个人任务' : '上级派发', style: const TextStyle(fontSize: 10, color: Palette.muted)),
          if (task.urgency == 'URGENT') ...[const SizedBox(width: 6), const Pill(text: '紧急', color: Color(0xFFC3654A), background: Color(0xFFFCECE6))],
          const Spacer(),
          if (task.deadline != null) Flexible(child: Text('截止 ${friendlyDate(task.deadline!)}', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.muted, fontSize: 10))),
          const Icon(Icons.arrow_outward_rounded, size: 17, color: Palette.primary),
        ]),
      ])),
    ])),
  )));

  Widget _tab(String label,bool value)=>InkWell(onTap:()=>setState((){_personal=value;_reload();}),child:Container(alignment:Alignment.center,padding:const EdgeInsets.symmetric(vertical:14),decoration:BoxDecoration(color:_personal==value?Palette.deep:Colors.white,borderRadius:BorderRadius.circular(15)),child:Text(label,style:TextStyle(fontWeight:FontWeight.w800,color:_personal==value?Colors.white:Palette.muted))));
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
            const CanvasHeader(
              eyebrow: 'PANDORA  /  CREATE',
              title: '新建任务',
              subtitle: '把计划变成具体、可完成的行动',
              icon: Icons.add_task_rounded,
            ),
            const SizedBox(height: 20),
            StoryCard(
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
