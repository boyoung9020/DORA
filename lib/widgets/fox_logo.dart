import 'package:flutter/material.dart';

/// SYNC ?ъ슦 留덉뒪肄뷀듃 濡쒓퀬
class FoxLogo extends StatelessWidget {
  final double size;

  const FoxLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FoxPainter(),
      ),
    );
  }
}

class _FoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final cy = s / 2;

    // ?됱긽 ?뺤쓽
    const orange = Color(0xFFFF8C42);
    const darkOrange = Color(0xFFE8722A);
    const cream = Color(0xFFFFF3E0);
    const white = Color(0xFFFFFFFF);
    const nose = Color(0xFF3D2C2C);
    const eyeColor = Color(0xFF2D2117);

    // === 洹 (?ㅼそ) ===
    // ?쇱そ 洹
    _drawEar(canvas, cx - s * 0.28, cy - s * 0.08, s, orange, darkOrange, cream, isLeft: true);
    // ?ㅻⅨ履?洹
    _drawEar(canvas, cx + s * 0.28, cy - s * 0.08, s, orange, darkOrange, cream, isLeft: false);

    // === 癒몃━ (硫붿씤 ?? ===
    final headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.0,
        colors: [
          const Color(0xFFFFAA65),
          orange,
          darkOrange,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s * 0.38));
    canvas.drawCircle(Offset(cx, cy + s * 0.02), s * 0.38, headPaint);

    // === ?쇨뎬 ?곗깋 ?곸뿭 (蹂?+ ??二쇰?) ===
    final facePath = Path();
    facePath.moveTo(cx, cy - s * 0.1);
    facePath.quadraticBezierTo(cx - s * 0.32, cy + s * 0.05, cx - s * 0.18, cy + s * 0.32);
    facePath.quadraticBezierTo(cx, cy + s * 0.42, cx + s * 0.18, cy + s * 0.32);
    facePath.quadraticBezierTo(cx + s * 0.32, cy + s * 0.05, cx, cy - s * 0.1);
    facePath.close();

    final facePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.3),
        radius: 0.8,
        colors: [white, cream],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy + s * 0.15), radius: s * 0.25));
    canvas.drawPath(facePath, facePaint);

    // === ??===
    // ???곗옄
    final eyeWhitePaint = Paint()..color = white;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - s * 0.12, cy - s * 0.02), width: s * 0.14, height: s * 0.15),
      eyeWhitePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + s * 0.12, cy - s * 0.02), width: s * 0.14, height: s * 0.15),
      eyeWhitePaint,
    );

    // ?덈룞??
    final pupilPaint = Paint()..color = eyeColor;
    canvas.drawCircle(Offset(cx - s * 0.11, cy - s * 0.01), s * 0.045, pupilPaint);
    canvas.drawCircle(Offset(cx + s * 0.13, cy - s * 0.01), s * 0.045, pupilPaint);

    // ???섏씠?쇱씠??
    final highlightPaint = Paint()..color = white;
    canvas.drawCircle(Offset(cx - s * 0.095, cy - s * 0.025), s * 0.018, highlightPaint);
    canvas.drawCircle(Offset(cx + s * 0.145, cy - s * 0.025), s * 0.018, highlightPaint);

    // === 肄?===
    final nosePath = Path();
    nosePath.moveTo(cx, cy + s * 0.08);
    nosePath.lineTo(cx - s * 0.04, cy + s * 0.12);
    nosePath.quadraticBezierTo(cx, cy + s * 0.14, cx + s * 0.04, cy + s * 0.12);
    nosePath.close();
    canvas.drawPath(nosePath, Paint()..color = nose);

    // 肄??섏씠?쇱씠??
    canvas.drawCircle(
      Offset(cx - s * 0.01, cy + s * 0.095),
      s * 0.01,
      Paint()..color = const Color(0xFF5A4545),
    );

    // === ??===
    final mouthPaint = Paint()
      ..color = nose.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012
      ..strokeCap = StrokeCap.round;

    // ?쇱そ ??
    final leftMouth = Path();
    leftMouth.moveTo(cx, cy + s * 0.14);
    leftMouth.quadraticBezierTo(cx - s * 0.04, cy + s * 0.19, cx - s * 0.06, cy + s * 0.17);
    canvas.drawPath(leftMouth, mouthPaint);

    // ?ㅻⅨ履???
    final rightMouth = Path();
    rightMouth.moveTo(cx, cy + s * 0.14);
    rightMouth.quadraticBezierTo(cx + s * 0.04, cy + s * 0.19, cx + s * 0.06, cy + s * 0.17);
    canvas.drawPath(rightMouth, mouthPaint);

    // === 蹂??띿“ ===
    final blushPaint = Paint()..color = const Color(0xFFFF9B9B).withValues(alpha: 0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - s * 0.2, cy + s * 0.1), width: s * 0.1, height: s * 0.06),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + s * 0.2, cy + s * 0.1), width: s * 0.1, height: s * 0.06),
      blushPaint,
    );
  }

  void _drawEar(Canvas canvas, double x, double y, double s, Color orange, Color darkOrange, Color inner, {required bool isLeft}) {
    final earPath = Path();
    final dir = isLeft ? -1.0 : 1.0;

    // 諛붽묑 洹
    earPath.moveTo(x - dir * s * 0.1, y + s * 0.18);
    earPath.lineTo(x + dir * s * 0.02, y - s * 0.22);
    earPath.lineTo(x + dir * s * 0.14, y + s * 0.12);
    earPath.close();

    final earPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [darkOrange, orange],
      ).createShader(Rect.fromLTWH(x - s * 0.15, y - s * 0.22, s * 0.3, s * 0.4));
    canvas.drawPath(earPath, earPaint);

    // ?덉そ 洹
    final innerPath = Path();
    innerPath.moveTo(x - dir * s * 0.05, y + s * 0.12);
    innerPath.lineTo(x + dir * s * 0.02, y - s * 0.12);
    innerPath.lineTo(x + dir * s * 0.09, y + s * 0.08);
    innerPath.close();

    canvas.drawPath(innerPath, Paint()..color = inner.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
