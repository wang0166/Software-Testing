import 'package:flutter/material.dart';

/// 收到但尚未查看的任务：蓝色角标，和下属异常的红色角标区分。
class TaskUnreadBadge extends StatelessWidget {
  final int count;
  final Key? badgeKey;
  const TaskUnreadBadge({super.key, required this.count, this.badgeKey});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Semantics(
      label: '$count 项收到但未查看的任务',
      child: ExcludeSemantics(
        child: Container(
          key: badgeKey,
          constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2267B5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 1.2),
          ),
          child: Text(count > 99 ? '99+' : '$count',
            textAlign: TextAlign.center, maxLines: 1,
            style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w800, fontSize: 10, height: 1.05)),
        ),
      ),
    );
  }
}
