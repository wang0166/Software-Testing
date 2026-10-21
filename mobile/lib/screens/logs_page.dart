import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import '../widgets/redesign.dart';
import 'log_detail_page.dart';

class LogsPage extends StatefulWidget {
  final AppState app;
  const LogsPage({super.key,required this.app});
  @override State<LogsPage> createState()=>_LogsPageState();
}
class _LogsPageState extends State<LogsPage> {
  late Future<List<WorkLog>> _future;
  String _filter='全部';
  final _search=TextEditingController();
  @override void initState(){super.initState();_refresh();}
  @override void dispose(){_search.dispose();super.dispose();}
  void _refresh(){_future=widget.app.repo.logs();}
  Future<void> _edit({WorkLog? draft}) async {
    final ok=await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>LogEditorPage(app:widget.app,draft:draft)));
    if(ok==true&&mounted)setState(_refresh);
  }
  @override Widget build(BuildContext context) {
    final me = widget.app.user!;
    return Scaffold(
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(22, 19, 22, 11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CanvasHeader(eyebrow: 'PANDORA  /  JOURNAL', title: '工作手记', subtitle: '日有所记，事有所成', icon: Icons.edit_note_rounded),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Palette.pastel, borderRadius: BorderRadius.circular(20)), child: const Row(children: [
            ColoredIcon(icon: Icons.lightbulb_outline_rounded, color: Color(0xFFBD8A47), background: Color(0xFFFFDFB0), size: 40),
            SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('写下今天的一点进步', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Palette.deep)),
              SizedBox(height: 3), Text('工作记录，让成长看得见', style: TextStyle(fontSize: 11, color: Palette.muted)),
            ])),
          ])),
          const SizedBox(height: 14),
          TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: '搜索日志、同事或关键词', prefixIcon: Icon(Icons.search_rounded))),
          const SizedBox(height: 11),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final tab in ['全部', '我的', '草稿', '已提交']) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
            label: Text(tab), selected: _filter == tab,
            selectedColor: Palette.deep, showCheckmark: false, backgroundColor: Colors.white,
            labelStyle: TextStyle(color: _filter == tab ? Colors.white : Palette.deep, fontSize: 12, fontWeight: FontWeight.w800),
            side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (_) => setState(() => _filter = tab),
          ))])),
        ])),
        Expanded(child: FutureBuilder<List<WorkLog>>(future: _future, builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorPanel(error: snap.error!, onRetry: () => setState(_refresh));
          final data = (snap.data ?? []).where((log) {
            if (_filter == '我的' && log.authorId != me.id) return false;
            if (_filter == '草稿' && log.status != 'DRAFT') return false;
            if (_filter == '已提交' && log.status != 'SUBMITTED') return false;
            final q = _search.text.trim().toLowerCase();
            return q.isEmpty || log.content.toLowerCase().contains(q) || log.authorName.toLowerCase().contains(q);
          }).toList();
          if (data.isEmpty) return ListView(children: const [EmptyPanel(title: '这里还很安静', subtitle: '换个筛选条件，或开始记录今天的工作', icon: Icons.auto_stories_outlined)]);
          return RefreshIndicator(onRefresh: () async { setState(_refresh); await _future; }, child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 120), itemCount: data.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final log = data[index];
              final day = DateTime.tryParse(log.logDate);
              final featured = index == 0;
              return StoryCard(padding: EdgeInsets.zero, child: Material(color: Colors.transparent, child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () async { await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LogDetailPage(app: widget.app, log: log))); if (mounted) setState(_refresh); },
                child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 49, height: 54, decoration: BoxDecoration(color: featured ? Palette.deep : Palette.sage, borderRadius: BorderRadius.circular(16)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(day == null ? '—' : '${day.day}', style: TextStyle(color: featured ? Colors.white : Palette.deep, fontSize: 21, fontWeight: FontWeight.w900)),
                      Text(day == null ? 'DATE' : '${day.month} 月', style: TextStyle(color: featured ? const Color(0xFFB7DDD4) : Palette.muted, fontSize: 9, fontWeight: FontWeight.w800)),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(log.authorName, style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.deep, fontSize: 15)),
                      const SizedBox(height: 3), Text(log.logDate, style: const TextStyle(color: Palette.muted, fontSize: 11)),
                    ])),
                    StatusBadge(status: log.status),
                  ]),
                  const SizedBox(height: 15),
                  Text(log.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.ink, fontSize: 13, height: 1.75)),
                  const SizedBox(height: 15),
                  const DottedDivider(),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: Palette.primary, size: 16), const SizedBox(width: 7),
                    const Text('查看日志与点评', style: TextStyle(color: Palette.muted, fontSize: 11)),
                    const Spacer(),
                    if (log.isImportant) const Pill(text: '重点', color: Color(0xFFB58037), background: Palette.pastel),
                    const SizedBox(width: 5), const Icon(Icons.arrow_outward_rounded, size: 17, color: Palette.primary),
                  ]),
                ])),
              )));
            },
          ));
        })),
      ]),
      floatingActionButton: me.canWriteLog ? FloatingActionButton.extended(
        onPressed: () async {
          try {
            final items = await widget.app.repo.logs(date: todayChina);
            if (!context.mounted) return;
            final own = items.where((e) => e.authorId == me.id).toList();
            if (own.isNotEmpty && own.first.submitted) { toast(context, '今天已提交日志，不能再次创建'); return; }
            await _edit(draft: own.isEmpty ? null : own.first);
          } catch (e) { if (context.mounted) toast(context, '$e'); }
        },
        backgroundColor: Palette.deep, foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_note_rounded), label: const Text('写今日志', style: TextStyle(fontWeight: FontWeight.w900)),
      ) : null,
    );
  }

}

