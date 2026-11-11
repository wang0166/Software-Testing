import 'package:flutter/material.dart';

/// A small notification-style badge for unresolved subordinate issues.
/// Zero issues have no visual marker; 100+ is capped to keep narrow tabs tidy.
class IssueCountBadge extends StatelessWidget {
  final int count;
  final Key? badgeKey;
  final bool compact;

  const IssueCountBadge({super.key, required this.count, this.badgeKey, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    return Semantics(
      label: '$count 个下属待解决问题',
      child: ExcludeSemantics(
        child: Container(
          key: badgeKey,
          constraints: BoxConstraints(minWidth: compact ? 16 : 19, minHeight: compact ? 16 : 19),
          padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 5, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFCF3838),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Text(label, maxLines: 1, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
              fontSize: compact ? 9 : 10, height: 1.05)),
        ),
      ),
    );
  }
}
