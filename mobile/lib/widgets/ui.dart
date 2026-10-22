import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/models.dart';

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const SoftCard({super.key,required this.child,this.padding=const EdgeInsets.all(18),this.color});
  @override Widget build(BuildContext context)=>Container(
    padding:padding,
    decoration:BoxDecoration(color:color??Colors.white,borderRadius:BorderRadius.circular(23),boxShadow:[BoxShadow(color:Palette.deep.withValues(alpha:.035),offset:const Offset(0,6),blurRadius:23)]),
    child:child,
  );
}
class Headline extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const Headline({super.key,required this.title,this.subtitle,this.trailing});
  @override Widget build(BuildContext context)=>Row(children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.titleLarge),if(subtitle!=null)...[const SizedBox(height:3),Text(subtitle!,style:Theme.of(context).textTheme.bodySmall)]])),
    if(trailing!=null)trailing!,
  ]);
}
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  const Pill({super.key,required this.text,this.color=Palette.primary,this.background=Palette.sage});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),decoration:BoxDecoration(color:background,borderRadius:BorderRadius.circular(100)),child:Text(text,style:TextStyle(color:color,fontWeight:FontWeight.w700,fontSize:11)));
}
class EmptyPanel extends StatelessWidget {
  final String title,subtitle;
  final IconData icon;
  const EmptyPanel({super.key,required this.title,required this.subtitle,this.icon=Icons.inbox_outlined});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:34,horizontal:8),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Container(width:70,height:70,decoration:const BoxDecoration(color:Palette.sage,shape:BoxShape.circle),child:Icon(icon,color:Palette.primary,size:31)),
    const SizedBox(height:16),Text(title,style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:7),Text(subtitle,textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall),
  ]));
}
class ErrorPanel extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorPanel({super.key,required this.error,required this.onRetry});
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(25),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.wifi_off_rounded,color:Palette.coral,size:42),const SizedBox(height:12),Text('加载失败',style:Theme.of(context).textTheme.titleMedium),
    const SizedBox(height:8),Text('$error',textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall),
    const SizedBox(height:15),OutlinedButton.icon(onPressed:onRetry,icon:const Icon(Icons.refresh),label:const Text('重试')),
  ])));
}
void toast(BuildContext context,String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
}

class ProgressDonut extends StatelessWidget {
  final double value;
  final double size;
  const ProgressDonut({super.key,required this.value,this.size=116});
  @override Widget build(BuildContext context)=>SizedBox(width:size,height:size,child:Stack(alignment:Alignment.center,children:[
    SizedBox.expand(child:CircularProgressIndicator(value:value.clamp(0,1).toDouble(),strokeWidth:10,strokeCap:StrokeCap.round,backgroundColor:const Color(0xFFE1F2EB),color:Palette.primary)),
    Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text('${(value*100).round()}%',style:TextStyle(color:Palette.deep,fontWeight:FontWeight.w900,fontSize:size*.20)),Text('提交率',style:const TextStyle(color:Palette.muted,fontSize:11))]),
  ]));
}
class TrendBars extends StatelessWidget {
  final List<TrendPoint> points;
  final int maxBars;
  const TrendBars({super.key, required this.points, this.maxBars = 7});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const EmptyPanel(
        title: '暂无趋势',
        subtitle: '有日志后会自动生成统计趋势',
      );
    }
    final limit = maxBars < 1 ? 1 : maxBars;
    final data = points.length > limit
        ? points.sublist(points.length - limit)
        : points;
    final maxVal = math.max(1, data.fold<int>(0, (m, e) => math.max(m, e.count)));

    return LayoutBuilder(
      builder: (context, constraints) {
        // A 30-day trend keeps readable labels and can be swiped horizontally.
        final chartWidth = data.length > 8
            ? math.max(constraints.maxWidth, data.length * 38.0)
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            height: 145,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in data)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${point.count}',
                              style: const TextStyle(
                                  fontSize: 10, color: Palette.muted)),
                          const SizedBox(height: 6),
                          Flexible(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: math.max(.07, point.count / maxVal),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: point.day == todayChina
                                        ? Palette.primary
                                        : const Color(0xFFAFE2D1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            friendlyDate(point.day)
                                .replaceAll('月', '/')
                                .replaceAll('日', ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: Palette.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PageHeading extends StatelessWidget {
  final String overline,title,description;
  const PageHeading({super.key,required this.overline,required this.title,required this.description});
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(overline.toUpperCase(),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800,letterSpacing:2,color:Palette.primary)),
    const SizedBox(height:7),Text(title,style:Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height:7),Text(description,style:Theme.of(context).textTheme.bodySmall),
  ]);
}
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key,required this.status});
  @override Widget build(BuildContext context){final submitted=status=='SUBMITTED',completed=status=='COMPLETED';return Pill(text:submitted?'已提交':status=='DRAFT'?'草稿':completed?'已完成':status=='IN_PROGRESS'?'进行中':'待开始',color:submitted||completed?Palette.primary:status=='DRAFT'?const Color(0xFFB58031):Palette.deep,background:submitted||completed?Palette.sage:status=='DRAFT'?Palette.pastel:const Color(0xFFEDF1F4));}
}
