import 'dart:math';

import 'package:flutter/material.dart';

/// Başlıktaki dekoratif figürler. Hepsi 0..1 birim karede çizilir, tek renkli
/// (şeffaflık üst widget'tan gelir). Oyuklar `BlendMode.clear` ile açılır.
class AppFigure {
  final String id;
  final String tr;
  final String en;
  const AppFigure(this.id, this.tr, this.en);
}

const List<AppFigure> appFigures = [
  AppFigure('mosque', 'Cami', 'Mosque'),
  AppFigure('crescent_star', 'Hilal ve Yıldız', 'Crescent & Star'),
  AppFigure('kaaba', 'Kâbe', 'Kaaba'),
  AppFigure('star8', 'Selçuklu Yıldızı', 'Seljuk Star'),
  AppFigure('lantern', 'Kandil', 'Lantern'),
  AppFigure('tulip', 'Lale', 'Tulip'),
  AppFigure('none', 'Yok', 'None'),
];

AppFigure figureById(String? id) =>
    appFigures.firstWhere((f) => f.id == id, orElse: () => appFigures.first);

class FigurePainter extends CustomPainter {
  final String id;
  final Color color;
  const FigurePainter(this.id, {this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    if (id == 'none') return;
    final fill = Paint()..color = color;
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.saveLayer(Offset.zero & size, Paint());
    switch (id) {
      case 'mosque':
        _mosque(canvas, size, fill, clear);
      case 'crescent_star':
        _crescentStar(canvas, size, fill, clear);
      case 'kaaba':
        _kaaba(canvas, size, fill, clear);
      case 'star8':
        _star8(canvas, size, fill, clear);
      case 'lantern':
        _lantern(canvas, size, fill, clear);
      case 'tulip':
        _tulip(canvas, size, fill, clear);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FigurePainter old) => old.id != id || old.color != color;

  // --- yardımcılar ---------------------------------------------------------

  Rect _r(Size s, double l, double t, double r, double b) =>
      Rect.fromLTRB(l * s.width, t * s.height, r * s.width, b * s.height);

  /// Üstü yarım daire olan kemer: [l,r] genişlik, [top,bottom] yükseklik.
  void _arch(Canvas c, Size s, double l, double top, double r, double bottom, Paint p) {
    final half = (r - l) / 2;
    c.drawRect(_r(s, l, top + half * s.width / s.height, r, bottom), p);
    c.drawArc(_r(s, l, top, r, top + 2 * half * s.width / s.height), pi, pi, true, p);
  }

  Path _poly(Size s, List<double> pts) {
    final p = Path();
    for (var i = 0; i < pts.length; i += 2) {
      final o = Offset(pts[i] * s.width, pts[i + 1] * s.height);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  Path _starPath(Offset center, double outer, double inner, int points, {double rotation = -pi / 2}) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = rotation + i * pi / points;
      final o = Offset(center.dx + cos(a) * r, center.dy + sin(a) * r);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  // --- figürler ------------------------------------------------------------

  void _mosque(Canvas c, Size s, Paint fill, Paint clear) {
    // Gövde, ana kubbe ve yan kubbeler.
    c.drawRect(_r(s, .16, .64, .84, 1.0), fill);
    c.drawArc(_r(s, .28, .34, .72, .94), pi, pi, true, fill);
    c.drawArc(_r(s, .15, .56, .37, .72), pi, pi, true, fill);
    c.drawArc(_r(s, .63, .56, .85, .72), pi, pi, true, fill);
    // Ana kubbe alemi.
    c.drawRect(_r(s, .488, .20, .512, .35), fill);
    c.drawCircle(Offset(.5 * s.width, .185 * s.height), .022 * s.width, fill);
    // İki minare: gövde, şerefe, külah ve alem.
    for (final x in [.07, .93]) {
      c.drawRect(_r(s, x - .027, .36, x + .027, 1.0), fill);
      c.drawRect(_r(s, x - .05, .46, x + .05, .495), fill);
      c.drawPath(_poly(s, [x - .04, .36, x, .15, x + .04, .36]), fill);
      c.drawCircle(Offset(x * s.width, .13 * s.height), .014 * s.width, fill);
    }
    // Kapı ve pencereler.
    _arch(c, s, .44, .78, .56, 1.0, clear);
    _arch(c, s, .25, .82, .31, .94, clear);
    _arch(c, s, .69, .82, .75, .94, clear);
    // Şerit: kubbe ile gövde arasında ince ayrım.
    c.drawRect(_r(s, .16, .635, .84, .650), clear);
  }

  void _crescentStar(Canvas c, Size s, Paint fill, Paint clear) {
    final w = s.width, h = s.height;
    // Hilal.
    c.drawCircle(Offset(.45 * w, .54 * h), .34 * w, fill);
    c.drawCircle(Offset(.58 * w, .47 * h), .28 * w, clear);
    // Hilalin ağzındaki yıldız.
    c.drawPath(_starPath(Offset(.66 * w, .44 * h), .11 * w, .045 * w, 5), fill);
    // Küçük parıltılar.
    void sparkle(double x, double y, double r) =>
        c.drawPath(_starPath(Offset(x * w, y * h), r * w, r * .3 * w, 4), fill);
    sparkle(.20, .18, .06);
    sparkle(.80, .16, .045);
    sparkle(.86, .66, .05);
    sparkle(.22, .86, .04);
    sparkle(.62, .84, .03);
  }

  void _kaaba(Canvas c, Size s, Paint fill, Paint clear) {
    // Üç yüz: ön, yan, üst — farklı yoğunluklarla derinlik verir.
    final front = Paint()..color = fill.color;
    final side = Paint()..color = fill.color.withValues(alpha: fill.color.a * .72);
    final top = Paint()..color = fill.color.withValues(alpha: fill.color.a * .5);
    c.drawPath(_poly(s, [.14, .40, .64, .40, .64, .92, .14, .92]), front);
    c.drawPath(_poly(s, [.64, .40, .86, .31, .86, .83, .64, .92]), side);
    c.drawPath(_poly(s, [.14, .40, .36, .31, .86, .31, .64, .40]), top);
    // Altın kuşak (kiswa şeridi): ön ve yan yüzde ince boşluklarla.
    for (final y in [.50, .56]) {
      c.drawRect(_r(s, .14, y, .64, y + .012), clear);
      c.drawPath(_poly(s, [.64, y, .86, y - .09, .86, y - .078, .64, y + .012]), clear);
    }
    // Kapı (yan yüzde yüksekte).
    c.drawPath(_poly(s, [.70, .66, .78, .63, .78, .78, .70, .81]), clear);
  }

  void _star8(Canvas c, Size s, Paint fill, Paint clear) {
    final center = Offset(.5 * s.width, .5 * s.height);
    final r = .44 * s.width;
    final inner = r * cos(pi / 4) / cos(pi / 8);
    // Dış halka.
    c.drawCircle(center, r + .04 * s.width, fill);
    c.drawCircle(center, r + .01 * s.width, clear);
    // Sekiz köşeli yıldız (iki kare) ve içinde ikinci, küçük yıldız.
    c.drawPath(_starPath(center, r, inner, 8), fill);
    c.drawPath(_starPath(center, r * .62, inner * .62, 8, rotation: -pi / 2 + pi / 8), clear);
    c.drawPath(_starPath(center, r * .44, inner * .44, 8, rotation: -pi / 2 + pi / 8), fill);
    c.drawCircle(center, r * .14, clear);
  }

  void _lantern(Canvas c, Size s, Paint fill, Paint clear) {
    final w = s.width, h = s.height;
    // Asma halkası ve kapak.
    c.drawArc(_r(s, .40, .04, .60, .26), pi, pi, false,
        Paint()..color = fill.color..style = PaintingStyle.stroke..strokeWidth = .022 * w);
    c.drawCircle(Offset(.5 * w, .27 * h), .03 * w, fill);
    c.drawPath(_poly(s, [.43, .26, .57, .26, .66, .36, .34, .36]), fill);
    // Gövde.
    final body = Path()
      ..moveTo(.34 * w, .38 * h)
      ..cubicTo(.24 * w, .50 * h, .24 * w, .64 * h, .34 * w, .76 * h)
      ..lineTo(.66 * w, .76 * h)
      ..cubicTo(.76 * w, .64 * h, .76 * w, .50 * h, .66 * w, .38 * h)
      ..close();
    c.drawPath(body, fill);
    // Cam kısmı ve içindeki alev.
    final glass = Path()
      ..moveTo(.42 * w, .44 * h)
      ..cubicTo(.35 * w, .53 * h, .35 * w, .62 * h, .42 * w, .70 * h)
      ..lineTo(.58 * w, .70 * h)
      ..cubicTo(.65 * w, .62 * h, .65 * w, .53 * h, .58 * w, .44 * h)
      ..close();
    c.drawPath(glass, clear);
    final flame = Path()
      ..moveTo(.5 * w, .49 * h)
      ..quadraticBezierTo(.56 * w, .59 * h, .5 * w, .66 * h)
      ..quadraticBezierTo(.44 * w, .59 * h, .5 * w, .49 * h);
    c.drawPath(flame, fill);
    // Taban ve püskül.
    c.drawPath(_poly(s, [.36, .76, .64, .76, .60, .84, .40, .84]), fill);
    c.drawRect(_r(s, .488, .84, .512, .93), fill);
    c.drawCircle(Offset(.5 * w, .95 * h), .028 * w, fill);
  }

  void _tulip(Canvas c, Size s, Paint fill, Paint clear) {
    final w = s.width, h = s.height;
    Path petal(bool right) {
      double x(double v) => (right ? 1 - v : v) * w;
      return Path()
        ..moveTo(x(.24), .20 * h)
        ..cubicTo(x(.36), .28 * h, x(.47), .44 * h, x(.50), .66 * h)
        ..cubicTo(x(.30), .68 * h, x(.20), .46 * h, x(.24), .20 * h)
        ..close();
    }

    Path leaf(bool right) {
      double x(double v) => (right ? 1 - v : v) * w;
      return Path()
        ..moveTo(x(.49), .93 * h)
        ..cubicTo(x(.30), .93 * h, x(.20), .80 * h, x(.17), .62 * h)
        ..cubicTo(x(.32), .70 * h, x(.45), .78 * h, x(.49), .84 * h)
        ..close();
    }

    c.drawPath(petal(false), fill);
    c.drawPath(petal(true), fill);
    // Orta taç yaprak: yan yapraklardan ince bir boşlukla ayrılır.
    final center = Path()
      ..moveTo(.5 * w, .12 * h)
      ..cubicTo(.64 * w, .26 * h, .66 * w, .50 * h, .5 * w, .70 * h)
      ..cubicTo(.34 * w, .50 * h, .36 * w, .26 * h, .5 * w, .12 * h)
      ..close();
    c.drawPath(center, Paint()..blendMode = BlendMode.clear..style = PaintingStyle.stroke..strokeWidth = .03 * w);
    c.drawPath(center, fill);
    // Sap ve yapraklar.
    c.drawRect(_r(s, .485, .68, .515, .94), fill);
    c.drawPath(leaf(false), fill);
    c.drawPath(leaf(true), fill);
  }
}
