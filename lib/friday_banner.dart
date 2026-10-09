import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Perşembe akşamından (akşam vakti) cuma ikindisine kadar ana ekranın üstünde gösterilen
/// "Hayırlı Cumalar" afişi. Oturum boyunca bir kez kapatılırsa uygulama yeniden açılana kadar çıkmaz.
class FridayBanner extends StatefulWidget {
  final String text;
  const FridayBanner({super.key, required this.text});

  static bool dismissedThisSession = false;

  /// [maghrib] ve [asr] bugünün vakitleridir.
  static bool isActive(DateTime now, DateTime maghrib, DateTime asr) {
    if (now.weekday == DateTime.thursday) return !now.isBefore(maghrib);
    if (now.weekday == DateTime.friday) return now.isBefore(asr);
    return false;
  }

  @override
  State<FridayBanner> createState() => _FridayBannerState();
}

class _FridayBannerState extends State<FridayBanner> {
  @override
  Widget build(BuildContext context) {
    if (FridayBanner.dismissedThisSession) return const SizedBox.shrink();
    const gold = Color(0xFFF1D58A);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      // Afişe dokunmak onu bu oturum için kapatır.
      child: GestureDetector(
        onTap: () => setState(() => FridayBanner.dismissedThisSession = true),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F4D3A),
                  Color(0xFF1B6B53),
                  Color(0xFF0F4D3A),
                ],
              ),
              border: Border.all(
                color: gold.withValues(alpha: 0.8),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _MotifPainter(gold)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 66),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.text,
                      style: const TextStyle(
                        color: gold,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MotifPainter extends CustomPainter {
  final Color color;
  _MotifPainter(this.color);

  Path _star(Offset c, double r, {int points = 8, double inner = 0.55}) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? r : r * inner;
      final a = -math.pi / 2 + i * math.pi / points;
      final p = Offset(
        c.dx + radius * math.cos(a),
        c.dy + radius * math.sin(a),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Path _crescent(Offset c, double r) {
    final outer = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: c.translate(r * 0.45, -r * 0.1),
          radius: r * 0.85,
        ),
      );
    return Path.combine(PathOperation.difference, outer, cut);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color.withValues(alpha: 0.9);
    final soft = Paint()..color = color.withValues(alpha: 0.28);
    final line = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final h = size.height;

    // Köşelerde hilal ve yıldız.
    canvas.drawPath(_crescent(Offset(22, h / 2), 13), fill);
    canvas.drawPath(
      _star(Offset(40, h / 2 - 8), 5, points: 5, inner: 0.45),
      fill,
    );
    canvas.save();
    canvas.translate(size.width, 0);
    canvas.scale(-1, 1);
    canvas.drawPath(_crescent(Offset(22, h / 2), 13), fill);
    canvas.drawPath(
      _star(Offset(40, h / 2 - 8), 5, points: 5, inner: 0.45),
      fill,
    );
    canvas.restore();

    // Arka planda yumuşak sekiz köşeli yıldız (selçuklu motifi) dizisi.
    final step = h * 0.9;
    for (var x = step / 2; x < size.width; x += step) {
      final c = Offset(x, h / 2);
      canvas.drawPath(_star(c, h * 0.42), line);
      canvas.drawPath(_star(c, 3.2, points: 4, inner: 0.4), soft);
    }
  }

  @override
  bool shouldRepaint(covariant _MotifPainter old) => old.color != color;
}
