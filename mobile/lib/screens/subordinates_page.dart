import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/business.dart';
import '../widgets/subordinate_task_row.dart';
import 'subordinate_detail_page.dart';
import 'subordinate_task_detail_page.dart';

/// All manager-visible subordinates; each issue badge shows unresolved problems,
/// rather than all historical reports or all overdue tasks.
class SubordinatesPage extends StatefulWidget {
  final AppState app;
  final VoidCallback? onIssueChanged;
  const SubordinatesPage({super.key,required this.app,this.onIssueChanged});
  @override State<SubordinatesPage> createState()=>_SubordinatesPageState();
}

class _SubordinatesPageState extends State<SubordinatesPage> {
  late Future<List<SubordinateTaskSummary>> _future;
  final _search = TextEditingController();
  String _department = '全部部门';
  String _team = '全部团队';
  String _role = '全部职务';
  int _shown = 20;
  @override void dispose() { _search.dispose(); super.dispose(); }
  @override void initState(){super.initState();_load();}
  void _load(){_future=widget.app.repo.subordinatesTaskOverview();}
  Future<void> _refresh() async {
    setState(_load);
    try {
      await _future;
      widget.onIssueChanged?.call();
    } catch (_) {/* Rendered in FutureBuilder */}
  }
  Future<void> _openMember(SubordinateTaskSummary member) async {
    await Navigator.push(context,MaterialPageRoute<void>(
      builder:(_)=>SubordinateDetailPage(app:widget.app,member:member)));
    if(mounted) await _refresh();
  }
  Future<void> _openTask(SubordinateTaskSummary member,TaskItem task) async {
    await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>
      SubordinateTaskDetailPage(app:widget.app,memberId:member.userId,
        memberName:member.name,task:task)));
    if(mounted) await _refresh();
  }
  Widget _badge(int count){
    return Container(
      key:const Key('subordinate_issue_badge'),
      constraints:const BoxConstraints(minHeight:23,minWidth:23),
      padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),
      decoration:BoxDecoration(color:const Color(0xFFD63D39),borderRadius:BorderRadius.circular(13)),
      child:Text('$count',textAlign:TextAlign.center,
        style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900)),
    );
  }
  @override Widget build(BuildContext context) =>
    FutureBuilder<List<SubordinateTaskSummary>>(
      future: _future, builder: (context, snap) {
        final all = snap.data ?? <SubordinateTaskSummary>[];
        final departments = all.map((m) => m.departmentName)
          .where((s) => s.isNotEmpty).toSet().toList()..sort();
        final teams = all.map((m) => m.teamName)
          .where((s) => s.isNotEmpty).toSet().toList()..sort();
        final roles = all.map((m) => m.role)
          .where((s) => s.isNotEmpty).toSet().toList()..sort();
        final keyword = _search.text.trim().toLowerCase();
        final visible = all.where((m) =>
          (_department == '全部部门' || m.departmentName == _department) &&
          (_team == '全部团队' || m.teamName == _team) &&
          (_role == '全部职务' || m.role == _role) &&
          (keyword.isEmpty || '${m.name} ${m.username} ${m.departmentName} ${m.teamName}'
            .toLowerCase().contains(keyword))).toList();
        return RefreshIndicator(onRefresh: _refresh,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 110), children: [
        const BusinessHeading(title:'下属工作动态',
          subtitle:'点开人员查看完整任务，红色数字表示待解决问题'),
        const SizedBox(height:15),
        if(snap.connectionState!=ConnectionState.done)
          const Center(child:Padding(padding:EdgeInsets.all(25),child:CircularProgressIndicator()))
        else if(snap.hasError)
          BusinessPanel(title:'下属数据暂不可用',child:Padding(
            padding:const EdgeInsets.symmetric(vertical:12),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('请确认后端已提供有权限过滤的下属任务汇总接口。',
                style:TextStyle(color:Palette.muted,fontSize:12)),
              const SizedBox(height:7),
              Text('${snap.error}',style:const TextStyle(color:Palette.coral,fontSize:11)),
              TextButton(onPressed:_refresh,child:const Text('重试')),
            ])))
        else if (all.isEmpty)
          const BusinessPanel(title:'下属任务',child:BusinessEmpty('暂无可查看的下属任务'))
        else ...[
          TextField(controller: _search, onChanged: (_) => setState(() => _shown = 20),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
              hintText: '搜索姓名、账号、部门或团队')),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 7, children: [
            _filter('全部部门', _department, departments,
              (v) => setState(() { _department = v; _shown = 20; })),
            _filter('全部团队', _team, teams,
              (v) => setState(() { _team = v; _shown = 20; })),
            _filter('全部职务', _role, roles,
              (v) => setState(() { _role = v; _shown = 20; }), role: true),
          ]),
          Padding(padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text('符合条件 ${visible.length} / ${all.length} 人',
              style: const TextStyle(color: Palette.muted, fontSize: 12))),
          if (visible.isEmpty) const BusinessEmpty('没有符合筛选条件的成员'),
        ],
        for (final member in visible.take(_shown)) Padding(

          padding:const EdgeInsets.only(bottom:11),
          child:BusinessPanel(
            title:member.name,kicker:member.departmentName,
            trailing:member.visibleIssueCount>0?_badge(member.visibleIssueCount):null,
            child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Padding(padding:const EdgeInsets.only(top:11),child:Row(children:[
                Semantics(button:true,label:'查看${member.name}的个人信息',
                  child:InkWell(
                    key:ValueKey('subordinate_avatar_${member.userId}'),
                    borderRadius:BorderRadius.circular(28),
                    onTap:()=>_openMember(member),
                    child:CircleAvatar(backgroundColor:Palette.sage,radius:22,
                      child:Text(member.name.isEmpty?'员':member.name.substring(0,1),
                        style:const TextStyle(color:Palette.deep,fontSize:17,fontWeight:FontWeight.w900))),
                  )),
                const SizedBox(width:10),
                Expanded(child:InkWell(onTap:()=>_openMember(member),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(member.name,style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w800)),
                    const Text('点击头像查看人员与全部任务',
                      style:TextStyle(color:Palette.muted,fontSize:11)),
                  ]))),
                const Icon(Icons.chevron_right,color:Palette.muted,size:17),
              ])),
              Padding(padding:const EdgeInsets.symmetric(vertical:10),
                child:Wrap(spacing:12,runSpacing:7,children:[
                  Text('${member.total} 项任务',style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w800)),
                  Text('进行中 ${member.inProgress}',style:const TextStyle(color:Palette.primary,fontSize:11)),
                  Text('已完成 ${member.completed}',style:const TextStyle(color:Palette.muted,fontSize:11)),
                  Text('受阻 ${member.tasks.where((t)=>t.status=='BLOCKED').length}',
                    style:const TextStyle(color:Palette.coral,fontSize:11)),
                  Text('逾期 ${member.tasks.where((t)=>t.isOverdue).length}',
                    style:const TextStyle(color:Palette.coral,fontSize:11)),
                ])),
              for(var i=0;i<member.tasks.take(3).length;i++) ...[
                const Divider(height:1,color:Palette.divider),
                SubordinateTaskRow(task:member.tasks[i],index:i+1,
                  onTap:()=>_openTask(member,member.tasks[i])),
              ],
              if(member.tasks.length>3) Align(alignment:Alignment.centerRight,
                child:TextButton(onPressed:()=>_openMember(member),
                  child:Text('查看全部 ${member.tasks.length} 项任务'))),
            ]),
          ),
        ),
        if (visible.length > _shown)
          TextButton.icon(onPressed: () => setState(() => _shown += 20),
            icon: const Icon(Icons.expand_more),
            label: Text('加载更多成员（还剩 ${visible.length - _shown} 人）')),
      ]));
      },
    );

  Widget _filter(String all, String value, List<String> options,
    ValueChanged<String> changed, {bool role = false}) =>
    SizedBox(width: 115, height: 42,
      child: DropdownButtonFormField<String>(
        key: ValueKey('${all}_$value'), initialValue: value, isExpanded: true,
        decoration: const InputDecoration(contentPadding:
          EdgeInsets.symmetric(horizontal: 7, vertical: 7)),
        items: [all, ...options, if(value != all && !options.contains(value)) value]
          .map((e) => DropdownMenuItem(
          value: e, child: Text(role ? const {
            'FOUNDER':'创始人', 'DEPT_MANAGER':'部门负责人',
            'TEAM_LEADER':'团队长', 'EMPLOYEE':'员工',
          }[e] ?? e : e, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11)))).toList(),
        onChanged: (v) { if (v != null) changed(v); },
      ));
}
