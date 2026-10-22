import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// 只读任务数据地图：仅显示本人接收的任务与本人自建任务。
class TaskMapPage extends StatefulWidget {
  final AppState app;
  const TaskMapPage({super.key,required this.app});
  @override State<TaskMapPage> createState()=>_TaskMapPageState();
}
class _TaskMapPageState extends State<TaskMapPage> {
  late Future<List<TaskItem>> _items;
  @override void initState(){super.initState();_reload();}
  void _reload(){_items=widget.app.repo.taskMap();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('任务数据地图')),
    body:RefreshIndicator(onRefresh:() async{setState(_reload);await _items;},child:ListView(padding:const EdgeInsets.fromLTRB(20,12,20,30),children:[
      const PageHeading(overline:'MY TASK MAP',title:'任务全景',description:'重要进展集中呈现，修改请前往任务页面'),
      const SizedBox(height:17),SoftCard(color:Palette.sage,child:const Row(children:[Icon(Icons.map_outlined,color:Palette.primary,size:28),SizedBox(width:13),Expanded(child:Text('这里仅展示你收到的任务和自己创建的任务，不包含公司展示项。',style:TextStyle(fontSize:12,color:Palette.deep,height:1.65)))])),
      const SizedBox(height:17),FutureBuilder<List<TaskItem>>(future:_items,builder:(context,s){
        if(s.connectionState!=ConnectionState.done)return const Padding(padding:EdgeInsets.all(30),child:Center(child:CircularProgressIndicator()));
        if(s.hasError)return ErrorPanel(error:s.error!,onRetry:()=>setState(_reload));
        final data=s.data??[];
        if(data.isEmpty)return const EmptyPanel(title:'暂无任务',subtitle:'收到的任务和自建任务会出现在这里');
        return Column(children:[for(final task in data) Padding(padding:const EdgeInsets.only(bottom:12),child:SoftCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text(task.name,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16,color:Palette.deep))),StatusBadge(status:task.status)]),
          const SizedBox(height:9),Text(task.details,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(height:1.5,fontSize:13,color:Palette.muted)),
          const SizedBox(height:12),Wrap(spacing:8,runSpacing:7,children:[Pill(text:task.source=='PERSONAL'?'个人自建':'上级派发'),if(task.urgency=='URGENT'&&task.source!='PERSONAL')const Pill(text:'紧急',color:Color(0xFFB45E46),background:Color(0xFFFDEEE8)),if(task.deadline!=null)Pill(text:'截止 ${task.deadline}',color:const Color(0xFF6C7790),background:const Color(0xFFF0F1F8))]),
        ])))]);
      }),
    ])),
  );
}
