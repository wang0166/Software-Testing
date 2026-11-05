import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/log_filters.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'log_detail_page.dart';

/// 可见日志由服务端授权；UI 对已授权日志再按部门/团队分组。
class LogsPage extends StatefulWidget {
  final AppState app;
  const LogsPage({super.key, required this.app});
  @override State<LogsPage> createState() => _LogsPageState();
}
class _LogsPageState extends State<LogsPage> {
  late Future<List<WorkLog>> _future;
  Future<List<SubordinateTaskSummary>>? _subordinates;
  int? _selectedSubordinateId;
  final _search = TextEditingController();
  String _filter = '部门日志';
  String? _department;
  @override void initState() {super.initState(); _refresh();}
  @override void dispose() {_search.dispose(); super.dispose();}
  void _refresh() {
    _future = widget.app.repo.logs();
    if (_filter == '我的下属') {
      _subordinates = widget.app.repo.subordinatesTaskOverview();
    }
  }
  void _selectMode(String mode) {
    setState(() {
      _filter = mode;
      _department = null;
      _selectedSubordinateId = null;
      if (mode == '我的下属') {
        _subordinates ??= widget.app.repo.subordinatesTaskOverview();
      }
    });
  }
  Future<void> _edit(WorkLog? draft, String date) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => LogEditorPage(app: widget.app, draft: draft, date: date)));
    if (ok == true && mounted) setState(_refresh);
  }
  Future<void> _write() async {
    final now = chinaNow;
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context, initialDate: today,
      firstDate: today.subtract(const Duration(days: 2)), lastDate: today,
      helpText: '选择近三天日志日期',
    );
    if (date == null || !mounted) return;
    final selectedDay = dayString(date);
    try {
      final entries = await widget.app.repo.logs(date: selectedDay);
      if (!mounted) return;
      final mine = entries.where((e) => e.authorId == widget.app.user!.id).toList();
      await _edit(mine.isEmpty ? null : mine.first, selectedDay);
    } catch (e) { if (mounted) toast(context, '$e'); }
  }
  String _dept(WorkLog l) => l.departmentName.isNotEmpty ? l.departmentName : l.departmentId == null ? '未标注部门' : '部门 ${l.departmentId}';
  String _team(WorkLog l) => l.teamName.isNotEmpty ? l.teamName : l.teamId == null ? '部门直属' : '团队 ${l.teamId}';
  @override Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('工作日志', style: TextStyle(color: Palette.deep, fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4), const Text('部门、我的、下属日志独立筛选，仅显示授权数据', style: TextStyle(color: Palette.muted, fontSize: 12)),
        const SizedBox(height: 14), TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: '搜索姓名或日志内容')),
        const SizedBox(height: 12), Row(children: [for (final option in [
          '部门日志', '我的日志',
          if (const ['TEAM_LEADER', 'DEPT_MANAGER', 'FOUNDER'].contains(widget.app.user?.role))
            '我的下属',
        ]) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(
          onTap: () => _selectMode(option), borderRadius: BorderRadius.circular(9), child: Container(alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: _filter == option ? Palette.deep : Colors.white, borderRadius: BorderRadius.circular(9)), child: Text(option, style: TextStyle(color: _filter == option ? Colors.white : Palette.muted, fontWeight: FontWeight.w800))),
        )))]),
      ])),
      Expanded(child: FutureBuilder<List<SubordinateTaskSummary>>(
        future: _filter == '我的下属' ? _subordinates : null,
        builder: (context, membersSnapshot) {
          if (_filter == '我的下属') {
            if (membersSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (membersSnapshot.hasError) {
              return ErrorPanel(error: membersSnapshot.error!,
                onRetry: () => setState(_refresh));
            }
          }
          final members = _filter == '我的下属'
              ? membersSnapshot.data ?? <SubordinateTaskSummary>[]
              : <SubordinateTaskSummary>[];
          final subordinateIds = members.map((item) => item.userId).toSet();
          return FutureBuilder<List<WorkLog>>(future: _future, builder: (context, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return ErrorPanel(error: s.error!, onRetry: () => setState(_refresh));
        final me = widget.app.user!;
        final authorized = s.data ?? [];
        final departments = authorized.map(_dept).toSet().toList()..sort();
        final visible = filterWorkLogs(
          authorized: authorized,
          viewerId: me.id,
          mode: _filter,
          selectedDepartment: _department,
          subordinateIds: subordinateIds,
          selectedSubordinateId: _selectedSubordinateId,
          search: _search.text,
        );
        final groups = <String, Map<String, List<WorkLog>>>{};
        for (final log in visible) {groups.putIfAbsent(_dept(log), () => {}).putIfAbsent(_team(log), () => []).add(log);}
        return RefreshIndicator(onRefresh: () async {setState(_refresh); await _future;}, child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 115), children: [
          if (_filter == '部门日志') ...[
            const Text('部门筛选', style: TextStyle(color: Palette.deep, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _chip('全部部门', _department == null, () => setState(() => _department = null)),
              ...departments.map((d) => _chip(d, _department == d, () => setState(() => _department = d))),
            ])), const SizedBox(height: 16),
          ],
          if (_filter == '我的下属') ...[
            const Text('下属筛选', style: TextStyle(color: Palette.deep,
              fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (members.isEmpty)
              const Padding(padding: EdgeInsets.only(bottom: 12),
                child: Text('暂无可查看的下属信息',
                  style: TextStyle(color: Palette.muted, fontSize: 12)))
            else
              SingleChildScrollView(scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _chip('全部下属', _selectedSubordinateId == null,
                    () => setState(() => _selectedSubordinateId = null)),
                  ...members.map((member) => _chip(member.name,
                    _selectedSubordinateId == member.userId,
                    () => setState(() => _selectedSubordinateId = member.userId))),
                ])),
            const SizedBox(height: 15),
          ],
          if (groups.isEmpty) const EmptyPanel(title: '暂无日志', subtitle: '当前筛选范围没有可查看的日志'),
          for (final dept in groups.keys) ...[
            Row(children: [const Icon(Icons.apartment_rounded, color: Palette.primary, size: 18), const SizedBox(width: 6), Expanded(child: Text(dept, style: const TextStyle(color: Palette.deep, fontSize: 17, fontWeight: FontWeight.w900))),
              Text('${groups[dept]!.values.fold<int>(0, (n, list) => n + list.length)} 条', style: const TextStyle(color: Palette.muted))]),
            const SizedBox(height: 9),
            for (final team in groups[dept]!.keys) ...[
              Padding(padding: const EdgeInsets.only(left: 3, bottom: 8, top: 5), child: Text('●  $team', style: const TextStyle(color: Palette.primary, fontWeight: FontWeight.w800, fontSize: 12))),
              ...groups[dept]![team]!.map(_logTile),
            ], const SizedBox(height: 14),
          ],
        ]));
          });
        },
      )),
    ]),
    floatingActionButton: widget.app.user!.canWriteLog ? FloatingActionButton.extended(onPressed: _write, icon: const Icon(Icons.edit_note_rounded), label: const Text('写 / 编辑日志')) : null,
  );
  Widget _chip(String text, bool chosen, VoidCallback tap) => Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(
    selected: chosen, label: Text(text), showCheckmark: false, onSelected: (_) => tap(), selectedColor: Palette.sage, backgroundColor: Colors.white,
    labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: chosen ? Palette.deep : Palette.muted), side: const BorderSide(color: Palette.divider),
  ));
  Widget _logTile(WorkLog l) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(12), child: ListTile(
    onTap: () async {await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LogDetailPage(app: widget.app, log: l))); if (mounted) setState(_refresh);},
    contentPadding: const EdgeInsets.fromLTRB(14, 7, 13, 7),
    leading: CircleAvatar(backgroundColor: Palette.sage, child: Text(l.authorName.isEmpty ? '记' : l.authorName.substring(0, 1), style: const TextStyle(color: Palette.deep, fontWeight: FontWeight.w900))),
    title: Row(children: [Expanded(child: Text(l.authorName, style: const TextStyle(color: Palette.deep, fontWeight: FontWeight.w900))), StatusBadge(status: l.status)]),
    subtitle: Text('${l.logDate}\n${l.content}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.5)), isThreeLine: true,
    trailing: const Icon(Icons.chevron_right_rounded, color: Palette.muted),
  )));
}

