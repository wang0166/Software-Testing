import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../data/repository.dart';
import '../widgets/business.dart';
import '../widgets/ui.dart';

/// Everyone may submit a dispatch request. The backend approves before a task
/// becomes active, including requests from employees to managers.
class DispatchPage extends StatefulWidget {
  final AppState app;
  /// When present, this form requests an edit to a task issued by the user.
  final IssuedTask? editing;
  const DispatchPage({super.key, required this.app, this.editing});
  @override State<DispatchPage> createState() => _DispatchPageState();
}
class _DispatchPageState extends State<DispatchPage> {
  final title = TextEditingController();
  final detail = TextEditingController();
  final search = TextEditingController();
  final selected = <int>{};
  late Future<List<UserProfile>> members;
  late DateTime start, deadline;
  String urgency = 'NOT_URGENT';
  String type = 'GENERAL';
  bool busy = false;
  final Set<String> _roles = {};
  final Set<int> _departments = {};
  final Set<int> _teams = {};
  bool _selectedOnly = false;
  static const taskTypes = [
    'GENERAL', 'DEVELOPMENT', 'PRODUCT', 'TESTING',
    'OPERATION', 'SALES', 'ADMINISTRATIVE',
  ];
  @override void initState() {
    super.initState();
    final now = chinaNow;
    final previous=widget.editing;
    start = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    deadline = start.add(const Duration(days: 7));
    if(previous!=null) {
      title.text=previous.name;
      detail.text=previous.details;
      urgency=previous.urgency;
      type=previous.taskType;
      start=DateTime.tryParse(previous.startDate) ?? start;
      deadline=DateTime.tryParse(previous.deadline) ?? deadline;
      selected.addAll(previous.assigneeIds);
    }
    members = _resolveMembers();
  }

