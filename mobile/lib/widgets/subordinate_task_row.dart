import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Read-only subordinate task line. Badges are OPEN issues, not unread messages.
class SubordinateTaskRow extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onTap;
  final int? index;
  const SubordinateTaskRow({super.key,required this.task,required this.onTap,this.index});

  @override
  Widget build(BuildContext context) {
    final issues = task.visibleIssueCount;
    final attention = issues > 0 || task.isOverdue;
    return Material(
      color: attention ? const Color(0xFFFFF7F5) : Colors.transparent,
      child: InkWell(
        key: ValueKey('subordinate_task_${task.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12,horizontal: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center,children:[
            if (index != null) ...[
              SizedBox(width:30,child:Text('$index'.padLeft(2,'0'),
                style: const TextStyle(fontSize:12,color:Palette.primary,fontWeight:FontWeight.w800))),
            ],
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(task.name,maxLines:2,overflow:TextOverflow.ellipsis,
                style: TextStyle(color:attention ? Palette.coral : Palette.deep,
                  fontSize:13,fontWeight:FontWeight.w800)),
              const SizedBox(height:3),
              Text('${taskTypeLabel(task.taskType)} · ${task.statusLabel}'
                '${task.progressPercent==null ? '' : ' · ${task.progressPercent}%'}'
                ' · 截止 ${task.deadline ?? '未设置'}',
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:Palette.muted,fontSize:11)),
              if (attention && task.progressNote.trim().isNotEmpty)
                Padding(padding:const EdgeInsets.only(top:4),
                  child:Text('问题反馈：${task.progressNote}',maxLines:1,
                    overflow:TextOverflow.ellipsis,
                    style:const TextStyle(color:Palette.coral,fontSize:11))),
              if (task.isOverdue)
                const Padding(padding:EdgeInsets.only(top:3),
                  child:Text('已逾期',style:TextStyle(color:Palette.coral,fontSize:11))),
            ])),
            if(issues>0) ...[
              const SizedBox(width:5),
              Container(
                constraints:const BoxConstraints(minWidth:21,minHeight:21),
                padding:const EdgeInsets.symmetric(horizontal:5,vertical:2),
                decoration:const BoxDecoration(color:Color(0xFFD63D39),shape:BoxShape.circle),
                child:Center(child:Text('$issues',
                  style:const TextStyle(fontSize:11,color:Colors.white,fontWeight:FontWeight.w800))),
              ),
            ],
            const SizedBox(width:5),
            const Icon(Icons.chevron_right,size:18,color:Palette.muted),
          ]),
        ),
      ),
    );
  }
}