class LogEditorPage extends StatefulWidget {
  final AppState app;
  final WorkLog? draft;
  final String? date;
  const LogEditorPage({super.key, required this.app, this.draft, this.date});
  @override State<LogEditorPage> createState() => _LogEditorPageState();
}
class _LogEditorPageState extends State<LogEditorPage> {
  late final TextEditingController controller;
  final FlutterSecureStorage secureDraft = const FlutterSecureStorage();
  Timer? autosave;
  bool saving = false;
  String get selectedDay => widget.date ?? widget.draft?.logDate ?? todayChina;
  String get draftKey => 'pandora_unsent_${widget.app.user!.id}_$selectedDay';
  @override void initState() {
    super.initState();
    controller = TextEditingController(text: widget.draft?.content ?? '');
    if (widget.draft == null) _restoreDraft();
    controller.addListener(_scheduleDraft);
  }
  Future<void> _restoreDraft() async {
    try {
      final saved = await secureDraft.read(key: draftKey);
      if (mounted && saved != null && controller.text.isEmpty) controller.text = saved;
    } catch (_) { /* Local recovery is best effort. */ }
  }
  void _scheduleDraft() {
    autosave?.cancel();
    final text = controller.text;
    autosave = Timer(const Duration(milliseconds: 650), () async {
      try {
        if (text.trim().isEmpty) {await secureDraft.delete(key: draftKey);}
        else {await secureDraft.write(key: draftKey, value: text);}
      } catch (_) { /* Server save will still report actual result. */ }
    });
  }
  @override void dispose() {autosave?.cancel(); controller.dispose(); super.dispose();}
  Future<void> _save(bool submit) async {
    if (saving) return;
    if (controller.text.trim().isEmpty) {toast(context, '日志内容不能为空'); return;}
    setState(() => saving = true);
    try {
      final draft = await widget.app.repo.saveLog(controller.text.trim(), id: widget.draft?.id, date: selectedDay);
      if (submit && !(widget.draft?.submitted ?? false)) await widget.app.repo.submitLog(draft.id);
      autosave?.cancel();
      try {await secureDraft.delete(key: draftKey);} catch (_) {}
      if (!mounted) return;
      toast(context, widget.draft?.submitted == true ? '日志修改已保存' : submit ? '日志提交成功' : '草稿保存成功'); Navigator.pop(context, true);
    } catch (e) {if (mounted) toast(context, '$e');}
    finally {if (mounted) setState(() => saving = false);}
  }
  Future<void> _confirm() async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('正式提交日志？'), content: const Text('每个日期仍只保留一条日志；该日期允许在近三天内再次编辑（需后端支持）。'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认提交'))]));
    if (yes == true) await _save(true);
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('我的日志')), body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Palette.sage, borderRadius: BorderRadius.circular(8)), child: Text('日志日期：$selectedDay  ·  近三天可编辑\n旧版后端可能仍限制补写和已提交编辑', style: const TextStyle(color: Palette.deep, height: 1.6, fontWeight: FontWeight.w700))),
    const SizedBox(height: 17), const Text('日志内容', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Palette.deep)), const SizedBox(height: 10),
    Expanded(child: TextField(controller: controller, expands: true, maxLines: null, minLines: null, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(hintText: '记录当日进展、遇到的问题、后续计划……'))),
    const SizedBox(height: 13), if (widget.draft?.submitted == true) FilledButton(onPressed: saving ? null : () => _save(false), child: const Text('保存修改')) else Row(children: [Expanded(child: OutlinedButton(onPressed: saving ? null : () => _save(false), child: const Text('保存草稿'))), const SizedBox(width: 11), Expanded(child: FilledButton(onPressed: saving ? null : _confirm, child: const Text('正式提交')))]),
  ]))));
}