  Future<List<UserProfile>> _resolveMembers() async {
    final list=await widget.app.repo.companyMembers();
    final issued=widget.editing;
    if(issued!=null && !issued.isRequest && issued.assigneeIds.isEmpty) {
      final assignments=await widget.app.repo.dispatchedAssignments(issued.id);
      if (assignments.isEmpty) {
        throw const AppFailure('无法查询任务原有接收人，已阻止可能覆盖接收人的编辑');
      }
      if(mounted) setState(() => selected.addAll(assignments.map((e)=>e.assigneeId)));
    }
    return list;
  }
  @override void dispose() { title.dispose(); detail.dispose(); search.dispose(); super.dispose(); }
  Future<void> _submit() async {
    if (busy) return;
    if (title.text.trim().isEmpty || detail.text.trim().isEmpty || selected.isEmpty) {
      toast(context, '请填写任务标题、内容并选择接收人'); return;
    }
    if (!deadline.isAfter(start)) { toast(context, '截止时间必须晚于开始时间'); return; }
    setState(() => busy = true);
    try {
      final editing=widget.editing;
      final state = editing == null
        ? await widget.app.repo.submitDispatchRequest(
            name: title.text.trim(), details: detail.text.trim(),
            startDate: taskDateTimeIso(start), deadline: taskDateTimeIso(deadline),
            urgency: urgency, taskType: type, assigneeIds: selected.toList(),
          )
        : await widget.app.repo.requestIssuedTaskEdit(editing,
            name: title.text.trim(), details: detail.text.trim(),
            startDate: taskDateTimeIso(start), deadline: taskDateTimeIso(deadline),
            urgency: urgency, taskType: type, assigneeIds: selected.toList(),
          );
      if (!mounted) return;
      toast(context, state == 'PENDING' ? (editing == null ? '派发申请已提交，等待审核' : '修改已提交，等待审核') : '请求状态：$state');
      Navigator.pop(context, true);
    } catch (e) { if (mounted) toast(context, '申请未成功：$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.editing == null ? '创建派发任务' : '编辑我发布的任务')),
    body: FutureBuilder<List<UserProfile>>(future: members, builder: (context, snap) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 22), children: [
        BusinessHeading(title: widget.editing == null ? '任务派发申请' : '修改任务申请',
          subtitle: widget.editing?.isRequest == true ? '修改待审申请 · 不会直接派发' : '可编辑所有任务字段 · 审核前不改变已发布任务'),
        const SizedBox(height: 14),
        TextField(controller: title, maxLength: 200, decoration: const InputDecoration(labelText: '任务标题')),
        const SizedBox(height: 9),
        TextField(controller: detail, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '任务内容')),
        const SizedBox(height: 14),
        _dateLine('开始时间', start, () async {
          final picked = await pickTaskDateTime(context, start);
          if (picked != null) setState(() { start = picked; if (!deadline.isAfter(start)) deadline = start.add(const Duration(hours: 1)); });
        }),
        const SizedBox(height: 10),
        _dateLine('截止时间', deadline, () async {
          final picked = await pickTaskDateTime(context, deadline);
          if (picked != null) setState(() => deadline = picked);
        }),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            key: ValueKey('dispatch_type_$type'),
            initialValue: type, isExpanded: true,
            decoration: InputDecoration(labelText: '任务类型', filled: true,
              fillColor: taskTypeColor(type).withValues(alpha: .09),
              enabledBorder: OutlineInputBorder(borderSide:
                BorderSide(color: taskTypeColor(type).withValues(alpha: .6)))),
            items: taskTypes.map((v) => DropdownMenuItem(value: v,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(
                  color: taskTypeColor(v), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 7),
                Flexible(child: Text(taskTypeLabel(v), style: TextStyle(
                  color: taskTypeColor(v), fontWeight: FontWeight.w800))),
              ]))).toList(),
            onChanged: (v) => setState(() => type = v ?? type),
          )),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(initialValue: urgency,
            decoration: const InputDecoration(labelText: '优先级'), items: const [
              DropdownMenuItem(value: 'NOT_URGENT', child: Text('普通')),
              DropdownMenuItem(value: 'URGENT', child: Text('紧急')),
            ], onChanged: (v) => setState(() => urgency = v ?? urgency))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(child: Text('选择接收人（全公司）', style: TextStyle(color: Palette.deep, fontWeight: FontWeight.w800, fontSize: 16))),
          Text('已选 ${selected.length} 人', style: const TextStyle(color: Palette.primary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        TextField(controller: search, onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '搜索姓名或账号',
            prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 8),
        if (snap.connectionState == ConnectionState.done && !snap.hasError)
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _memberFilters(snap.data ?? []),
              icon: const Icon(Icons.tune, size: 17),
              label: Text('职务 / 部门 / 团队筛选 ${_roles.length + _departments.length + _teams.length > 0 ? '(${_roles.length + _departments.length + _teams.length})' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            )),
            const SizedBox(width: 7),
            FilterChip(label: const Text('仅已选'),
              selected: _selectedOnly,
              onSelected: (v) => setState(() => _selectedOnly = v)),
          ]),
        const SizedBox(height: 8),
        if (snap.connectionState != ConnectionState.done)
          const LinearProgressIndicator()
        else if (snap.hasError)
          BusinessPanel(title: '成员列表不可用', child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Text('需要后端提供全公司成员查询接口。\n${snap.error}',
              style: const TextStyle(color: Palette.coral, fontSize: 12))))
        else if ((snap.data ?? []).isEmpty)
          const BusinessPanel(title: '成员列表', child: BusinessEmpty('暂无可选公司成员'))
        else _membersList(snap.data!),
        const SizedBox(height: 12),
        const Text('审核说明：员工可向上级申请派发任务。后端须校验派发对象及审批状态，审核通过前不生成接收任务。',
          style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.6)),
      ],
    )),
    bottomNavigationBar: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 9, 16, 10), child: FilledButton(
      onPressed: busy ? null : _submit, child: Text(busy ? '正在提交申请…' : widget.editing == null ? '提交派发申请（待审核）' : '提交修改申请（待审核）'),
    ))),
  );
  List<UserProfile> _visibleMembers(List<UserProfile> all) {
    final keyword = search.text.trim().toLowerCase();
    return all.where((p) =>
      p.id != widget.app.user?.id &&
      (keyword.isEmpty || '${p.name} ${p.username}'.toLowerCase().contains(keyword)) &&
      (_roles.isEmpty || _roles.contains(p.role)) &&
      (_departments.isEmpty || _departments.contains(p.departmentId)) &&
      (_teams.isEmpty || _teams.contains(p.teamId)) &&
      (!_selectedOnly || selected.contains(p.id))
    ).toList();
  }

  Widget _membersList(List<UserProfile> all) {
    final visible = _visibleMembers(all);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Palette.divider)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
          child: Row(children: [
            Expanded(child: Text('筛选结果 ${visible.length} / ${all.length} 人',
              style: const TextStyle(fontSize: 12, color: Palette.muted))),
            TextButton(onPressed: visible.isEmpty ? null : () => setState(() =>
              selected.addAll(visible.map((e) => e.id))), child: const Text('全选结果')),
            TextButton(onPressed: visible.isEmpty ? null : () => setState(() =>
              selected.removeAll(visible.map((e) => e.id))), child: const Text('取消结果')),
          ])),
        const Divider(height: 1),
        SizedBox(height: 310, child: visible.isEmpty
          ? const Center(child: Text('没有符合条件的成员'))
          : ListView.builder(itemCount: visible.length,
            itemBuilder: (context, index) {
              final person = visible[index];
              return CheckboxListTile(
                key: Key('dispatch_member_${person.id}'),
                title: Text(person.name, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700)),
                subtitle: Text('${person.roleLabel} · 部门 ${person.departmentId ?? '未分配'} · 团队 ${person.teamId ?? '未分配'}',
                  style: const TextStyle(fontSize: 11)),
                dense: true, visualDensity: const VisualDensity(vertical: -3),
                value: selected.contains(person.id), activeColor: Palette.primary,
                onChanged: (v) => setState(() => v == true
                  ? selected.add(person.id) : selected.remove(person.id)),
              );
            })),
      ]),
    );
  }

  Future<void> _memberFilters(List<UserProfile> members) async {
    final roles = members.map((e) => e.role).toSet().toList()..sort();
    final departments = members.map((e) => e.departmentId)
      .whereType<int>().toSet().toList()..sort();
    final teams = members.map((e) => e.teamId)
      .whereType<int>().toSet().toList()..sort();
    await showModalBottomSheet<void>(context: context,
      isScrollControlled: true, showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (context, update) {
        void change(void Function() action) {
          setState(action);
          update(() {});
        }
        return SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 0, 17, 18),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('筛选任务接收人', style: TextStyle(
                color: Palette.deep, fontWeight: FontWeight.w900, fontSize: 19)),
              const Text('每组可多选；组内取并集，不同组取交集',
                style: TextStyle(color: Palette.muted, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('职务', style: TextStyle(fontWeight: FontWeight.w800)),
              Wrap(spacing: 7, children: [for (final value in roles)
                FilterChip(label: Text(members.firstWhere((m) => m.role == value).roleLabel),
                  selected: _roles.contains(value), onSelected: (v) => change(() =>
                    v ? _roles.add(value) : _roles.remove(value))),
              ]),
              const SizedBox(height: 10),
              const Text('部门', style: TextStyle(fontWeight: FontWeight.w800)),
              Wrap(spacing: 7, children: [for (final value in departments)
                FilterChip(label: Text('部门 $value'),
                  selected: _departments.contains(value), onSelected: (v) => change(() =>
                    v ? _departments.add(value) : _departments.remove(value))),
              ]),
              const SizedBox(height: 10),
              const Text('团队', style: TextStyle(fontWeight: FontWeight.w800)),
              Wrap(spacing: 7, children: [for (final value in teams)
                FilterChip(label: Text('团队 $value'),
                  selected: _teams.contains(value), onSelected: (v) => change(() =>
                    v ? _teams.add(value) : _teams.remove(value))),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                TextButton(onPressed: () => change(() {
                  _roles.clear(); _departments.clear(); _teams.clear();
                }), child: const Text('清空筛选')),
                const Spacer(),
                FilledButton(onPressed: () => Navigator.pop(sheet),
                  child: const Text('查看结果')),
              ]),
            ],
          )),
        ));
      }),
    );
  }

  Widget _dateLine(String caption, DateTime value, VoidCallback tap) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(8), child: InkWell(
      onTap: tap, borderRadius: BorderRadius.circular(8), child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13), decoration: BoxDecoration(border: Border.all(color: Palette.divider), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(caption, style: const TextStyle(color: Palette.muted, fontSize: 11)),
            const SizedBox(height: 4), Text(formatTaskDateTime(value), style: const TextStyle(color: Palette.deep, fontSize: 18, fontWeight: FontWeight.w800)),
          ])),
          const Icon(Icons.edit_calendar, size: 20, color: Palette.primary),
        ]),
      ),
    ),
  );
}

String formatTaskDateTime(DateTime value) => '${dayString(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String taskDateTimeIso(DateTime value) => '${dayString(value)}T${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
Future<DateTime?> pickTaskDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100), helpText: '选择任务日期');
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial), helpText: '精确到小时与分钟', initialEntryMode: TimePickerEntryMode.input);
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
