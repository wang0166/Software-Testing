import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
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
  final _search = TextEditingController();
  String _filter = '部门日志';
  String? _department;
  @override void initState() {super.initState(); _refresh();}
  @override void dispose() {_search.dispose(); super.dispose();}
  void _refresh() => _future = widget.app.repo.logs();
  Future<void> _edit(WorkLog? draft) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => LogEditorPage(app: widget.app, draft: draft)));
    if (ok == true && mounted) setState(_refresh);
  }
  Future<void> _write() async {
    try {
      final me = widget.app.user!;
      final logs = await widget.app.repo.logs(date: todayChina);
      if (!mounted) return;
      final own = logs.where((e) => e.authorId == me.id).toList();
      if (own.isNotEmpty && own.first.submitted) {toast(context, '今天日志已提交，无法再次编辑'); return;}
      await _edit(own.isEmpty ? null : own.first);
    } catch (e) {if (mounted) toast(context, '$e');}
  }
  String _dept(WorkLog l) => l.departmentName.isNotEmpty ? l.departmentName : l.departmentId == null ? '未标注部门' : '部门 ${l.departmentId}';
  String _team(WorkLog l) => l.teamName.isNotEmpty ? l.teamName : l.teamId == null ? '部门直属' : '团队 ${l.teamId}';
  @override Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('工作日志', style: TextStyle(color: Palette.deep, fontSize: 29, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4), const Text('按部门 · 团队分层查看权限内日志', style: TextStyle(color: Palette.muted, fontSize: 12)),
        const SizedBox(height: 14), TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: '搜索姓名或日志内容')),
        const SizedBox(height: 12), Row(children: [for (final option in ['部门日志', '我的日志']) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(
          onTap: () => setState(() {_filter = option; _department = null;}), borderRadius: BorderRadius.circular(13), child: Container(alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: _filter == option ? Palette.deep : Colors.white, borderRadius: BorderRadius.circular(13)), child: Text(option, style: TextStyle(color: _filter == option ? Colors.white : Palette.muted, fontWeight: FontWeight.w800))),
        )))]),
      ])),
      Expanded(child: FutureBuilder<List<WorkLog>>(future: _future, builder: (context, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return ErrorPanel(error: s.error!, onRetry: () => setState(_refresh));
        final me = widget.app.user!;
        final authorized = s.data ?? [];
        final departments = authorized.map(_dept).toSet().toList()..sort();
        final visible = authorized.where((l) => (_filter != '我的日志' || l.authorId == me.id) && (_department == null || _dept(l) == _department) &&
          (_search.text.isEmpty || l.authorName.contains(_search.text.trim()) || l.content.contains(_search.text.trim()))).toList();
        final groups = <String, Map<String, List<WorkLog>>>{};
        for (final log in visible) {groups.putIfAbsent(_dept(log), () => {}).putIfAbsent(_team(log), () => []).add(log);}
        return RefreshIndicator(onRefresh: () async {setState(_refresh); await _future;}, child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 115), children: [
          if (_filter == '部门日志') ...[
            const Text('部门筛选', style: TextStyle(color: Palette.deep, fontWeight: FontWeight.w900, fontSize: 12)),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _chip('全部部门', _department == null, () => setState(() => _department = null)),
              ...departments.map((d) => _chip(d, _department == d, () => setState(() => _department = d))),
            ])), const SizedBox(height: 16),
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
      })),
    ]),
    floatingActionButton: widget.app.user!.canWriteLog ? FloatingActionButton.extended(onPressed: _write, icon: const Icon(Icons.edit_note_rounded), label: const Text('写今日日志')) : null,
  );
  Widget _chip(String text, bool chosen, VoidCallback tap) => Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(
    selected: chosen, label: Text(text), showCheckmark: false, onSelected: (_) => tap(), selectedColor: Palette.sage, backgroundColor: Colors.white,
    labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: chosen ? Palette.deep : Palette.muted), side: BorderSide.none,
  ));
  Widget _logTile(WorkLog l) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(19), child: ListTile(
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
  const LogEditorPage({super.key, required this.app, this.draft});
  @override State<LogEditorPage> createState() => _LogEditorPageState();
}
class _LogEditorPageState extends State<LogEditorPage> {
  late final TextEditingController controller;
  final FlutterSecureStorage secureDraft = const FlutterSecureStorage();
  Timer? autosave;
  bool saving = false;
  String get draftKey => 'pandora_unsent_${widget.app.user!.id}_$todayChina';
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
      final draft = await widget.app.repo.saveLog(controller.text.trim(), id: widget.draft?.id);
      if (submit) await widget.app.repo.submitLog(draft.id);
      autosave?.cancel();
      try {await secureDraft.delete(key: draftKey);} catch (_) {}
      if (!mounted) return;
      toast(context, submit ? '日志提交成功' : '草稿保存成功'); Navigator.pop(context, true);
    } catch (e) {if (mounted) toast(context, '$e');}
    finally {if (mounted) setState(() => saving = false);}
  }
  Future<void> _confirm() async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('正式提交日志？'), content: const Text('提交后不可修改，每人每天仅能提交一条。'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认提交'))]));
    if (yes == true) await _save(true);
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('我的日志')), body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Palette.sage, borderRadius: BorderRadius.circular(18)), child: Text('日期：$todayChina   ·   每日 22:00 截止\n支持保存草稿，正式提交后不可更改', style: const TextStyle(color: Palette.deep, height: 1.6, fontWeight: FontWeight.w700))),
    const SizedBox(height: 17), const Text('今日日志', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Palette.deep)), const SizedBox(height: 10),
    Expanded(child: TextField(controller: controller, expands: true, maxLines: null, minLines: null, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(hintText: '记录今天的工作进展、遇到的问题和明日计划……'))),
    const SizedBox(height: 13), Row(children: [Expanded(child: OutlinedButton(onPressed: saving ? null : () => _save(false), child: const Text('保存草稿'))), const SizedBox(width: 11), Expanded(child: FilledButton(onPressed: saving ? null : _confirm, child: const Text('正式提交')))]),
  ]))));
}
