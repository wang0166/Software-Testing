import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../data/repository.dart';
import '../widgets/business.dart';

/// Task execution: update progress without editing the dispatch definition.
/// Real-mode updates are server-verified; no local success simulation.
class TaskProgressPage extends StatefulWidget {
  final AppState app;
  final TaskItem task;
  const TaskProgressPage({super.key, required this.app, required this.task});

  @override
  State<TaskProgressPage> createState() => _TaskProgressPageState();
}

class _TaskProgressPageState extends State<TaskProgressPage> {
  late TaskItem current;
  late Future<List<TaskProgressRecord>> history;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    current = widget.task;
    _loadHistory();
  }

  void _loadHistory() {
    history = widget.app.repo.taskProgressHistory(current.id);
  }

  Future<void> _refresh() async {
    try {
      final list = await widget.app.repo.tasks(personal: false);
      final match = list.where((e) => e.id == current.id).toList();
      if (!mounted) { return; }
      setState(() {
        if (match.isNotEmpty) { current = match.first; }
        _loadHistory();
      });
      await history;
    } catch (_) {
      if (mounted) { setState(_loadHistory); }
    }
  }

  String _recordStatus(String value) => const {
    'NOT_STARTED':'待开始','IN_PROGRESS':'进行中','BLOCKED':'受阻',
    'COMPLETED':'已完成','APPROVED':'完成检查通过','RETURNED':'完成检查退回',
  }[value]??value;

  String _display(String? value) {
    if (value == null || value.trim().isEmpty) { return '未设置'; }
    return value.replaceFirst('T', ' ');
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
  );

  @override
  Widget build(BuildContext context) {
    final task = current;
    final percent = task.progressPercent;
    return Scaffold(
      appBar: AppBar(title: const Text('任务执行详情')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Palette.deep,
                borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TASK EXECUTION / 任务执行',
                  style: TextStyle(color: Color(0xFFA4BBC8),fontSize: 11,letterSpacing: 1)),
                const SizedBox(height: 10),
                Text(task.name,style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900,fontSize: 22,height: 1.3)),
                const SizedBox(height: 12),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  _tag(taskTypeLabel(task.taskType), const Color(0xFF9BE1DB)),
                  _tag(task.statusLabel, const Color(0xFFE8EFF7)),
                  if (task.urgency == 'URGENT') _tag('紧急', const Color(0xFFFFCF9F)),
                  if (task.isOverdue) _tag('已逾期', const Color(0xFFFFB3A8)),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            BusinessPanel(title:'任务信息',child:Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(task.details.isEmpty?'暂无详细说明':task.details,
                  style: const TextStyle(color: Palette.ink, height: 1.55, fontSize: 14)),
                const SizedBox(height: 13),
                _field('负责人',task.assigneeName.isEmpty?(widget.app.user?.name??'当前用户'):task.assigneeName),
                _field('开始时间',_display(task.startDate)),
                _field('截止时间',_display(task.deadline)),
                _field('完成检查',const {'NONE':'未申请','PENDING':'检查中','APPROVED':'已通过','RETURNED':'已退回'}[task.reviewStatus]??task.reviewStatus),
              ]),
            )),
            const SizedBox(height: 12),
            BusinessPanel(title:'完成率与进度反馈',child:Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('当前进度',style:TextStyle(color:Palette.ink,fontWeight:FontWeight.w700))),
                  Text(percent==null?'未填报':'$percent%',
                    style: const TextStyle(color:Palette.primary,fontSize:23,fontWeight:FontWeight.w900)),
                ]),
                const SizedBox(height: 8),
                if (percent!=null) LinearProgressIndicator(
                  value: percent/100, minHeight: 8, color: Palette.primary,
                  borderRadius:BorderRadius.circular(5),backgroundColor:Palette.divider),
                const SizedBox(height: 12),
                Text(task.progressNote.isEmpty?'暂无进度备注':task.progressNote,
                  style:const TextStyle(fontSize:13,color:Palette.ink,height:1.5)),
                if (task.progressUpdatedAt!=null) Padding(
                  padding:const EdgeInsets.only(top:8),
                  child:Text('最近更新：${_display(task.progressUpdatedAt)}',
                    style:const TextStyle(color:Palette.muted,fontSize:11))),
                const SizedBox(height: 15),
                if(task.status!='COMPLETED') SizedBox(width:double.infinity,
                  child:FilledButton.icon(
                    key:const Key('task_update_progress'),
                    onPressed:saving?null:_editProgress,
                    icon: const Icon(Icons.edit_note,size:20),
                    label:const Text('更新进度 / 填写反馈'))),
                if(task.status=='COMPLETED' &&
                    (task.reviewStatus=='NONE' || task.reviewStatus=='RETURNED'))
                  SizedBox(width:double.infinity,child:OutlinedButton(
                    onPressed:saving?null:_inviteReview,
                    child:const Text('申请完成检查'))),
              ]),
            )),
            const SizedBox(height: 12),
            BusinessPanel(title:'任务流转记录',child:Padding(
              padding:const EdgeInsets.symmetric(vertical:12),
              child:FutureBuilder<List<TaskProgressRecord>>(
                future:history,
                builder:(context,snap) {
                  if(snap.connectionState!=ConnectionState.done) {
                    return const Center(child:Padding(padding:EdgeInsets.all(14),child:CircularProgressIndicator()));
                  }
                  if (snap.hasError) {
                    return Column(
                      crossAxisAlignment:CrossAxisAlignment.start,children:[
                        const Text('历史记录接口尚不可用或无查看权限。新记录仅在服务器成功保存后显示。',
                          style:TextStyle(color:Palette.muted,fontSize:12)),
                        const SizedBox(height:5),
                        Text('${snap.error}',style:const TextStyle(color:Palette.coral,fontSize:11)),
                        TextButton(onPressed:()=>setState(_loadHistory),child:const Text('重试')),
                      ]);
                  }
                  final items=snap.data??[];
                  if(items.isEmpty) { return const Text('暂无历史进度记录',style:TextStyle(color:Palette.muted)); }
                  return Column(children:[
                    for(var i=0;i<items.length;i++) ...[
                      if(i>0) const Divider(height:22,color:Palette.divider),
                      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Container(width:8,height:8,margin:const EdgeInsets.only(top:6,right:10),
                          decoration:const BoxDecoration(color:Palette.primary,shape:BoxShape.circle)),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text('${items[i].authorName} · ${_display(items[i].createdAt)}',
                            style:const TextStyle(color:Palette.muted,fontSize:11)),
                          const SizedBox(height:3),
                          Text('${_recordStatus(items[i].status)}${items[i].percent==null?'':' · ${items[i].percent}%'}',
                            style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w800)),
                          if(items[i].note.isNotEmpty) Text(items[i].note,style:const TextStyle(color:Palette.ink,fontSize:12,height:1.5)),
                        ])),
                      ]),
                    ],
                  ]);
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _field(String label,String text) => Padding(
    padding:const EdgeInsets.only(top:7),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(width:83,child:Text(label,style:const TextStyle(color:Palette.muted,fontSize:12))),
      Expanded(child:Text(text,style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w600,fontSize:12))),
    ]));

  Future<void> _editProgress() async {
    var status=current.status;
    var percentage=current.progressPercent??(status=='COMPLETED'?100:0);
    final note=TextEditingController();
    final approved=await showModalBottomSheet<bool>(
      context:context,isScrollControlled:true,showDragHandle:true,
      builder:(ctx) => StatefulBuilder(builder:(ctx,update) => SafeArea(child:
        Padding(padding:EdgeInsets.fromLTRB(20,8,20,MediaQuery.viewInsetsOf(ctx).bottom+24),
        child:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('更新任务进度',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:Palette.deep)),
            const SizedBox(height:7),
            const Text('仅更新执行状态与进度。任务名称、人员和截止日期变更仍须审核。',
              style:TextStyle(color:Palette.muted,fontSize:12)),
            const SizedBox(height:17),
            DropdownButtonFormField<String>(
              key:const Key('progress_status'),initialValue:status,
              decoration:const InputDecoration(labelText:'执行状态'),
              items:const [
                DropdownMenuItem(value:'NOT_STARTED',child:Text('待开始')),
                DropdownMenuItem(value:'IN_PROGRESS',child:Text('进行中')),
                DropdownMenuItem(value:'BLOCKED',child:Text('受阻')),
                DropdownMenuItem(value:'COMPLETED',child:Text('已完成')),
              ],
              onChanged:(value) {
                if (value != null) {
                  update(() {
                    status = value;
                    if (status == 'COMPLETED') {
                      percentage = 100;
                    } else if (percentage == 100) {
                      percentage = 99;
                    }
                  });
                }
              },
            ),
            const SizedBox(height:16),
            Row(children:[
              const Expanded(child:Text('完成百分比',style:TextStyle(fontWeight:FontWeight.w700))),
              Text('$percentage%',style:const TextStyle(color:Palette.primary,fontSize:18,fontWeight:FontWeight.w900)),
            ]),
            Slider(key:const Key('progress_percent'),value:percentage.toDouble(),min:0,max:100,divisions:20,
              onChanged:status=='COMPLETED'?null:(value)=>update(()=>percentage=value.round())),
            const SizedBox(height:10),
            TextField(key:const Key('progress_note'),controller:note,maxLines:4,maxLength:1000,
              decoration:InputDecoration(labelText:status=='BLOCKED'?'受阻原因（必填）':'进度备注 / 当前问题',
                hintText:'例如：已完成接口联调，待处理权限异常')),
            const SizedBox(height:10),
            SizedBox(width:double.infinity,child:FilledButton(
              onPressed:()=>Navigator.pop(ctx,true),child:const Text('保存进度记录'))),
          ],
        )))
      )),
    );
    final message=note.text.trim();
    note.dispose();
    if(approved!=true || !mounted) { return; }
    final error=taskProgressValidation(current,status,percentage,message);
    if(error!=null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error)));
      return;
    }
    setState(()=>saving=true);
    try {
      await widget.app.repo.updateTaskProgress(current,
        status:status,percent:percentage,note:message);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('进度已保存，任务台账将同步刷新')));
      }
    } on AppFailure catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text('保存失败：${e.message}')));
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text('保存失败：$e')));
      }
    } finally {
      if(mounted) { setState(()=>saving=false); }
    }
  }

  Future<void> _inviteReview() async {
    setState(()=>saving=true);
    try {
      await widget.app.repo.inviteReview(current.id);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('已申请完成检查，等待上级处理')));
      }
    }catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text('提交检查失败：$e')));
      }
    }finally {
      if(mounted) { setState(()=>saving=false); }
    }
  }
}
