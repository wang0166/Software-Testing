import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/business.dart';
import '../widgets/ui.dart';

/// Everyone may submit a dispatch request. The backend approves before a task
/// becomes active, including requests from employees to managers.
class DispatchPage extends StatefulWidget {
  final AppState app;
  const DispatchPage({super.key, required this.app});
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
  @override void initState() {
    super.initState();
    final now = chinaNow;
    start = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    deadline = start.add(const Duration(days: 7));
    members = widget.app.repo.companyMembers();
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
      final state = await widget.app.repo.submitDispatchRequest(
        name: title.text.trim(), details: detail.text.trim(),
        startDate: taskDateTimeIso(start), deadline: taskDateTimeIso(deadline),
        urgency: urgency, taskType: type, assigneeIds: selected.toList(),
      );
      if (!mounted) return;
      toast(context, state == 'PENDING' ? '任务派发申请已提交，等待审核' : '任务已由服务端批准');
      Navigator.pop(context, true);
    } catch (e) { if (mounted) toast(context, '申请未成功：$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('创建派发任务')),
    body: FutureBuilder<List<UserProfile>>(future: members, builder: (context, snap) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 22), children: [
        const BusinessHeading(title: '任务派发申请', subtitle: '可选择全公司成员 · 创建后须经管理员审核'),
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
          Expanded(child: DropdownButtonFormField<String>(initialValue: type,
            decoration: const InputDecoration(labelText: '任务类型'),
            items: const [
              DropdownMenuItem(value:'GENERAL',child:Text('综合')),
              DropdownMenuItem(value:'DEVELOPMENT',child:Text('开发')),
              DropdownMenuItem(value:'PRODUCT',child:Text('产品')),
              DropdownMenuItem(value:'TESTING',child:Text('测试')),
              DropdownMenuItem(value:'OPERATION',child:Text('运营')),
              DropdownMenuItem(value:'SALES',child:Text('销售')),
              DropdownMenuItem(value:'ADMINISTRATIVE',child:Text('行政')),
            ], onChanged: (v) => setState(() => type = v ?? type))),
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
        TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: '按姓名或账号搜索', prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 9),
        if (snap.connectionState != ConnectionState.done) const LinearProgressIndicator()
        else if (snap.hasError) BusinessPanel(title: '成员列表不可用', child: Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Text('需要后端提供全公司成员查询接口。\n${snap.error}', style: const TextStyle(color: Palette.coral, fontSize: 12))))
        else if ((snap.data ?? []).isEmpty) const BusinessPanel(title: '成员列表', child: BusinessEmpty('暂无可选公司成员'))
        // CheckboxListTile needs its own Material ancestor for selection ink.
        // A DecoratedBox/Container with a background would hide the ink splash
        // and trigger a Flutter framework assertion in widget tests.
        else Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Palette.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final person in snap.data!.where((p) => p.id != widget.app.user!.id &&
              ('${p.name}${p.username}'.toLowerCase().contains(search.text.trim().toLowerCase()))))
              CheckboxListTile(
                title: Text(person.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: Text('${person.roleLabel} · ${person.username}', style: const TextStyle(fontSize: 11)),
                dense: true, visualDensity: const VisualDensity(vertical: -3),
                value: selected.contains(person.id), activeColor: Palette.primary,
                onChanged: (v) => setState(() => v == true ? selected.add(person.id) : selected.remove(person.id)),
              ),
          ])),
        const SizedBox(height: 12),
        const Text('审核说明：员工可向上级申请派发任务。后端须校验派发对象及审批状态，审核通过前不生成接收任务。',
          style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.6)),
      ],
    )),
    bottomNavigationBar: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 9, 16, 10), child: FilledButton(
      onPressed: busy ? null : _submit, child: Text(busy ? '正在提交申请…' : '提交派发申请（待审核）'),
    ))),
  );
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
