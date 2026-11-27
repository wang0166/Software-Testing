import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../crm/crm_models.dart';

class EmployeeArchivePage extends StatefulWidget {
  final AppState app;
  const EmployeeArchivePage({super.key, required this.app});
  @override State<EmployeeArchivePage> createState() => _EmployeeArchivePageState();
}
class _EmployeeArchivePageState extends State<EmployeeArchivePage> {
  final _search = TextEditingController();
  final List<EmployeeArchive> _items = [];
  String _keyword = '';
  bool _onlyExpiring = false, _loading = false, _hasMore = true;
  String? _error;
  int _page = 0, _total = 0, _epoch = 0;
  @override void initState() {super.initState(); _fetch(reset: true);}
  @override void dispose() {_epoch++; _search.dispose(); super.dispose();}

  Future<void> _fetch({bool reset = false}) async {
    if (_loading && !reset) { return; }
    if (!reset && !_hasMore) { return; }
    final current = reset ? ++_epoch : _epoch;
    final next = reset ? 1 : _page + 1;
    setState(() {
      if (reset) { _items.clear(); _page = 0; _total = 0; _hasMore = true; }
      _loading = true; _error = null;
    });
    try {
      final page = await widget.app.crmGateway.employees(widget.app.user!,
        search: _keyword, expiringOnly: _onlyExpiring, page: next, size: 20);
      if (!mounted || current != _epoch) { return; }
      setState(() {
        _items.addAll(page.items); _page = next;
        _total = page.total; _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted && current == _epoch) { setState(() => _error = e.toString()); }
    } finally {
      if (mounted && current == _epoch) { setState(() => _loading = false); }
    }
  }

  Future<void> _create() async {
    final saved = await showDialog<bool>(context: context,
      builder: (_) => _CreateEmployeeDialog(app: widget.app));
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('员工档案已保存，合同材料仍待归档')));
      await _fetch(reset: true);
    }
  }

  Widget _header(CrmAccess access) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('人员与业务档案', style: TextStyle(color: Palette.deep,
        fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('岗位职责 · 业务参与 · 合同到期预警',
        style: TextStyle(color: Palette.muted, fontSize: 12)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) { _keyword = v.trim(); _fetch(reset: true); },
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
            hintText: '搜索员工、部门或职责',
            suffixIcon: IconButton(tooltip: '查询',
              icon: const Icon(Icons.arrow_forward),
              onPressed: () { _keyword = _search.text.trim(); _fetch(reset: true); })))),
        if (access.editEmployees) ...[
          const SizedBox(width: 8),
          IconButton.filled(key: const Key('hr_add_employee'),
            tooltip: '新增员工档案', onPressed: _create,
            icon: const Icon(Icons.person_add_outlined)),
        ],
      ]),
      if (access.contractAlerts) Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: FilterChip(key: const Key('hr_contract_expiring_filter'),
          label: const Text('仅看 30 天内到期合同'),
          selected: _onlyExpiring,
          onSelected: (v) { _onlyExpiring = v; _fetch(reset: true); }),
      ),
      Padding(padding: const EdgeInsets.only(bottom: 9),
        child: Text('符合筛选的员工 $_total 人 · 每次加载 20 人',
          style: const TextStyle(fontSize: 11, color: Palette.muted))),
    ]);

  Widget _row(EmployeeArchive e, CrmAccess access) {
    final days = e.daysToContractEnd(DateTime.now());
    final contractText = days == null ? '未录入到期日'
      : days < 0 ? '合同已到期' : days <= 30 ? '合同 $days 天后到期' : '合同有效';
    return Card(margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(contentPadding: const EdgeInsets.all(13),
        leading: CircleAvatar(backgroundColor: e.active ? Palette.sage : Palette.lavender,
          child: const Icon(Icons.badge_outlined, color: Palette.deep)),
        title: Row(children: [
          Flexible(child: Text(e.name, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800,
              color: Palette.deep))),
          if (!e.active) const Padding(padding: EdgeInsets.only(left: 8),
            child: Text('已停用', style: TextStyle(color: Palette.muted,
              fontSize: 11))),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${e.department} · ${e.duty}', maxLines: 2,
              overflow: TextOverflow.ellipsis),
            if (access.contractAlerts) Text(contractText, style: TextStyle(
              color: days != null && days <= 30 ? Palette.coral : Palette.muted,
              fontSize: 12)),
          ]),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => _EmployeeActivityDetail(app: widget.app,
            employee: e, access: access))),
      ));
  }

  @override Widget build(BuildContext context) {
    final access = CrmAccess.forUser(widget.app.user);
    if (!access.employees) { return const Center(child: Text('当前账号没有人员档案访问权限')); }
    return RefreshIndicator(onRefresh: () => _fetch(reset: true),
      child: ListView.builder(key: const Key('hr_employee_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        itemCount: _items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) { return _header(access); }
          if (index <= _items.length) { return _row(_items[index - 1], access); }
          if (_loading) { return const Center(child: Padding(
            padding: EdgeInsets.all(25), child: CircularProgressIndicator())); }
          if (_error != null) { return Column(children: [
            Text('人员数据不可用：$_error',
              style: const TextStyle(color: Palette.coral)),
            TextButton(onPressed: () => _fetch(reset: _page == 0),
              child: const Text('重试')),
          ]); }
          if (_items.isEmpty) { return const Center(child: Padding(
            padding: EdgeInsets.all(28), child: Text('暂无符合条件的员工档案'))); }
          if (!_hasMore) { return const Center(child: Padding(
            padding: EdgeInsets.all(15), child: Text('已显示全部结果'))); }
          return TextButton(onPressed: () => _fetch(), child: const Text('加载更多员工'));
        }));
  }
}

