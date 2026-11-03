import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/task_issue_utils.dart';
import '../widgets/business.dart';

/// Managers have read-only access; the repository/server must validate that the
/// requested assignment belongs to this subordinate in the viewer's hierarchy.
class SubordinateTaskDetailPage extends StatefulWidget {
  final AppState app;
  final int memberId;
  final String memberName;
  final TaskItem task;
  const SubordinateTaskDetailPage({super.key,required this.app,
    required this.memberId,required this.memberName,required this.task});

  @override State<SubordinateTaskDetailPage> createState() => _SubordinateTaskDetailPageState();
}

class _SubordinateTaskDetailPageState extends State<SubordinateTaskDetailPage> {
  late Future<List<TaskProgressRecord>> history;
  @override void initState(){super.initState();_load();}
  void _load(){history=widget.app.repo.subordinateTaskProgressHistory(widget.memberId,widget.task.id);}
  Future<void> _refresh() async {
    setState(_load);
    try{await history;}catch(_){/* Error is rendered below, never swallowed as success. */}
  }

  String _status(String value)=>const {
    'NOT_STARTED':'待开始','IN_PROGRESS':'进行中','BLOCKED':'受阻',
    'COMPLETED':'已完成','RETURNED':'退回','APPROVED':'已通过',
  }[value]??value;

  @override Widget build(BuildContext context){
    final task=widget.task;
    return Scaffold(
      appBar:AppBar(title:const Text('下属任务详情')),
      body:RefreshIndicator(onRefresh:_refresh,child:ListView(
        padding:const EdgeInsets.fromLTRB(16,12,16,32),children:[
          Container(
            padding:const EdgeInsets.all(17),
            decoration:BoxDecoration(color:Palette.deep,borderRadius:BorderRadius.circular(10)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('TEAM TASK / 下属执行任务',
                style:TextStyle(color:Color(0xFFB7C9D6),fontSize:11)),
              const SizedBox(height:7),
              Text(task.name,style:const TextStyle(color:Colors.white,
                fontSize:21,fontWeight:FontWeight.w900)),
              const SizedBox(height:10),
              Text('${widget.memberName} · ${taskTypeLabel(task.taskType)} · ${_status(task.status)}',
                style:const TextStyle(color:Color(0xFFBBE4E0),fontSize:13)),
            ]),
          ),
          const SizedBox(height:12),
          BusinessPanel(title:'任务详情',child:Padding(
            padding:const EdgeInsets.symmetric(vertical:14),child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(task.details.isEmpty?'暂无任务描述':task.details,
                  style:const TextStyle(color:Palette.deep,fontSize:14,height:1.6)),
                const SizedBox(height:10),
                _field('执行人',widget.memberName),
                _field('任务状态',_status(task.status)),
                _field('起始',task.startDate?.replaceFirst('T',' ')??'未设置'),
                _field('截止',task.deadline?.replaceFirst('T',' ')??'未设置'),
                _field('完成率',task.progressPercent==null?'未填报':'${task.progressPercent}%'),
                if(task.isOverdue) const Padding(padding:EdgeInsets.only(top:8),
                  child:Text('该任务已逾期',style:TextStyle(color:Palette.coral,fontWeight:FontWeight.w800))),
              ],
            ),
          )),
          const SizedBox(height:12),
          BusinessPanel(title:'执行反馈与异常问题',child:Padding(
            padding:const EdgeInsets.symmetric(vertical:14),
            child:FutureBuilder<List<TaskProgressRecord>>(
              future:history,builder:(context,snapshot){
                if(snapshot.connectionState!=ConnectionState.done){
                  return const Center(child:Padding(padding:EdgeInsets.all(12),
                    child:CircularProgressIndicator()));
                }
                final items=snapshot.data??[];
                final issueCount=unresolvedIssueEvents(task,items);
                return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  if(issueCount>0) Container(
                    key:const Key('subordinate_issue_count'),
                    padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
                    decoration:BoxDecoration(color:const Color(0xFFFFE9E6),
                      borderRadius:BorderRadius.circular(6)),
                    child:Text(task.openIssueCount==null
                        ? '任务受阻 · 请及时跟进' : '待解决问题 $issueCount 条 · 请及时跟进',
                      style:const TextStyle(color:Palette.coral,fontWeight:FontWeight.w800)),
                  ),
                  if(issueCount>0) const SizedBox(height:12),
                  if(task.progressNote.trim().isNotEmpty) ...[
                    const Text('最新反馈',style:TextStyle(color:Palette.muted,fontSize:12)),
                    const SizedBox(height:4),
                    Text(task.progressNote,style:const TextStyle(
                      fontSize:13,color:Palette.deep,height:1.6)),
                    const SizedBox(height:12),
                  ],
                  if(snapshot.hasError) ...[
                    const Text('当前后端未开放管理者查看进度历史的接口，\n已显示授权任务中的最新反馈。',
                      style:TextStyle(color:Palette.muted,fontSize:12,height:1.6)),
                    const SizedBox(height:5),
                    Text('${snapshot.error}',style:const TextStyle(color:Palette.coral,fontSize:11)),
                  ] else if(items.isEmpty)
                    const Text('暂无历史进度记录',style:TextStyle(color:Palette.muted))
                  else ...[
                    const Text('反馈历史',style:TextStyle(color:Palette.deep,fontWeight:FontWeight.w800)),
                    for(final record in items) Padding(
                      padding:const EdgeInsets.only(top:12),
                      child:Container(
                        decoration:BoxDecoration(
                          color:record.status=='BLOCKED'?const Color(0xFFFFF4F2):const Color(0xFFF5F7F9),
                          borderRadius:BorderRadius.circular(6)),
                        padding:const EdgeInsets.all(11),
                        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Row(children:[
                            Expanded(child:Text('${record.authorName} · ${record.createdAt.replaceFirst('T',' ')}',
                              style:const TextStyle(color:Palette.muted,fontSize:11))),
                            Text(_status(record.status),style:TextStyle(
                              fontSize:12,fontWeight:FontWeight.w800,
                              color:record.status=='BLOCKED'?Palette.coral:Palette.primary)),
                          ]),
                          if(record.percent!=null) Padding(padding:const EdgeInsets.only(top:5),
                            child:Text('完成率 ${record.percent}%',style:const TextStyle(fontSize:12,color:Palette.deep))),
                          if(record.note.trim().isNotEmpty) Padding(padding:const EdgeInsets.only(top:5),
                            child:Text(record.note,style:const TextStyle(fontSize:13,color:Palette.deep,height:1.5))),
                        ]),
                      ),
                    ),
                  ],
                ]);
              },
            ),
          )),
          const SizedBox(height:12),
          const Text('此页面为上级只读视图。任务进度由执行者更新，任务定义修改仍走管理员审核。',
            style:TextStyle(color:Palette.muted,fontSize:11,height:1.6)),
        ],
      )),
    );
  }

  Widget _field(String label,String value)=>Padding(
    padding:const EdgeInsets.only(top:5),child:Row(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        SizedBox(width:75,child:Text(label,style:const TextStyle(color:Palette.muted,fontSize:12))),
        Expanded(child:Text(value,style:const TextStyle(color:Palette.deep,fontSize:12,fontWeight:FontWeight.w600))),
      ]));
}
