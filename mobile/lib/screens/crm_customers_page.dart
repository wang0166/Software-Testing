import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../crm/crm_models.dart';
import 'crm_customer_detail_page.dart';

/// V2 CRM entry. Paged lists, explicit loading/error states, no client-side PII cache.
class CrmCustomersPage extends StatefulWidget {
  final AppState app;
  const CrmCustomersPage({super.key, required this.app});
  @override State<CrmCustomersPage> createState() => _CrmCustomersPageState();
}
class _CrmCustomersPageState extends State<CrmCustomersPage> {
  final _search = TextEditingController();
  Future<CrmRevenueSummary>? _revenueFuture;
  final List<CrmCustomer> _items = [];
  String _keyword = '', _category = '', _business = '';
  bool _loading = false, _hasMore = true;
  int _page = 0, _total = 0, _epoch = 0;
  String? _error;
  static const _businesses = ['全部业务', '会员服务', '线上商城', '演出活动',
    '高端私宴', '企业参访', '线下沙龙'];
  @override void initState() {
    super.initState();
    if (CrmAccess.forUser(widget.app.user).revenue) {
      _revenueFuture = widget.app.crmGateway.revenueSummary(widget.app.user!);
    }
    _fetch(reset: true);
  }
  @override void dispose() {_epoch++; _search.dispose(); super.dispose();}

  Future<void> _fetch({bool reset = false}) async {
    if (_loading && !reset) { return; }
    if (!reset && !_hasMore) { return; }
    final current = reset ? ++_epoch : _epoch;
    final next = reset ? 1 : _page + 1;
    setState(() {
      if (reset) { _items.clear(); _page = 0; _total = 0; _hasMore = true; }
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.app.crmGateway.customers(widget.app.user!,
        search: _keyword, category: _category, business: _business,
        page: next, size: 20);
      if (!mounted || current != _epoch) { return; }
      setState(() {
        _items.addAll(data.items);
        _total = data.total;
        _page = next;
        _hasMore = data.hasMore;
      });
    } catch (e) {
      if (mounted && current == _epoch) { setState(() => _error = e.toString()); }
    } finally {
      if (mounted && current == _epoch) { setState(() => _loading = false); }
    }
  }

  Future<void> _create() async {
    final values = await showDialog<Map<String, String>>(
      context: context, builder: (_) => const _CreateCustomerDialog());
    if (values == null || !mounted) return;
    try {
      await widget.app.crmGateway.createCustomer(widget.app.user!,
        name: values['name']!, category: values['category']!,
        business: values['business']!, tier: values['tier']!,
        remark: values['remark']!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('客户档案已保存')));
      await _fetch(reset: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('保存失败：$e')));
    }
  }

  Widget _filterChip(String title, String value) => Padding(
    padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(title),
      selected: _category == value,
      onSelected: (_) { _category = value; _fetch(reset: true); }),
  );
  Widget _header(CrmAccess access) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('客户与会员', style: TextStyle(fontSize: 23,
        fontWeight: FontWeight.w900, color: Palette.deep)),
      const SizedBox(height: 5),
      const Text('一人一档 · 会员权益 · 跨业务服务轨迹',
        style: TextStyle(color: Palette.muted, fontSize: 12)),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(
        color: Palette.lavender, borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
          const Icon(Icons.security_outlined, color: Palette.deep),
          const SizedBox(width: 9),
          Expanded(child: Text(
            pandoraDemo ? '演示数据，仅模拟业务；不会上传客户隐私' :
              '真实服务模式：仅展示后端授权返回的数据',
            style: const TextStyle(fontSize: 12, color: Palette.deep))),
        ])),
      const SizedBox(height: 12),
      if (_revenueFuture != null) FutureBuilder<CrmRevenueSummary>(
        future: _revenueFuture, builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(12),
              child: LinearProgressIndicator());
          }
          if (snap.hasError) { return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('营收汇总暂不可用：${snap.error}',
              style: const TextStyle(color: Palette.coral, fontSize: 12))); }
          final revenue = snap.data!;
          return Card(margin: const EdgeInsets.only(bottom: 12),
            child: Padding(padding: const EdgeInsets.all(15), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('授权营收概览 · ${revenue.month}',
                  style: const TextStyle(color: Palette.deep,
                    fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(CrmRevenueSummary.amountLabel(revenue.totalAmountFen),
                  style: const TextStyle(color: Palette.primary,
                    fontSize: 23, fontWeight: FontWeight.w900)),
                Text('订单/业务 ${revenue.orderCount} 笔 · ${pandoraDemo ? '演示金额' : '服务端数据'}',
                  style: const TextStyle(fontSize: 11, color: Palette.muted)),
                const Divider(),
                for (final e in revenue.byBusinessFen.entries) Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [Expanded(child: Text(e.key)),
                    Text(CrmRevenueSummary.amountLabel(e.value))])),
              ])));
        }),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (text) { _keyword = text.trim(); _fetch(reset: true); },
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
            hintText: '搜索名称、编号或会员等级',
            suffixIcon: IconButton(tooltip: '查询', icon: const Icon(Icons.arrow_forward),
              onPressed: () { _keyword = _search.text.trim(); _fetch(reset: true); })))),
        if (access.editCustomers) ...[
          const SizedBox(width: 8),
          IconButton.filled(key: const Key('crm_add_customer'),
            tooltip: '新增客户', onPressed: _create,
            icon: const Icon(Icons.person_add_alt_1_outlined)),
        ],
      ]),
      const SizedBox(height: 9),
      SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: Row(children: [
          _filterChip('全部', ''), _filterChip('个人会员', 'PERSON'),
          _filterChip('企业客户', 'COMPANY'),
        ])),
      Row(children: [
        const Text('业务类型', style: TextStyle(fontSize: 12, color: Palette.muted)),
        const SizedBox(width: 8),
        Expanded(child: DropdownButton<String>(value: _business,
          isExpanded: true, underline: const SizedBox.shrink(),
          items: _businesses.map((v) => DropdownMenuItem(
            value: v == '全部业务' ? '' : v, child: Text(v,
              style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) { _business = v ?? ''; _fetch(reset: true); })),
      ]),
      Text('符合筛选的客户 $_total 条 · 每次加载 20 条',
        style: const TextStyle(color: Palette.muted, fontSize: 11)),
      const SizedBox(height: 12),
    ]);
  Widget _row(CrmCustomer c) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(contentPadding: const EdgeInsets.all(13),
      leading: CircleAvatar(backgroundColor: c.isCompany ? Palette.lavender : Palette.rose,
        child: Icon(c.isCompany ? Icons.apartment : Icons.person_outline,
          color: Palette.primary)),
      title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Palette.deep, fontWeight: FontWeight.w800)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 5),
        Text('${c.business} · ${c.memberTier}', maxLines: 1,
          overflow: TextOverflow.ellipsis),
        Text('编号 ${c.id}  ·  负责人 ${c.ownerName}', maxLines: 1,
          overflow: TextOverflow.ellipsis),
        if (c.annualCardLimit > 0) Text('年卡剩余 ${c.annualCardRemaining} / ${c.annualCardLimit} 次',
          style: const TextStyle(color: Palette.primary, fontSize: 12)),
      ]), trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => CrmCustomerDetailPage(app: widget.app, customer: c)));
        if (mounted) { _fetch(reset: true); }
      }),
  );

  @override Widget build(BuildContext context) {
    final access = CrmAccess.forUser(widget.app.user);
    if (!access.customers) { return const Center(child: Padding(
      padding: EdgeInsets.all(30), child: Text('当前账号没有客户档案访问权限'))); }
    return RefreshIndicator(onRefresh: () => _fetch(reset: true),
      child: ListView.builder(
        key: const Key('crm_customer_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        itemCount: _items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) { return _header(access); }
          if (index <= _items.length) { return _row(_items[index - 1]); }
          if (_loading) { return const Padding(padding: EdgeInsets.all(25),
            child: Center(child: CircularProgressIndicator())); }
          if (_error != null) { return Column(children: [
            Text('客户列表暂不可用：$_error', textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.coral)),
            TextButton(onPressed: () => _fetch(reset: _page == 0),
              child: const Text('重试')),
          ]); }
          if (_items.isEmpty) { return const Center(child: Padding(
            padding: EdgeInsets.all(28), child: Text('暂无符合条件的客户'))); }
          if (!_hasMore) { return const Center(child: Padding(
            padding: EdgeInsets.all(16), child: Text('已显示全部结果'))); }
          return TextButton(onPressed: () => _fetch(), child: const Text('加载更多客户'));
        },
      ));
  }
}

