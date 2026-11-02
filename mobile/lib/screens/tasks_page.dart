import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/business.dart';
import '../widgets/ui.dart';
import 'dispatch_page.dart';
import 'task_progress_page.dart';
import 'published_task_detail_page.dart';

/// 甲方任务台账：收到任务与本人发布记录在同一页面管理。
/// 创建入口仍由 ViewPage 统一提供；审核由后端最终校验。
class TasksPage extends StatefulWidget {
  final AppState app;
  final bool initiallyIssued;
  final Set<int> unreadTaskIds;
  final ValueChanged<int>? onTaskViewed;
  const TasksPage({super.key, required this.app, this.initiallyIssued=false,
    this.unreadTaskIds=const <int>{}, this.onTaskViewed});
  @override State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late Future<List<TaskItem>> _future;
  final search = TextEditingController();
  final _horizontal = ScrollController();
  String filter = '全部';
  bool showIssued = false;
  Future<IssuedTasksResult>? _issuedFuture;
  static const double tableWidth = 1204;
  static const double rowHeight = 54;
  @override void initState() {
    super.initState();
    showIssued=widget.initiallyIssued;
    _reload();
    if(showIssued) _issuedFuture=widget.app.repo.issuedTasks();
  }
  @override void dispose() {search.dispose(); _horizontal.dispose(); super.dispose();}
  void _reload() {
    _future = widget.app.repo.tasks(personal: false);
    if (_issuedFuture != null) _issuedFuture = widget.app.repo.issuedTasks();
  }
  void _switchTab(bool issued) {
    if (showIssued == issued) return;
    setState(() {
      showIssued = issued;
      if (issued) _issuedFuture ??= widget.app.repo.issuedTasks();
    });
  }
  void _refreshIssued() => setState(() => _issuedFuture = widget.app.repo.issuedTasks());

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), child: Row(children: [
      Expanded(child: _tab('收到的任务', !showIssued, const Key('received_tasks_tab'), () => _switchTab(false))),
      const SizedBox(width: 8),
      Expanded(child: _tab('我发布的任务', showIssued, const Key('issued_tasks_tab'), () => _switchTab(true))),
    ])),
    Expanded(child: showIssued ? _issuedBody() : _receivedBody()),
  ]);

  Widget _tab(String label, bool active, Key key, VoidCallback onTap) => Material(
    color: active ? Palette.deep : Colors.white,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(key:key,onTap:onTap,borderRadius:BorderRadius.circular(8),
      child: Container(alignment:Alignment.center,height:43,
        decoration:BoxDecoration(border:Border.all(color:active?Palette.deep:Palette.divider),borderRadius:BorderRadius.circular(8)),
        child:Text(label,style:TextStyle(color:active?Colors.white:Palette.ink,
          fontSize:13,fontWeight:FontWeight.w800)))),
  );

  Widget _receivedBody() => FutureBuilder<List<TaskItem>>(
    future: _future,
    builder: (context, snap) {
      final tasks = snap.data ?? <TaskItem>[];
      final keyword = search.text.trim().toLowerCase();
      final visible = tasks.where((t) =>
        (filter == '全部' || filter == t.statusLabel) &&
        (keyword.isEmpty || t.name.toLowerCase().contains(keyword) ||
          t.details.toLowerCase().contains(keyword))
      ).toList();
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 9, 16, 8), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('任务执行台账', style: TextStyle(
                color: Palette.deep, fontWeight: FontWeight.w900, fontSize: 19))),
              Text('共 ${visible.length} 项', style: const TextStyle(color: Palette.primary,
                fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
            const SizedBox(height: 3),
            const Text('左右滑动查看更多字段 · 上下滑动查看全部任务 · 点行查看详情',
              style: TextStyle(color: Palette.muted, fontSize: 11)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: SizedBox(height: 42, child: TextField(
                controller: search, onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18),
                  hintText: '搜索任务名称或进度备注', contentPadding: EdgeInsets.symmetric(vertical: 7))))),
              const SizedBox(width: 9),
              SizedBox(width: 102, child: DropdownButtonFormField<String>(
                key: ValueKey(filter), initialValue: filter, isExpanded: true,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 8)),
                style: const TextStyle(color: Palette.deep, fontSize: 12, fontWeight: FontWeight.w700),
                items: ['全部','待开始','进行中','已完成','受阻'].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
                onChanged: (v) {if(v != null) setState(() => filter = v);},
              )),
            ]),
          ],
        )),
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: snap.connectionState != ConnectionState.done
            ? const Center(child: CircularProgressIndicator())
            : snap.hasError
              ? ErrorPanel(error: snap.error!, onRetry: () => setState(_reload))
              : visible.isEmpty
                ? const Center(child: BusinessEmpty('当前没有匹配的接收任务'))
                : RefreshIndicator(
                    onRefresh: () async {setState(_reload); await _future;},
                    child: _ledger(visible),
                  ),
        )),
        const SizedBox(height: 64),
      ]);
    },
  );

  Widget _issuedBody() => FutureBuilder<IssuedTasksResult>(
    future: _issuedFuture,
    builder:(context,snap) {
      if(snap.connectionState!=ConnectionState.done) {
        return const Center(child:CircularProgressIndicator());
      }
      if(snap.hasError) return ErrorPanel(error:snap.error!,onRetry:_refreshIssued);
      final result=snap.data ?? const IssuedTasksResult([]);
      return Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(16,10,16,8),child:Row(children:[
          const Expanded(child:Text('我的发布记录',style:TextStyle(
            color:Palette.deep,fontSize:19,fontWeight:FontWeight.w900))),
          Text('${result.items.length} 条',style:const TextStyle(
            color:Palette.primary,fontSize:12,fontWeight:FontWeight.w800)),
          IconButton(onPressed:_refreshIssued,tooltip:'刷新发布记录',
            icon:const Icon(Icons.refresh,color:Palette.primary,size:20)),
        ])),
        if(result.notice!=null) Padding(padding:const EdgeInsets.symmetric(horizontal:16),
          child:Container(width:double.infinity,padding:const EdgeInsets.all(11),
            decoration:BoxDecoration(color:Palette.pastel,borderRadius:BorderRadius.circular(8)),
            child:Text(result.notice!,style:const TextStyle(color:Palette.deep,fontSize:11)))),
        Expanded(child:result.items.isEmpty
          ? const Center(child:BusinessEmpty('暂无发布或待审核的任务'))
          : RefreshIndicator(onRefresh:() async {
              final future=widget.app.repo.issuedTasks();
              setState(()=>_issuedFuture=future);
              await future;
            },child:ListView.separated(
              padding:const EdgeInsets.fromLTRB(12,8,12,88),
              itemCount:result.items.length,
              separatorBuilder:(_,__)=>const SizedBox(height:7),
              itemBuilder:(context,i)=>_issuedRow(result.items[i]),
            ))),
      ]);
    },
  );

  Widget _issuedRow(IssuedTask item) => Material(
    color:Colors.white,borderRadius:BorderRadius.circular(8),
    child:Container(
      decoration:BoxDecoration(border:Border.all(color:Palette.divider),borderRadius:BorderRadius.circular(8)),
      padding:const EdgeInsets.fromLTRB(13,11,13,9),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Expanded(child:Text(item.name,style:const TextStyle(color:Palette.deep,
            fontWeight:FontWeight.w800,fontSize:14),maxLines:2,overflow:TextOverflow.ellipsis)),
          const SizedBox(width:8),
          _tag(item.stateLabel,item.changePending || item.isWaiting
            ? const Color(0xFFB47A24) : item.reviewStatus=='REJECTED'
              ? Palette.coral : Palette.primary),
        ]),
        const SizedBox(height:7),
        Text('${taskTypeLabel(item.taskType)} · 接收 ${item.assigneeCount} 人 · 截止 ${_shortDate(item.deadline)}',
          style:const TextStyle(color:Palette.muted,fontSize:11),maxLines:1,overflow:TextOverflow.ellipsis),
        const SizedBox(height:8),
        Row(children:[
          TextButton(onPressed:()=>_issuedDetail(item),child:const Text('详情')),
          const Spacer(),
          TextButton(key:Key('edit_issued_${item.id}'),
            onPressed:item.changePending || (item.isRequest && !item.isWaiting)
              ? null : ()=>_editIssued(item),child:const Text('编辑')),
          TextButton(key:Key('delete_issued_${item.id}'),
            onPressed:item.changePending || (item.isRequest && !item.isWaiting)
              ? null : ()=>_deleteIssued(item),
            style:TextButton.styleFrom(foregroundColor:Palette.coral),
            child:Text(item.isRequest?'撤回':'删除')),
        ]),
      ]),
    ),
  );

  Future<void> _issuedDetail(IssuedTask item) async {
    await Navigator.push<void>(context,MaterialPageRoute<void>(
      builder:(_)=>PublishedTaskDetailPage(app:widget.app,issued:item)));
    if(mounted) _refreshIssued();
  }

  Future<void> _editIssued(IssuedTask item) async {
    final saved=await Navigator.push<bool>(context,MaterialPageRoute<bool>(
      builder:(_)=>DispatchPage(app:widget.app,editing:item)));
    if(mounted && saved==true) _refreshIssued();
  }

  Future<void> _deleteIssued(IssuedTask item) async {
    final withdraw=item.isRequest;
    final approved=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(withdraw?'撤回派发申请？':'申请删除已发布任务？'),
      content:Text(withdraw?'待审核的申请将被撤回，不会生成任务。':
        '删除必须经过管理员审核。审核通过之前，接收人仍可看到原任务。'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(withdraw?'确认撤回':'提交删除申请')),
      ],
    ));
    if(approved!=true) return;
    try {
      final status=await widget.app.repo.requestIssuedTaskDelete(item);
      if(!mounted) return;
      toast(context,status=='WITHDRAWN'?'派发申请已撤回':'删除申请已提交，等待审核');
      _refreshIssued();
    } catch(e) {if(mounted) toast(context,'操作失败：$e');}
  }

  Widget _ledger(List<TaskItem> tasks) => Container(
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Palette.divider),
      borderRadius: BorderRadius.circular(8)),
    clipBehavior: Clip.antiAlias,
    child: Scrollbar(
      controller: _horizontal,
      thumbVisibility: true,
      notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        key: const Key('task_ledger_horizontal'),
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: tableWidth, child: Column(children: [
          _header(),
          Expanded(child: Scrollbar(child: ListView.builder(
            key: const Key('task_ledger_vertical'),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemExtent: rowHeight,
            itemBuilder: (context, i) => _row(tasks[i], i),
          ))),
        ])),
      ),
    ),
  );

  Widget _cell(String text, double width, {Color? ink, FontWeight? weight,
    Alignment alignment = Alignment.centerLeft, int maxLines = 2}) =>
    Container(width: width, alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: Palette.divider, width: .55))),
      child: Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: ink ?? Palette.deep, fontSize: 11.5,
          height: 1.25, fontWeight: weight ?? FontWeight.w500)));

  Widget _header() => Container(
    height: 44, color: Palette.deep,
    child: Row(children: [
      _heading('序号', 47), _heading('任务名称', 250), _heading('任务类型', 91),
      _heading('截止日期', 150), _heading('紧急程度', 104), _heading('完成情况', 114),
      _heading('完成率', 84), _heading('进度备注 / 详情', 244), _heading('负责人', 120),
    ]),
  );

  Widget _heading(String label, double width) => SizedBox(width: width,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Align(alignment: Alignment.centerLeft,
        child: Text(label, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.w800, fontSize: 11)))));

  Widget _tag(String text, Color color) => Container(
    constraints: const BoxConstraints(maxWidth: 102),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(4)),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
  );

  Widget _tagCell(Widget tag, double width) => Container(width: width,
    alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Palette.divider, width: .55))),
    child: tag);

  Widget _row(TaskItem task, int i) => Material(
    color: i.isEven ? Colors.white : const Color(0xFFF3F6F9),
    child: InkWell(onTap: () => _detail(task),
      child: Container(height: rowHeight,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.divider, width: .65))),
        child: Row(children: [
          _cell('${i + 1}', 47, ink: Palette.muted),
          SizedBox(width: 250, child: Row(children: [
            if (widget.unreadTaskIds.contains(task.id)) ...[
              const Padding(padding: EdgeInsets.only(left: 8),
                child: CircleAvatar(key: Key('task_row_unread_dot'), radius: 4,
                  backgroundColor: Color(0xFF2267B5))),
            ],
            Expanded(child: _cell(task.name,
              widget.unreadTaskIds.contains(task.id) ? 231 : 250,
              weight: FontWeight.w800)),
          ])),
          _tagCell(_tag(taskTypeLabel(task.taskType), taskTypeColor(task.taskType)), 91),
          _cell(_shortDate(task.deadline), 150),
          _tagCell(_tag(task.urgency == 'URGENT' ? '紧急' : '普通',
            task.urgency == 'URGENT' ? const Color(0xFFD46840) : const Color(0xFF187B68)), 104),
          _tagCell(_tag(task.statusLabel,
            task.status == 'COMPLETED' ? const Color(0xFF087D79)
              : task.status == 'IN_PROGRESS' ? const Color(0xFFB47A24) : task.status=='BLOCKED'?Palette.coral:const Color(0xFF6B7886)), 114),
          _cell(task.progressPercent==null?'未填报':'${task.progressPercent}%',84,
            weight:FontWeight.w800,ink:task.progressPercent==null?Palette.muted:Palette.primary),
          _cell(task.progressNote.isNotEmpty ? task.progressNote :
            (task.details.isNotEmpty ? task.details : '—'), 244, ink: Palette.muted),
          _cell(task.assigneeName.isNotEmpty ? task.assigneeName : (widget.app.user?.name ?? '我'), 120),
        ]),
      ),
    ),
  );
  String _shortDate(String? raw) => raw == null || raw.isEmpty ? '未设置' : raw.replaceFirst('T', ' ');

  Future<void> _detail(TaskItem item) async {
    widget.onTaskViewed?.call(item.id);
    await Navigator.push<void>(context,MaterialPageRoute<void>(
      builder:(_)=>TaskProgressPage(app:widget.app,task:item),
    ));
    if(mounted) setState(_reload);
  }
}
