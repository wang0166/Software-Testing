import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'calendar_page.dart';
import 'log_detail_page.dart';

class HomePage extends StatefulWidget {
  final AppState app;
  final ValueChanged<int> onTab;
  const HomePage({super.key,required this.app,required this.onTab});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _future;
  @override void initState(){super.initState();_refresh();}
  void _refresh(){_future=_load();}
  Future<_HomeData> _load() async {
    final r=widget.app.repo;
    // Panels load independently; a partially implemented backend can still show useful data.
    Future<T?> safely<T>(Future<T> Function() fn) async {try{return await fn();}catch(_){return null;}}
    final values=await Future.wait<dynamic>([
      safely(()=>r.overview()),
      safely(()=>r.logs()),
      safely(()=>r.companyMatters()),
      safely(()=>r.companyImportantTasks()),
    ]);
    return _HomeData(values[0] as Overview?,values[1] as List<WorkLog>?,values[2] as List<CompanyItem>?,values[3] as List<CompanyItem>?);
  }
  void _reload()=>setState(_refresh);
  @override Widget build(BuildContext context){
    final name=widget.app.user!.name;
    final h=chinaNow.hour;
    final greeting=h<11?'早上好':h<18?'下午好':'晚上好';
    return RefreshIndicator(onRefresh:() async{_reload();await _future;},child:ListView(padding:const EdgeInsets.fromLTRB(20,16,20,28),children:[
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('PANDORA / WORKSPACE',style:TextStyle(fontSize:11,color:Palette.primary,fontWeight:FontWeight.w900,letterSpacing:1.6)),const SizedBox(height:4),Text('$greeting，$name ✨',style:Theme.of(context).textTheme.headlineMedium)])),CircleAvatar(backgroundColor:Palette.sage,radius:24,child:Text(name.isEmpty?'P':name.substring(0,1),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:Palette.primary)))]),
      const SizedBox(height:17),Container(padding:const EdgeInsets.all(21),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF208E81),Color(0xFF62B7A0)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(25)),child:Stack(children:[
        Positioned(right:-25,top:-35,child:Icon(Icons.spa_rounded,color:Colors.white.withValues(alpha:.12),size:160)),
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('每一步努力，都值得被记录',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:9),Text('${friendlyDate(todayChina)}  ·  ${widget.app.user!.roleLabel}的工作空间',style:const TextStyle(color:Color(0xFFE0F8EF),fontSize:12)),const SizedBox(height:19),Wrap(spacing:9,runSpacing:9,children:[_bannerButton('写今日志',Icons.edit_note_rounded,()=>widget.onTab(1)),_bannerButton('日历视图',Icons.calendar_month_outlined,()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>CalendarPage(app:widget.app))))])]),
      ])),
      const SizedBox(height:23),FutureBuilder<_HomeData>(future:_future,builder:(context,snapshot){
        if(!snapshot.hasData) return const Padding(padding:EdgeInsets.all(42),child:Center(child:CircularProgressIndicator()));
        final d=snapshot.data!;
        final today=d.logs?.where((e)=>e.logDate==todayChina && e.authorId==widget.app.user!.id).toList()??[];
        final myLog=today.isEmpty?null:today.first;
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Headline(title:'今日工作速览',subtitle:'重点信息，一眼掌握'),const SizedBox(height:13),
          Row(children:[Expanded(child:_metric('提交率',d.overview==null?'—':'${d.overview!.rate.toStringAsFixed(0)}%',Icons.donut_large_rounded,const Color(0xFFE3F6EE),Palette.primary)),const SizedBox(width:12),Expanded(child:_metric('待提交',d.overview==null?'—':'${d.overview!.unsubmitted} 人',Icons.hourglass_bottom_rounded,const Color(0xFFFDF0DF),const Color(0xFFB7863D)))]),
          const SizedBox(height:18),const Headline(title:'我的日志',subtitle:'当天工作随手记录'),const SizedBox(height:12),
          SoftCard(child:InkWell(onTap:()=>myLog==null?widget.onTab(1):Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LogDetailPage(app:widget.app,log:myLog))),child:Row(children:[Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Palette.sage,borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.auto_stories_rounded,color:Palette.primary)),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(myLog==null?'今天还没有日志':'今日工作日志',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:15,color:Palette.deep)),const SizedBox(height:5),Text(myLog==null?'点击开始记录今天的成果':myLog.content,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Palette.muted,fontSize:12))])),const SizedBox(width:8),if(myLog!=null)StatusBadge(status:myLog.status),const Icon(Icons.chevron_right_rounded,color:Palette.muted)]))),
          const SizedBox(height:23),const Headline(title:'四大信息面板',subtitle:'把重要的事放在最前面'),const SizedBox(height:13),
          Row(children:[
            Expanded(child:_compactBoard('公司重要事项',Icons.campaign_outlined,const Color(0xFFF2F8EB),d.matters)),
            const SizedBox(width:11),
            Expanded(child:_compactBoard('公司重要任务',Icons.flag_outlined,const Color(0xFFFFF4E5),d.companyTasks)),
          ]),
          const SizedBox(height:11),
          Row(children:[
            Expanded(child:_compactBoard('个人重点工作',Icons.task_alt_rounded,const Color(0xFFF0EFFB),null,onTap:()=>widget.onTab(2))),
            const SizedBox(width:11),
            Expanded(child:_compactBoard('日志信息流',Icons.forum_outlined,const Color(0xFFE7F5F3),null,onTap:()=>widget.onTab(1))),
          ]),
          if(d.overview==null || d.logs==null)const Padding(padding:EdgeInsets.only(top:15),child:Text('部分数据未能加载，请检查后端接口或下拉刷新。',style:TextStyle(color:Palette.muted,fontSize:12))),
        ]);
      }),
    ]));
  }
  Widget _bannerButton(String label,IconData icon,VoidCallback action)=>TextButton.icon(onPressed:action,style:TextButton.styleFrom(backgroundColor:Colors.white.withValues(alpha:.18),foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)),padding:const EdgeInsets.symmetric(horizontal:12,vertical:8)),icon:Icon(icon,size:18),label:Text(label,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12)));
  Widget _metric(String title,String value,IconData icon,Color bg,Color color)=>SoftCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:37,height:37,decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:color,size:20)),const SizedBox(height:12),Text(title,style:const TextStyle(color:Palette.muted,fontSize:12)),const SizedBox(height:4),Text(value,style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w900,fontSize:23))]));
  Widget _compactBoard(String title,IconData icon,Color bg,List<CompanyItem>? data,{VoidCallback? onTap}) {
    void openItems(){
      if(onTap!=null){onTap();return;}
      if(data==null)return;
      showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,8,20,25),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(ctx).textTheme.titleLarge),const SizedBox(height:12),if(data.isEmpty)const Text('暂无内容') else ...data.take(10).map((e)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.circle,size:8,color:Palette.primary),title:Text(e.title),subtitle:Text(e.content,maxLines:3,overflow:TextOverflow.ellipsis)))]))));
    }
    return SoftCard(padding:const EdgeInsets.all(15),child:InkWell(onTap:openItems,child:SizedBox(height:132,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(height:42,width:42,decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:Palette.deep)),
      const Spacer(),Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800,color:Palette.deep)),
      const SizedBox(height:5),Text(data==null?'点击查看':data.isEmpty?'暂无内容':'${data.length} 条动态',style:const TextStyle(fontSize:11,color:Palette.muted)),
    ]))));
  }

}
class _HomeData {
  final Overview? overview;
  final List<WorkLog>? logs;
  final List<CompanyItem>? matters,companyTasks;
  const _HomeData(this.overview,this.logs,this.matters,this.companyTasks);
}
