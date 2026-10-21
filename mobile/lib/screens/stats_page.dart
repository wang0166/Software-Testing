import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

class StatsPage extends StatefulWidget {
  final AppState app;
  const StatsPage({super.key,required this.app});
  @override State<StatsPage> createState()=>_StatsPageState();
}
class _StatsPageState extends State<StatsPage> {
  int _days=7;
  late Future<_StatsData> _future;
  @override void initState(){super.initState();_refresh();}
  void _refresh(){_future=_load();}
  Future<_StatsData> _load() async {
    final r=widget.app.repo;
    final values=await Future.wait<dynamic>([r.overview(),r.trend(_days),r.unsubmitted()]);
    return _StatsData(values[0] as Overview,values[1] as List<TrendPoint>,values[2] as List<String>);
  }
  @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:()async{setState(_refresh);await _future;},child:ListView(padding:const EdgeInsets.fromLTRB(20,17,20,35),children:[
    const PageHeading(overline:'INSIGHTS & GROWTH',title:'统计看板',description:'从每一份记录里，看见团队成长'),const SizedBox(height:19),
    FutureBuilder<_StatsData>(future:_future,builder:(context,s){
      if(s.connectionState!=ConnectionState.done)return const Padding(padding:EdgeInsets.all(55),child:Center(child:CircularProgressIndicator()));
      if(s.hasError)return ErrorPanel(error:s.error!,onRetry:()=>setState(_refresh));
      final d=s.data!,o=d.overview;
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        SoftCard(
          child: Row(children: [
            ProgressDonut(value: o.rate / 100),
            const SizedBox(width: 21),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('今日日志提交情况', style: TextStyle(fontSize: 12, color: Palette.muted)),
                  const SizedBox(height: 7),
                  Text('${o.submitted} / ${o.expected}', style: const TextStyle(fontSize: 28, color: Palette.deep, fontWeight: FontWeight.w900)),
                  const Text('已提交 / 应提交', style: TextStyle(fontSize: 11, color: Palette.muted)),
                  const SizedBox(height: 12),
                  const Pill(text: '实时汇总 · 按权限统计'),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height:13),Row(children:[Expanded(child:_smallStat('应提交',o.expected.toString(),Icons.people_outline_rounded,const Color(0xFFE8F4FB))),const SizedBox(width:10),Expanded(child:_smallStat('已提交',o.submitted.toString(),Icons.check_circle_outline_rounded,Palette.sage)),const SizedBox(width:10),Expanded(child:_smallStat('未提交',o.unsubmitted.toString(),Icons.schedule_rounded,Palette.pastel))]),
        const SizedBox(height:24),Row(children:[const Expanded(child:Headline(title:'工作日志趋势',subtitle:'观察日常记录节奏')),ChoiceChip(label:const Text('7天'),selected:_days==7,onSelected:(_)=>setState((){_days=7;_refresh();}),showCheckmark:false),const SizedBox(width:6),ChoiceChip(label:const Text('30天'),selected:_days==30,onSelected:(_)=>setState((){_days=30;_refresh();}),showCheckmark:false)]),
        const SizedBox(height:13),SoftCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('近7个时间点的日志数量',style:TextStyle(color:Palette.muted,fontSize:11)),const SizedBox(height:14),TrendBars(points:d.trend)])),
        const SizedBox(height:24),Headline(title:'待提交名单',subtitle:'仅显示你有权限查看的成员',trailing:Pill(text:'${d.unsubmitted.length} 人',color:const Color(0xFFAD7846),background:Palette.pastel)),const SizedBox(height:12),
        SoftCard(child:d.unsubmitted.isEmpty?const EmptyPanel(title:'全部已完成',subtitle:'当前统计范围内，没有待提交人员',icon:Icons.celebration_outlined):Column(children:[for(var i=0;i<d.unsubmitted.length;i++)Column(children:[if(i>0)const Divider(height:18),Row(children:[CircleAvatar(radius:16,backgroundColor:Palette.pastel,child:Text(d.unsubmitted[i].isEmpty?'—':d.unsubmitted[i].substring(0,1),style:const TextStyle(color:Color(0xFFA87C47)))),const SizedBox(width:10),Expanded(child:Text(d.unsubmitted[i],style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w700))),const Pill(text:'未提交',color:Color(0xFFA87C47),background:Palette.pastel)])])])),
      ]);
    }),
  ]));
  Widget _smallStat(String title,String val,IconData icon,Color bg)=>SoftCard(padding:const EdgeInsets.symmetric(vertical:17,horizontal:10),child:Column(children:[Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:Palette.primary,size:20)),const SizedBox(height:9),Text(val,style:const TextStyle(color:Palette.deep,fontWeight:FontWeight.w900,fontSize:21)),Text(title,style:const TextStyle(color:Palette.muted,fontSize:11))]));
}
class _StatsData {
  final Overview overview;
  final List<TrendPoint> trend;
  final List<String> unsubmitted;
  const _StatsData(this.overview,this.trend,this.unsubmitted);
}
