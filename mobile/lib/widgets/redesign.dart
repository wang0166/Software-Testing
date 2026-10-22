import 'package:flutter/material.dart';
import '../core/theme.dart';

/// A small self-contained design system. No extra font, image or pub dependency.
class CanvasHeader extends StatelessWidget {
  final String eyebrow, title, subtitle;
  final IconData icon;
  final Color accent;
  const CanvasHeader({super.key, required this.eyebrow, required this.title, required this.subtitle, this.icon = Icons.auto_awesome_rounded, this.accent = Palette.primary});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow, style: TextStyle(letterSpacing: 2.1, color: accent, fontSize: 10, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text(title, style: const TextStyle(fontSize: 31, letterSpacing: -.6, fontWeight: FontWeight.w900, color: Palette.deep)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Palette.muted, fontSize: 12)),
      ])),
      const SizedBox(width: 12),
      Container(width: 58, height: 58, decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(21)), child: Icon(icon, color: accent, size: 29)),
    ]),
  );
}

class StoryCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final Border? border;
  const StoryCard({super.key, required this.child, this.color = Colors.white, this.padding = const EdgeInsets.all(19), this.border});
  @override Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color, border: border,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: Palette.deep.withValues(alpha: .035), blurRadius: 22, offset: const Offset(0, 9))],
    ), child: child,
  );
}

class TinyLabel extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;
  const TinyLabel({super.key, required this.title, this.action, this.onTap});
  @override Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(fontSize: 19, letterSpacing: -.3, fontWeight: FontWeight.w900, color: Palette.deep))),
    if (action != null) TextButton(onPressed: onTap, child: Row(mainAxisSize: MainAxisSize.min, children: [Text(action!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const Icon(Icons.arrow_forward_ios_rounded, size: 11)])),
  ]);
}

class ColoredIcon extends StatelessWidget {
  final IconData icon;
  final Color color, background;
  final double size;
  const ColoredIcon({super.key, required this.icon, this.color = Palette.primary, this.background = Palette.sage, this.size = 48});
  @override Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * .32)),
    child: Icon(icon, color: color, size: size * .48),
  );
}

class WatermarkNumber extends StatelessWidget {
  final String value, label;
  final Color color;
  const WatermarkNumber({super.key, required this.value, required this.label, this.color = Colors.white});
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -.9)),
    const SizedBox(height: 3),
    Text(label, style: TextStyle(color: color.withValues(alpha: .76), fontSize: 11, fontWeight: FontWeight.w600)),
  ]);
}

class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key});
  @override Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
    final n = (c.maxWidth / 11).floor();
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(n > 0 ? n : 1, (i) => Container(width: 4, height: 2, color: Palette.divider)));
  });
}
