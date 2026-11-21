// The Jellyfin mark (purple to blue gradient), drawn in code to avoid an SVG dependency.
import 'package:flutter/material.dart';

class JellyfinMark extends StatelessWidget {
  final double size;
  const JellyfinMark({super.key, this.size = 52});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _MarkPainter());
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final outer = Path()
      ..moveTo(p(50, 8).dx, p(50, 8).dy)
      ..cubicTo(p(44, 8).dx, p(44, 8).dy, p(40, 14).dx, p(40, 14).dy, p(36, 21).dx, p(36, 21).dy)
      ..lineTo(p(10, 70).dx, p(10, 70).dy)
      ..cubicTo(p(6, 78).dx, p(6, 78).dy, p(9, 86).dx, p(9, 86).dy, p(20, 89).dx, p(20, 89).dy)
      ..cubicTo(p(38, 94).dx, p(38, 94).dy, p(62, 94).dx, p(62, 94).dy, p(80, 89).dx, p(80, 89).dy)
      ..cubicTo(p(91, 86).dx, p(91, 86).dy, p(94, 78).dx, p(94, 78).dy, p(90, 70).dx, p(90, 70).dy)
      ..lineTo(p(64, 21).dx, p(64, 21).dy)
      ..cubicTo(p(60, 14).dx, p(60, 14).dy, p(56, 8).dx, p(56, 8).dy, p(50, 8).dx, p(50, 8).dy)
      ..close()
      ..moveTo(p(50, 30).dx, p(50, 30).dy)
      ..cubicTo(p(53, 30).dx, p(53, 30).dy, p(55, 33).dx, p(55, 33).dy, p(58, 38).dx, p(58, 38).dy)
      ..lineTo(p(74, 68).dx, p(74, 68).dy)
      ..cubicTo(p(76, 72).dx, p(76, 72).dy, p(74, 75).dx, p(74, 75).dy, p(70, 76).dx, p(70, 76).dy)
      ..cubicTo(p(58, 79).dx, p(58, 79).dy, p(42, 79).dx, p(42, 79).dy, p(30, 76).dx, p(30, 76).dy)
      ..cubicTo(p(26, 75).dx, p(26, 75).dy, p(24, 72).dx, p(24, 72).dy, p(26, 68).dx, p(26, 68).dy)
      ..lineTo(p(42, 38).dx, p(42, 38).dy)
      ..cubicTo(p(45, 33).dx, p(45, 33).dy, p(47, 30).dx, p(47, 30).dy, p(50, 30).dx, p(50, 30).dy)
      ..close();
    outer.fillType = PathFillType.evenOdd;
    final inner = Path()
      ..moveTo(p(50, 46).dx, p(50, 46).dy)
      ..cubicTo(p(52, 46).dx, p(52, 46).dy, p(53, 48).dx, p(53, 48).dy, p(55, 51).dx, p(55, 51).dy)
      ..lineTo(p(62, 64).dx, p(62, 64).dy)
      ..cubicTo(p(63, 66).dx, p(63, 66).dy, p(62, 67).dx, p(62, 67).dy, p(60, 68).dx, p(60, 68).dy)
      ..cubicTo(p(54, 69).dx, p(54, 69).dy, p(46, 69).dx, p(46, 69).dy, p(40, 68).dx, p(40, 68).dy)
      ..cubicTo(p(38, 67).dx, p(38, 67).dy, p(37, 66).dx, p(37, 66).dy, p(38, 64).dx, p(38, 64).dy)
      ..lineTo(p(45, 51).dx, p(45, 51).dy)
      ..cubicTo(p(47, 48).dx, p(47, 48).dy, p(48, 46).dx, p(48, 46).dy, p(50, 46).dx, p(50, 46).dy)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFAA5CC3), Color(0xFF00A4DC)], begin: Alignment.topLeft, end: Alignment.bottomRight)
          .createShader(Offset.zero & size);
    canvas.drawPath(outer, paint);
    canvas.drawPath(inner, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