class _CreateCustomerDialog extends StatefulWidget {
  const _CreateCustomerDialog();
  @override State<_CreateCustomerDialog> createState() => _CreateCustomerDialogState();
}

class _CreateCustomerDialogState extends State<_CreateCustomerDialog> {
  final _name = TextEditingController();
  final _remark = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _category = 'PERSON', _business = '会员服务', _tier = '普通客户';

  @override void dispose() {
    _name.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('新增客户档案'),
    content: SizedBox(
      width: (MediaQuery.sizeOf(context).width - 128).clamp(180.0, 380.0),
      child: SingleChildScrollView(child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(key: const Key('crm_customer_name'), controller: _name,
            maxLength: 60, decoration: const InputDecoration(labelText: '客户名称 *'),
            validator: (value) => (value?.trim().length ?? 0) < 2 ? '至少填写两个字符' : null),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(initialValue: _category, isExpanded: true,
            decoration: const InputDecoration(labelText: '客户类型'),
            items: const [DropdownMenuItem(value: 'PERSON', child: Text('个人客户')),
              DropdownMenuItem(value: 'COMPANY', child: Text('企业客户'))],
            onChanged: (value) => setState(() => _category = value ?? _category)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: _business, isExpanded: true,
            decoration: const InputDecoration(labelText: '主要业务'),
            items: _CrmCustomersPageState._businesses.skip(1).map((value) =>
              DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) => setState(() => _business = value ?? _business)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: _tier, isExpanded: true,
            decoration: const InputDecoration(labelText: '客户/会员等级'),
            items: ['普通客户', '银卡会员', '金卡会员', '尊享会员', '演出年卡', '企业客户']
              .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) => setState(() => _tier = value ?? _tier)),
          const SizedBox(height: 12),
          TextFormField(key: const Key('crm_customer_remark'), controller: _remark,
            maxLines: 2, maxLength: 200,
            decoration: const InputDecoration(labelText: '客户备注（选填）')),
          const Text('敏感联系方式、订单及合同材料须由授权后端安全保存。',
            style: TextStyle(fontSize: 11, color: Palette.muted)),
        ]),
      )),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      FilledButton(key: const Key('crm_customer_save'), onPressed: () {
        if (_form.currentState?.validate() != true) return;
        Navigator.pop(context, {'name': _name.text.trim(), 'category': _category,
          'business': _business, 'tier': _tier, 'remark': _remark.text.trim()});
      }, child: const Text('保存档案')),
    ],
  );
}
