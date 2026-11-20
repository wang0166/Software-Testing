import 'package:flutter/material.dart';
import '../core/theme.dart';

/// 全应用共用的软萌信息组件，业务信息保持清晰可读。
class BusinessHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const BusinessHeading({super.key, required this.title, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        height: 38, width: 38,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(color: Palette.rose,
          borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.auto_awesome_rounded,
          color: Palette.primary, size: 21),
      ),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Palette.deep,
            fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.3)),
          if (subtitle != null) Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle!, style: const TextStyle(
              color: Palette.muted, fontSize: 12))),
        ])),
      if (action != null) action!,
    ],
  );
}

class BusinessPanel extends StatelessWidget {
  final String title;
  final String? kicker;
  final int? count;
  final Widget child;
  final Widget? trailing;
  const BusinessPanel({super.key, required this.title, required this.child,
    this.kicker, this.count, this.trailing});
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Palette.divider),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: Palette.primary.withValues(alpha: .045),
        blurRadius: 17, offset: const Offset(0, 5))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(15, 13, 14, 13),
        decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Palette.rose, Palette.lavender],
          begin: Alignment.centerLeft, end: Alignment.centerRight)),
        child: Row(children: [
          const Icon(Icons.auto_awesome_rounded,
            color: Palette.primary, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kicker != null) Text(kicker!, style: const TextStyle(
                color: Palette.muted, fontSize: 10, letterSpacing: .7)),
              Text(title, style: const TextStyle(color: Palette.deep,
                fontSize: 16, fontWeight: FontWeight.w900)),
            ])),
          if (count != null) Text('$count / 10', style: const TextStyle(
            color: Palette.primary, fontSize: 13, fontWeight: FontWeight.w800)),
          if (trailing != null) trailing!,
        ]),
      ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: child),
    ]),
  );
}

class BusinessRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int? index;
  final VoidCallback? onTap;
  const BusinessRow({super.key, required this.title, this.subtitle, this.index, this.onTap});
  @override Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(
    onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 11), child: Row(children: [
      if (index != null) ...[
        Container(width: 27, height: 27, alignment: Alignment.center,
          decoration: BoxDecoration(color: Palette.rose,
            borderRadius: BorderRadius.circular(10)),
          child: Text(index!.toString().padLeft(2, '0'),
            style: const TextStyle(color: Palette.primary,
              fontSize: 11, fontWeight: FontWeight.w900))),
        const SizedBox(width: 7),
      ],
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Palette.deep, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
        if (subtitle != null && subtitle!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Palette.muted))),
      ])),
      if (onTap != null) const Icon(Icons.chevron_right, size: 17, color: Palette.muted),
    ])),
  ));
}

class BusinessEmpty extends StatelessWidget {
  final String message;
  const BusinessEmpty(this.message, {super.key});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text(message, style: const TextStyle(color: Palette.muted, fontSize: 12)));
}
