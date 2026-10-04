import 'dart:math' show pi, sin, cos;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'l10n.dart';
import 'qibla_geometry.dart';

class QiblaCompass extends StatelessWidget {
  const QiblaCompass({
    super.key,
    this.stream,
    this.reliable = true,
    this.initialDirection,
  });
  final bool reliable;
  final QiblahDirection? initialDirection;

  /// Yalnızca mağaza ekran görüntüsü aracı içindir; normalde cihaz pusulası kullanılır.
  final Stream<QiblahDirection>? stream;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder(
      stream: stream ?? FlutterQiblah.qiblahStream,
      initialData: initialDirection,
      builder: (_, AsyncSnapshot<QiblahDirection> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_disabled,
                    size: 56,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t(
                      "Konumuna ulaşamadık. Konum servisinin açık olduğundan emin olup tekrar dener misin?",
                      "We couldn't get your location. Please make sure location services are on and try again.",
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Text(
              t(
                "Pusula sensörü verisi bekleniyor. (Konumun açık olduğundan emin olun.)",
                "Waiting for compass sensor data. (Make sure location is turned on.)",
              ),
            ),
          );
        }

        final qiblahDirection = snapshot.data!;

        // qiblahDirection.qiblah = heading - offset (mod 360): how far the
        // Kaaba marker sits from the device's current heading, measured the
        // opposite way round from the compass ring's own rotation. Negating
        // it here keeps both rotations in the same clockwise convention, so
        // the marker lands at the Kaaba's true screen position instead of
        // its mirror image.
        final markerAngle = qiblahDirection.qiblah * (pi / 180) * -1;

        // Signed remaining angle to rotate to face the Kaaba exactly, in (-180, 180].
        final remaining = signedQiblaTurn(
          qiblahDirection.direction,
          qiblahDirection.offset,
        );
        final isAligned = remaining.abs() <= 3 && reliable;

        return LayoutBuilder(
          builder: (context, constraints) {
            final dialSize = constraints.maxWidth.clamp(0.0, 300.0);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isAligned
                          ? (isDark
                                ? Colors.green.shade300
                                : Colors.green.shade700)
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                    child: Text(
                      !reliable
                          ? t('Pusulayı kalibre edin', 'Calibrate the compass')
                          : isAligned
                          ? t("Kıbleyi Buldunuz!", "You are facing the Qibla!")
                          : t(
                              "Kıbleye dönmek için ${remaining.abs().toStringAsFixed(0)}° ${remaining > 0 ? 'sağa' : 'sola'} çevirin",
                              "Turn ${remaining.abs().toStringAsFixed(0)}° to the ${remaining > 0 ? 'right' : 'left'} to face the Qibla",
                            ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      "Kıble, kuzeyden ${qiblahDirection.offset.toStringAsFixed(1)}° yönünde",
                      "Qibla is ${qiblahDirection.offset.toStringAsFixed(1)}° from north",
                    ),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background container just for aesthetics
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: dialSize,
                        height: dialSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAligned
                              ? Colors.green.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.2),
                          border: isAligned
                              ? Border.all(color: Colors.green, width: 3)
                              : null,
                        ),
                      ),
                      // Dial with directions
                      Transform.rotate(
                        angle: (qiblahDirection.direction * (pi / 180) * -1),
                        child: CustomPaint(
                          size: Size(dialSize, dialSize),
                          painter: CompassRingPainter(isDark: isDark),
                        ),
                      ),
                      // Kaaba Indicator
                      Transform.rotate(
                        angle: markerAngle,
                        child: Container(
                          width: dialSize,
                          height: dialSize,
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Icon(
                              Icons.mosque,
                              size: isAligned ? 58 : 50,
                              color: isAligned
                                  ? Colors.amber.shade700
                                  : Colors.green,
                            ),
                          ),
                        ),
                      ),
                      // Phone heading indicator (fixed at top)
                      Positioned(
                        top: -15,
                        child: Icon(
                          Icons.arrow_drop_up,
                          size: 40,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Icon(
                        Icons.fiber_manual_record,
                        size: 15,
                        color: isAligned ? Colors.amber.shade700 : Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    t(
                      "Pusulayı hizalamak için cihazınızı uzak tutun ve yatay çevirin.",
                      "To align the compass, hold your device flat and away from metal objects.",
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class CompassRingPainter extends CustomPainter {
  final bool isDark;
  const CompassRingPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = isDark ? Colors.green.shade400 : Colors.green.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - ringPaint.strokeWidth / 2, ringPaint);

    final tickPaint = Paint()
      ..color = (isDark ? Colors.green.shade300 : Colors.green.shade900)
      ..strokeWidth = 2;
    for (int i = 0; i < 360; i += 45) {
      if (i % 90 != 0) {
        final angle = i * pi / 180;
        final outer = Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        );
        final inner = Offset(
          center.dx + (radius - 12) * cos(angle),
          center.dy + (radius - 12) * sin(angle),
        );
        canvas.drawLine(inner, outer, tickPaint);
      }
    }

    final textStyle = TextStyle(
      color: isDark ? Colors.white : Colors.black87,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    );
    _drawText(canvas, t("K", "N"), center, Offset(0, -radius + 25), textStyle);
    _drawText(canvas, t("G", "S"), center, Offset(0, radius - 25), textStyle);
    _drawText(canvas, t("D", "E"), center, Offset(radius - 25, 0), textStyle);
    _drawText(canvas, t("B", "W"), center, Offset(-radius + 25, 0), textStyle);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    Offset offset,
    TextStyle style,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    canvas.save();
    canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CompassRingPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
