import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/business.dart';
import 'log_detail_page.dart';
import 'subordinate_task_detail_page.dart';
import '../widgets/subordinate_task_row.dart';

/// 只展示后端授权返回的下属业务信息，绝不推测联系方式或展示私密点评。
class SubordinateDetailPage extends StatefulWidget {
  final AppState app;
  final SubordinateTaskSummary member;
  const SubordinateDetailPage({super.key, required this.app,
    required this.member});

  @override State<SubordinateDetailPage> createState() => _SubordinateDetailPageState();
}

class _SubordinateDetailPageState extends State<SubordinateDetailPage> {
  late Future<List<WorkLog>> _logs;
  late SubordinateTaskSummary member;
  final _taskSearch = TextEditingController();
  final _logSearch = TextEditingController();
  String _taskState = '全部任务';
  String _logState = '全部日志';
  bool _newestFirst = true;
  DateTimeRange? _logDates;
  int _shownTasks = 20;
  int _shownLogs = 20;

  @override void dispose() {
    _taskSearch.dispose();
    _logSearch.dispose();
    super.dispose();
  }

  Future<void> _chooseLogDates() async {
    final dates = await showDateRangePicker(context: context,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      initialDateRange: _logDates, helpText: '筛选下属日志日期');
    if (dates != null && mounted) {
      setState(() {
        _logDates = dates;
        _shownLogs = 20;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    member=widget.member;
    _loadLogs();
  }

  void _loadLogs() {
    _logs = widget.app.repo.logs().then((items) =>
      items.where((e) => e.authorId == widget.member.userId).toList()
        ..sort((a, b) => b.logDate.compareTo(a.logDate)));
  }

  Future<void> _openTask(TaskItem task) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
      SubordinateTaskDetailPage(app:widget.app,memberId:member.userId,
        memberName:member.name,task:task)));
    if (!mounted) return;
    try {
      final fresh=await widget.app.repo.subordinatesTaskOverview();
      if (!mounted) return;
      final found=fresh.where((m)=>m.userId==member.userId).toList();
      if(found.isNotEmpty) setState(()=>member=found.first);
    } catch (_) {/* The task detail already shows API failures. */}
  }