class LogEditorPage extends StatefulWidget {
  final AppState app;
  final WorkLog? draft;
  const LogEditorPage({super.key,required this.app,this.draft});
  @override State<LogEditorPage> createState()=>_LogEditorPageState();
}
class _LogEditorPageState extends State<LogEditorPage> {
  late final TextEditingController _controller;
  bool _saving=false;
  @override void initState(){super.initState();_controller=TextEditingController(text:widget.draft?.content??'');}
  @override void dispose(){_controller.dispose();super.dispose();}
  Future<void> _save({required bool submit}) async {
    if(_saving)return;
    if(_controller.text.trim().isEmpty){toast(context,'先写下今天完成的工作吧');return;}
    setState(()=>_saving=true);
    try {
      final saved=await widget.app.repo.saveLog(_controller.text.trim(),id:widget.draft?.id);
      if(submit) await widget.app.repo.submitLog(saved.id);
      if(!mounted)return;
      toast(context,submit?'今日工作日志已提交':'草稿保存成功');
      Navigator.pop(context,true);
    }catch(e){if(mounted)toast(context,'$e');}
    finally {if(mounted)setState(()=>_saving=false);}
  }
  @override Widget build(BuildContext context){final len=_controller.text.trim().length;return Scaffold(
    appBar:AppBar(title:Text(widget.draft==null?'写今日志':'编辑今日草稿')),
    body:SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:Palette.sage,borderRadius:BorderRadius.circular(20)),child:Row(children:[const Icon(Icons.today_rounded,color:Palette.primary),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('今天 · ${friendlyDate(todayChina)}',style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w800)),const SizedBox(height:3),const Text('每日一条 · 22:00 截止 · 提交后不可修改',style:TextStyle(color:Palette.muted,fontSize:11))]))])),
      const SizedBox(height:20),const Text('记录今天的闪光时刻',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:Palette.deep)),const SizedBox(height:10),
      Expanded(child:TextField(controller:_controller,onChanged:(_)=>setState((){}),maxLines:null,expands:true,textAlignVertical:TextAlignVertical.top,keyboardType:TextInputType.multiline,decoration:const InputDecoration(hintText:'例如：\n• 今天完成了哪些任务\n• 遇到了哪些问题与解决方案\n• 明天计划推进什么\n\n写下真实的工作记录就好。'))),
      const SizedBox(height:8),Text('$len 字 · 内容不能为空',textAlign:TextAlign.right,style:const TextStyle(color:Palette.muted,fontSize:11)),
      const SizedBox(height:13),Row(children:[Expanded(child:OutlinedButton(onPressed:_saving?null:()=>_save(submit:false),style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(50),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),child:const Text('保存草稿'))),const SizedBox(width:10),Expanded(child:FilledButton(onPressed:_saving?null:()=>_confirmSubmit(),child:_saving?const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Text('正式提交')))]),
    ]))));
  }
  Future<void> _confirmSubmit() async {
    final confirm=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('确认提交日志？'),content:const Text('正式提交后内容不可修改，确定要提交吗？'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('再检查一下')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('确定提交'))]));
    if(confirm==true)await _save(submit:true);
  }
}