class _CreateEmployeeDialog extends StatefulWidget {
  final AppState app;
  const _CreateEmployeeDialog({required this.app});
  @override State<_CreateEmployeeDialog> createState() => _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends State<_CreateEmployeeDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dept = TextEditingController();
  final _duty = TextEditingController();
  DateTime? _end;
  bool _saving = false;
  String? _error;

  @override void dispose() {
    _name.dispose(); _dept.dispose(); _duty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _form.currentState?.validate() != true) return;
    setState(() { _saving = true; _error = null; });
    final date = _end == null ? '' :
      '${_end!.year}-${_end!.month.toString().padLeft(2, '0')}-${_end!.day.toString().padLeft(2, '0')}';
    try {
      await widget.app.crmGateway.createEmployee(widget.app.user!,
        name: _name.text.trim(), department: _dept.text.trim(),
        duty: _duty.text.trim(), contractEnd: date);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('新增员工档案'),
    content: SizedBox(width: (MediaQuery.sizeOf(context).width - 128).clamp(180.0, 380.0),
      child: SingleChildScrollView(child: Form(key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(key: const Key('hr_employee_name'), controller: _name, maxLength: 40,
            decoration: const InputDecoration(labelText: '员工姓名 *'),
            validator: (value) => (value?.trim().length ?? 0) < 2 ? '请填写员工姓名' : null),
          TextFormField(controller: _dept, maxLength: 40,
            decoration: const InputDecoration(labelText: '所属部门 *'),
            validator: (value) => (value?.trim().isEmpty ?? true) ? '请填写部门' : null),
          TextFormField(controller: _duty, maxLength: 120, maxLines: 2,
            decoration: const InputDecoration(labelText: '岗位职责 *'),
            validator: (value) => (value?.trim().isEmpty ?? true) ? '请填写职责' : null),
          OutlinedButton.icon(onPressed: _saving ? null : () async {
            final picked = await showDatePicker(context: context,
              initialDate: _end ?? DateTime.now(),
              firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (picked != null && mounted) setState(() => _end = picked);
          }, icon: const Icon(Icons.event),
            label: Text(_end == null ? '选择合同到期日（选填）' :
              '${_end!.year}-${_end!.month.toString().padLeft(2, '0')}-${_end!.day.toString().padLeft(2, '0')}')),
          if (_error != null) Text(_error!, style: const TextStyle(color: Palette.coral)),
          const SizedBox(height: 8),
          const Text('此处仅创建档案元数据；劳动合同扫描件需在后端文件系统安全归档。',
            style: TextStyle(fontSize: 11, color: Palette.muted)),
        ])))),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('取消')),
      FilledButton(key: const Key('hr_employee_save'), onPressed: _saving ? null : _save,
        child: Text(_saving ? '保存中…' : '保存档案')),
    ],
  );
}

class _EmployeeActivityDetail extends StatelessWidget {
  final AppState app;
  final EmployeeArchive employee;
  final CrmAccess access;
  const _EmployeeActivityDetail({required this.app,
    required this.employee, required this.access});
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('员工业务参与档案')),
      body: FutureBuilder<List<CrmActivity>>(
        future: app.crmGateway.employeeActivities(app.user!, employee.id),
        builder: (context, snap) => ListView(
          padding: const EdgeInsets.all(16), children: [
            Card(child: Padding(padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.name, style: const TextStyle(fontSize: 21,
                    fontWeight: FontWeight.w800, color: Palette.deep)),
                  const SizedBox(height: 8),
                  Text('部门：${employee.department}'),
                  Text('岗位职责：${employee.duty}'),
                  Text('账号状态：${employee.active ? '在职' : '已停用（历史档案保留）'}'),
                  if (access.contractAlerts) ...[
                    const Divider(),
                    Text('合同到期日：${employee.contractEnd.isEmpty ? '未录入' : employee.contractEnd}'),
                    if (access.contracts) ...[
                      Text('合同材料：${employee.contractArchiveStatus == 'ARCHIVED' ? '已登记归档' : '待归档'}'),
                      const Text('仅展示归档状态，合同原件需通过后端授权下载。',
                        style: TextStyle(fontSize: 11, color: Palette.muted)),
                    ],
                  ],
                ]))),
            const SizedBox(height: 18),
            const Text('参与过的业务', style: TextStyle(fontSize: 17,
              fontWeight: FontWeight.w800, color: Palette.deep)),
            const SizedBox(height: 8),
            if (snap.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (snap.hasError)
              Text('业务记录暂不可用：${snap.error}',
                style: const TextStyle(color: Palette.coral))
            else if ((snap.data ?? []).isEmpty)
              const Text('暂无有权限查看的业务参与记录',
                style: TextStyle(color: Palette.muted))
            else for (final a in snap.data!) Card(child: ListTile(
              title: Text(a.title),
              subtitle: Text('${crmActivityKindLabel(a.kind)} · ${a.date}\n'
                '${crmStatusLabel(a.status)} · 负责人 ${a.ownerName}'))),
          ]),
      ),
    );
  }
}