  @override
  Widget build(BuildContext context) {
    final taskKeyword = _taskSearch.text.trim().toLowerCase();
    final visibleTasks = member.tasks.where((task) =>
      (_taskState == '全部任务' ||
        (_taskState == '已完成' ? task.status == 'COMPLETED'
          : task.status != 'COMPLETED')) &&
      (taskKeyword.isEmpty || '${task.name} ${task.details}'
        .toLowerCase().contains(taskKeyword))).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('下属个人信息')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          BusinessPanel(
            title: '成员信息',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 17),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 28, backgroundColor: Palette.sage,
                  child: Text(member.name.isEmpty ? '员' : member.name.substring(0, 1),
                    style: const TextStyle(fontWeight: FontWeight.w900,
                      fontSize: 22, color: Palette.deep)),
                ),
                const SizedBox(width: 13),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: const TextStyle(color: Palette.deep,
                      fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    _field('部门 / 组织', member.departmentName),
                    if (member.teamName.isNotEmpty)
                      _field('团队', member.teamName),
                    if (member.role.isNotEmpty)
                      _field('岗位角色', const {
                        'EMPLOYEE': '员工', 'TEAM_LEADER': '团队长',
                        'DEPT_MANAGER': '部门老总', 'FOUNDER': '创始人',
                      }[member.role] ?? member.role),
                    if (member.username.isNotEmpty)
                      _field('工作账号', member.username),
                    _field('MBTI（选填）', member.mbtiType.isEmpty ? '未提供' : member.mbtiType),
                  ],
                )),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          BusinessPanel(
            title: '当前任务', count: null,
            trailing:member.visibleIssueCount>0?Container(
              padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),
              decoration:BoxDecoration(color:const Color(0xFFD63D39),borderRadius:BorderRadius.circular(13)),
              child:Text('${member.visibleIssueCount}',
                style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900))):null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: _metric('任务总数', member.total)),
                  Expanded(child: _metric('进行中', member.inProgress)),
                  Expanded(child: _metric('已完成', member.completed)),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing:13,runSpacing:7,children:[
                  Text('待解决问题 ${member.visibleIssueCount}',
                    style:const TextStyle(color:Palette.coral,fontSize:12,fontWeight:FontWeight.w700)),
                  Text('逾期 ${member.tasks.where((t)=>t.isOverdue).length}',
                    style:const TextStyle(color:Palette.coral,fontSize:12,fontWeight:FontWeight.w700)),
                ]),
                const SizedBox(height: 12),
                TextField(controller: _taskSearch,
                  onChanged: (_) => setState(() => _shownTasks = 20),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 19),
                    hintText: '搜索任务名称、任务内容')),
                const SizedBox(height: 7),
                Wrap(spacing: 8, children: [
                  for (final value in ['全部任务', '进行中', '已完成'])
                    ChoiceChip(label: Text(value), selected: _taskState == value,
                      showCheckmark: false, onSelected: (_) => setState(() {
                        _taskState = value; _shownTasks = 20;
                      })),
                ]),
                Text('筛选结果 ${visibleTasks.length} 条',
                  style: const TextStyle(color: Palette.muted, fontSize: 11)),
                if (visibleTasks.isEmpty)
                  const BusinessEmpty('当前条件下没有任务')
                else
                  for (var i = 0; i < visibleTasks.length && i < _shownTasks; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Palette.divider),
                    SubordinateTaskRow(task: visibleTasks[i], index: i + 1,
                      onTap: () => _openTask(visibleTasks[i])),
                  ],
                if (visibleTasks.length > _shownTasks)
                  TextButton.icon(onPressed: () => setState(() => _shownTasks += 20),
                    icon: const Icon(Icons.expand_more),
                    label: Text('加载更多（还剩 ${visibleTasks.length - _shownTasks} 条）')),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          BusinessPanel(
            title: '工作日志',
            child: FutureBuilder<List<WorkLog>>(
              future: _logs,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('日志暂不可用：${snapshot.error}',
                      style: const TextStyle(color: Palette.muted, fontSize: 12)),
                  );
                }
                final keyword = _logSearch.text.trim().toLowerCase();
                final logs = (snapshot.data ?? []).where((log) {
                  if (_logState == '已提交' && !log.submitted) return false;
                  if (_logState == '草稿' && log.submitted) return false;
                  if (keyword.isNotEmpty &&
                    !'${log.content} ${log.logDate}'.toLowerCase().contains(keyword)) {
                    return false;
                  }
                  if (_logDates != null) {
                    final date = DateTime.tryParse(log.logDate);
                    if (date == null || date.isBefore(_logDates!.start) ||
                      date.isAfter(_logDates!.end)) {
                      return false;
                    }
                  }
                  return true;
                }).toList()..sort((a, b) => _newestFirst
                  ? b.logDate.compareTo(a.logDate)
                  : a.logDate.compareTo(b.logDate));
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: 10),
                  TextField(controller: _logSearch, onChanged: (_) =>
                    setState(() => _shownLogs = 20),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 19),
                      hintText: '搜索日志关键词或日期')),
                  const SizedBox(height: 7),
                  Wrap(spacing: 7, runSpacing: 6, crossAxisAlignment:
                    WrapCrossAlignment.center, children: [
                    SizedBox(width: 104, child: DropdownButtonFormField<String>(
                      key: ValueKey(_logState), initialValue: _logState,
                      decoration: const InputDecoration(contentPadding:
                        EdgeInsets.symmetric(horizontal: 7, vertical: 8)),
                      items: ['全部日志', '已提交', '草稿'].map((v) =>
                        DropdownMenuItem(value: v, child: Text(v,
                          style: const TextStyle(fontSize: 11)))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _logState = v;
                            _shownLogs = 20;
                          });
                        }
                      },
                    )),
                    ActionChip(label: Text(_newestFirst ? '最新在前' : '最早在前'),
                      onPressed: () => setState(() => _newestFirst = !_newestFirst)),
                    ActionChip(label: Text(_logDates == null ? '选择日期段'
                      : '${_logDates!.start.month}/${_logDates!.start.day}—${_logDates!.end.month}/${_logDates!.end.day}'),
                      onPressed: _chooseLogDates),
                    if (_logDates != null)
                      ActionChip(label: const Text('清除日期'),
                        onPressed: () => setState(() => _logDates = null)),
                  ]),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('共 ${logs.length} 条匹配日志 · 每次展示 20 条',
                      style: const TextStyle(color: Palette.muted, fontSize: 11))),
                  if (logs.isEmpty) const BusinessEmpty('没有符合条件的授权日志')
                  else for (var i = 0; i < logs.length && i < _shownLogs; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Palette.divider),
                    BusinessRow(
                      title: logs[i].content.replaceAll('\n', ' '),
                      subtitle: '${logs[i].logDate} · ${logs[i].submitted ? '已提交' : '草稿'}',
                      onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                        builder: (_) => LogDetailPage(app: widget.app, log: logs[i]))),
                    ),
                  ],
                  if (logs.length > _shownLogs)
                    TextButton.icon(onPressed: () => setState(() => _shownLogs += 20),
                      icon: const Icon(Icons.expand_more),
                      label: Text('加载更多（还剩 ${logs.length - _shownLogs} 条）')),
                ]);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text('仅展示当前账号获得授权的人员、任务与日志。个人联系方式等字段须由后端明确授权后才可展示。',
              style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Text('$label：$value', style: const TextStyle(
      color: Palette.muted, fontSize: 12, height: 1.4)),
  );

  Widget _metric(String label, int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$count', style: const TextStyle(color: Palette.deep,
        fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Palette.muted, fontSize: 11)),
    ],
  );
}
