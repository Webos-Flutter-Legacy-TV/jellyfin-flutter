// A subtitle line styled by the viewer's settings (size, colour, background); used by the
// player and by the preview in Settings.
import 'package:flutter/material.dart';

import '../session.dart';
import '../theme.dart';

class SubtitleText extends StatelessWidget {
  final String text;
  final Session session;
  const SubtitleText(this.text, {super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final size = session.subSize.toDouble();
    final color = session.subColor == 'yellow' ? const Color(0xFFFFE14D) : Colors.white;
    final bg = session.subBackground;
    final base = tv(size, weight: FontWeight.w600, color: color, height: 1.3);
    final style = switch (bg) {
      'shadow' => base.copyWith(shadows: const [Shadow(color: Color(0xE6000000), blurRadius: 8, offset: Offset(0, 2)), Shadow(color: Color(0x99000000), blurRadius: 2)]),
      _ => base,
    };
    Widget t = Text(text, textAlign: TextAlign.center, style: style);
    if (bg == 'outline') {
      // A black stroke under the filled text.
      t = Stack(alignment: Alignment.center, children: [
        Text(text, textAlign: TextAlign.center, style: base.copyWith(foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = size / 8..strokeJoin = StrokeJoin.round..color = Colors.black)),
        t,
      ]);
    }
    if (bg == 'box' || bg == 'solid') {
      t = Container(
        padding: EdgeInsets.symmetric(horizontal: size * 0.45, vertical: size * 0.18),
        decoration: BoxDecoration(color: bg == 'solid' ? Colors.black : const Color(0x99000000), borderRadius: BorderRadius.circular(8)),
        child: t,
      );
    }
    return t;
  }
}
