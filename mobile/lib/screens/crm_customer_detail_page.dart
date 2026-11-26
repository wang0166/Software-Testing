import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../crm/crm_models.dart';

class CrmCustomerDetailPage extends StatefulWidget {
  final AppState app;
  final CrmCustomer customer;
  const CrmCustomerDetailPage({super.key, required this.app,
    required this.customer});
  @override State<CrmCustomerDetailPage> createState() => _CrmCustomerDetailPageState();
}
class _CrmCustomerDetailPageState extends State<CrmCustomerDetailPage> {
  late Future<List<Object>> _future;
  @override void initState() { super.initState(); _reload(); }
  void _reload() {
    final user = widget.app.user!;
    _future = Future.wait<Object>([
      widget.app.crmGateway.benefits(user, widget.customer.id),
      widget.app.crmGateway.customerActivities(user, widget.customer.id),
    ]);
  }
  Future<void> _refresh() async {
    setState(_reload);
    try { await _future; } catch (_) { /* FutureBuilder displays the error. */ }
  }
  Future<void> _redeem(CrmBenefit benefit) async {
    if (benefit.remaining == 0) { return; }
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认核销权益？'),
        content: Text('将为「${widget.customer.name}」核销一次「${benefit.title}」。\n此操作需要服务端保存核销流水。'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认核销'))],
      ));
    if (confirmed != true || !mounted) { return; }
    try {
      await widget.app.crmGateway.consumeBenefit(widget.app.user!, benefit.id);
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('权益核销成功')));
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('核销失败：$e')));
    }
  }

  Future<void> _addActivity() async {
    final title = TextEditingController(), note = TextEditingController();
    final form = GlobalKey<FormState>();
    String kind = 'SERVICE', status = 'PLANNED';
    DateTime day = DateTime.now();
    final selected = <int>{widget.app.user!.id};
    var staff = <EmployeeArchive>[];
    if (CrmAccess.forUser(widget.app.user).employees) {
      try {
        final page = await widget.app.crmGateway.employees(widget.app.user!, size: 50);
        staff = page.items.where((e) => e.active).toList();
      } catch (_) { /* Staff list remains optional. */ }
    }
    if (!mounted) {title.dispose(); note.dispose(); return;}
    try {
      final data = await showDialog<Map<String, dynamic>>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
          title: const Text('新增业务参与记录'),
          content: SizedBox(width: (MediaQuery.sizeOf(context).width - 128).clamp(180.0, 380.0), child: SingleChildScrollView(
            child: Form(key: form, child: Column(
              mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: title, maxLength: 100,
                decoration: const InputDecoration(labelText: '业务名称 *'),
                validator: (v) => (v?.trim().length ?? 0) < 2 ? '请填写业务名称' : null),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(initialValue: kind, isExpanded: true,
                decoration: const InputDecoration(labelText: '业务类型'),
                items: ['MALL', 'PERFORMANCE', 'BANQUET', 'VISIT', 'SALON', 'SERVICE']
                  .map((e) => DropdownMenuItem(value: e,
                    child: Text(crmActivityKindLabel(e)))).toList(),
                onChanged: (v) => update(() => kind = v ?? kind)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(initialValue: status, isExpanded: true,
                decoration: const InputDecoration(labelText: '服务进度'),
                items: ['PLANNED', 'IN_PROGRESS', 'COMPLETED']
                  .map((e) => DropdownMenuItem(value: e,
                    child: Text(crmStatusLabel(e)))).toList(),
                onChanged: (v) => update(() => status = v ?? status)),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: () async {
                final picked = await showDatePicker(context: ctx,
                  initialDate: day,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (picked != null) { update(() => day = picked); }
              }, icon: const Icon(Icons.event_outlined),
                label: Text('${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}')),
              if (staff.isNotEmpty) ...[
                const Align(alignment: Alignment.centerLeft,
                  child: Text('参与人员（可多选）',
                    style: TextStyle(fontWeight: FontWeight.w700))),
                for (final employee in staff)
                  CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero,
                    title: Text('${employee.name} · ${employee.department}',
                      style: const TextStyle(fontSize: 12)),
                    value: selected.contains(employee.id),
                    onChanged: (v) => update(() {
                      if (v == true) { selected.add(employee.id); }
                      else { selected.remove(employee.id); }
                    })),
              ],
              TextFormField(controller: note, maxLength: 200, maxLines: 2,
                decoration: const InputDecoration(labelText: '服务备注（选填）')),
            ])))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('取消')),
            FilledButton(onPressed: () {
              if (form.currentState?.validate() != true) { return; }
              final date = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              Navigator.pop(ctx, <String, dynamic>{'title': title.text.trim(),
                'kind': kind, 'status': status, 'date': date,
                'note': note.text.trim(), 'participants': selected.toList()});
            }, child: const Text('保存记录'))],
        )));
      if (data == null || !mounted) { return; }
      try {
        await widget.app.crmGateway.addActivity(widget.app.user!,
          customerId: widget.customer.id, kind: data['kind'] as String,
          title: data['title'] as String, date: data['date'] as String,
          status: data['status'] as String,
          participantIds: (data['participants'] as List<int>),
          note: data['note'] as String);
        if (!mounted) { return; }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('业务记录已保存')));
        await _refresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('保存失败：$e')));
      }
    } finally {title.dispose(); note.dispose();}
  }

  String _activityDetails(CrmActivity a) {
    final participants = a.participantNames.isEmpty
      ? '参与人员 ${a.participantIds.length} 人'
      : '参与人员：${a.participantNames.join('、')}';
    return [
      '${crmActivityKindLabel(a.kind)} · ${a.date}',
      '${crmStatusLabel(a.status)} · 负责人 ${a.ownerName}',
      participants,
      if (a.note.isNotEmpty) a.note,
    ].join('\n');
  }

  Widget _section(String title, Widget content) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16,
          fontWeight: FontWeight.w800, color: Palette.deep)),
        const SizedBox(height: 9), content,
      ])),
  );

  @override Widget build(BuildContext context) {
    final c = widget.customer;
    final access = CrmAccess.forUser(widget.app.user);
    return Scaffold(appBar: AppBar(title: const Text('客户 360° 档案')),
      body: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<List<Object>>(future: _future,
          builder: (context, snap) {
            final benefits = snap.hasData ? (snap.data![0] as List<CrmBenefit>) : <CrmBenefit>[];
            final activities = snap.hasData ? (snap.data![1] as List<CrmActivity>) : <CrmActivity>[];
            return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
              Text(c.name, style: const TextStyle(fontSize: 23,
                fontWeight: FontWeight.w900, color: Palette.deep)),
              const SizedBox(height: 4),
              Text('${c.id} · ${c.isCompany ? '企业客户' : '个人客户'} · ${c.business}',
                style: const TextStyle(color: Palette.muted)),
              const SizedBox(height: 14),
              _section('客户基础信息', Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('会员级别：${c.memberTier}'),
                  Text('会员到期：${c.memberExpiresAt.isEmpty ? '未设置' : c.memberExpiresAt}'),
                  if (c.annualCardLimit > 0)
                    Text('年卡使用：${c.annualCardUsed} / ${c.annualCardLimit} 次'),
                  Text('服务负责人：${c.ownerName}'),
                  if (c.linkedMallMemberId.isNotEmpty)
                    Text('商城关联会员号：${c.linkedMallMemberId}'),
                  if (c.linkedTicketCardId.isNotEmpty)
                    Text('演出年卡关联号：${c.linkedTicketCardId}'),
                  Text('联系方式：${c.maskedContact}'),
                  Text('备注：${c.remark.isEmpty ? '暂无' : c.remark}'),
                ])),
              if (snap.connectionState != ConnectionState.done)
                const Center(child: Padding(padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator())),
              if (snap.hasError) _section('业务数据暂不可用', Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${snap.error}', style: const TextStyle(color: Palette.coral)),
                  TextButton(onPressed: _refresh, child: const Text('重试')),
                ])),
              if (snap.hasData) ...[
                _section('会员权益与履约', benefits.isEmpty
                  ? const Text('暂未配置权益', style: TextStyle(color: Palette.muted))
                  : Column(children: [for (final b in benefits) ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(b.title),
                    subtitle: Text('已用 ${b.used} / ${b.total} · ${crmStatusLabel(b.serviceStatus)}'),
                    trailing: access.editCustomers && b.remaining > 0
                      ? TextButton(onPressed: () => _redeem(b), child: const Text('登记使用'))
                      : Text('剩余 ${b.remaining}',
                        style: const TextStyle(color: Palette.muted)),
                  )])),
                _section('跨业务服务与参与记录', Column(children: [
                  if (access.editCustomers) Align(alignment: Alignment.centerRight,
                    child: TextButton.icon(key: const Key('crm_add_activity'),
                      onPressed: _addActivity, icon: const Icon(Icons.add),
                      label: const Text('新增业务记录'))),
                  if (activities.isEmpty) const Text('暂无业务记录',
                    style: TextStyle(color: Palette.muted)),
                  for (final a in activities) ListTile(contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, color: Palette.primary),
                    title: Text(a.title),
                    subtitle: Text(_activityDetails(a)),
                    isThreeLine: true,
                  ),
                ])),
              ],
              const SizedBox(height: 8),
              const Text('金额、身份证明及合同原件不得保存在移动端明文缓存；'
                '敏感信息由后端按权限返回。',
                style: TextStyle(color: Palette.muted, fontSize: 11)),
            ]);
          },
        ),
      ),
    );
  }
}
