// lib/src/widgets/telegram_icon.dart
// Inline Telegram glyph drawn with CustomPainter (no asset dependency).

import 'package:flutter/widgets.dart';

class BondifyTelegramIcon extends StatelessWidget {
  final Color color;
  final double size;
  const BondifyTelegramIcon({super.key, required this.color, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TelegramPainter(color: color),
    );
  }
}

class _TelegramPainter extends CustomPainter {
  final Color color;
  _TelegramPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final plane = Path()
      ..moveTo(2 * s, 12 * s)
      ..lineTo(22 * s, 4 * s)
      ..lineTo(16 * s, 20 * s)
      ..lineTo(10 * s, 14 * s)
      ..close();
    canvas.drawPath(plane, paint);

    final fold = Path()
      ..moveTo(10 * s, 14 * s)
      ..lineTo(9 * s, 19 * s)
      ..lineTo(12 * s, 16 * s)
      ..close();
    canvas.drawPath(fold, paint..color = color.withOpacity(0.6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
