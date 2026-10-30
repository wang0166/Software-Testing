import 'package:flutter/material.dart';
import '../core/theme.dart';

/// High-contrast enterprise components; information first, decoration second.
class BusinessHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const BusinessHeading({super.key, required this.title, this.subtitle, this.action});
  @override Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Palette.deep, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.6)),
      if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, style: const TextStyle(color: Palette.muted, fontSize: 12))),
    ])),
    if (action != null) action!,
  ]);
}

class BusinessPanel extends StatelessWidget {
  final String title;
  final String? kicker;
  final int? count;
  final Widget child;
  final Widget? trailing;
  const BusinessPanel({super.key, required this.title, required this.child, this.kicker, this.count, this.trailing});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Palette.divider), borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.fromLTRB(15, 13, 14, 13), decoration: const BoxDecoration(
        color: Palette.deep, borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
      ), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (kicker != null) Text(kicker!, style: const TextStyle(color: Color(0xFF9BB8C6), fontSize: 10, letterSpacing: .8)),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ])),
        if (count != null) Text('$count / 10', style: const TextStyle(color: Color(0xFF72D7C6), fontSize: 13, fontWeight: FontWeight.w700)),
        if (trailing != null) trailing!,
      ])),
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
        SizedBox(width: 26, child: Text(index!.toString().padLeft(2, '0'), style: const TextStyle(color: Palette.primary, fontSize: 12, fontWeight: FontWeight.w800))),
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
