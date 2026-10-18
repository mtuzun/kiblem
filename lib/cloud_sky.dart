import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Gökyüzü temasının arka planı: üst kısımda yavaşça kayan, yumuşak ve bulanık bulutlar
/// (uçak penceresinden bakış gibi). Üç katman farklı hızda ilerler; bulutlar aşağı doğru
/// silinir. Sistemde animasyonlar kapalıysa bulutlar durağan çizilir; sayfa ekranda
/// değilken (başka ekran üstündeyken) Flutter ticker'ı kendiliğinden durdurur.
class CloudSky extends StatefulWidget {
  final Widget child;
  const CloudSky({super.key, required this.child});

  @override
  State<CloudSky> createState() => _CloudSkyState();
}

class _CloudSkyState extends State<CloudSky> with SingleTickerProviderStateMixin {
  // Pil için saniyede en çok ~24 kare çizilir; bulutlar zaten çok yavaş hareket eder.
  static const _frame = Duration(milliseconds: 42);

  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (elapsed - _last < _frame) return;
      _last = elapsed;
      _seconds.value = elapsed.inMicroseconds / 1e6;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _ticker.stop();
      _seconds.value = 0;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(painter: CloudPainter(_seconds)),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Bir bulut: üst üste binen birkaç kabarıktan oluşur (kümülüs görünümü); altında koyu bir
/// gölge çizilir. Ölçüler 390dp genişlik içindir.
class _Cloud {
  final double x; // 0..1, yatay başlangıç konumu
  final double y; // 0..1, bulut bandı içindeki konum
  final double speed; // dp/saniye
  final double alpha;
  final double baseRadius;
  final double width;
  final List<({double dx, double dy, double r})> puffs;
  const _Cloud(this.x, this.y, this.speed, this.alpha, this.baseRadius, this.width, this.puffs);
}

/// Konumlar sabit tohumla üretilir ki her açılışta aynı gökyüzü çıksın.
List<_Cloud> _makeClouds() {
  final rnd = Random(11);
  final out = <_Cloud>[];
  // (adet, genişlik, kabarık yarıçapı, alfa, hız): arkadaki büyük ve yavaş, öndeki küçük ve hızlı.
  const layers = [
    (5, 380.0, 70.0, 0.34, 6.0),
    (5, 280.0, 52.0, 0.44, 12.0),
    (4, 200.0, 38.0, 0.52, 20.0),
  ];
  for (final (count, width, baseR, alpha, speed) in layers) {
    for (var i = 0; i < count; i++) {
      final puffs = <({double dx, double dy, double r})>[];
      for (var k = 0; k < 6; k++) {
        final t = (k / 5) * 2 - 1; // -1..1: bulutun solundan sağına
        final r = baseR * (1.15 - 0.5 * t.abs()) * (0.8 + rnd.nextDouble() * 0.35);
        puffs.add((dx: t * width / 2, dy: -rnd.nextDouble() * r * 0.35, r: r));
      }
      out.add(_Cloud(rnd.nextDouble(), rnd.nextDouble(), speed, alpha, baseR, width, puffs));
    }
  }
  return out;
}

final List<_Cloud> _clouds = _makeClouds();

const _lightCloud = Color(0xFFE3EDF8);
const _shadowCloud = Color(0xFF0E2038);

class CloudPainter extends CustomPainter {
  final ValueListenable<double> seconds;
  CloudPainter(this.seconds) : super(repaint: seconds);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Büyük ekranlarda bulutlar sonsuz büyümesin; bunun yerine daha çok bulut çizilir.
    final scale = min(size.width / 390, 1.5);
    final repeats = min(2, max(1, (size.width / (420 * scale)).round()));
    final bandHeight = min(size.height * 0.5, 480 * scale);
    final t = seconds.value;
    final margin = 220 * scale;
    final span = size.width + 2 * margin;
    for (var rep = 0; rep < repeats; rep++) {
      for (final c in _clouds) {
        final fx = (c.x + rep * 0.618) % 1.0;
        // Bulutlar sağdan sola kayar (Dart'ta % her zaman 0 ya da pozitif döner, sarma güvenli).
        final x = ((fx * span - c.speed * scale * t) % span) - margin;
        final y = c.y * bandHeight;
        // Bandın altına doğru bulutlar silinir.
        final fade = pow(1 - (y / bandHeight), 1.3).toDouble();
        if (fade <= 0.02) continue;
        final blur = c.baseRadius * scale * 0.3;
        final shadow = Paint()
          ..color = _shadowCloud.withValues(alpha: c.alpha * 0.9 * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 1.2);
        final light = Paint()
          ..color = _lightCloud.withValues(alpha: c.alpha * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
        // Altta tek bir geniş gölge, üstünde kabarıklar.
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, y + c.baseRadius * scale * 0.55),
            width: c.width * scale,
            height: c.baseRadius * scale * 1.1,
          ),
          shadow,
        );
        for (final p in c.puffs) {
          canvas.drawCircle(Offset(x + p.dx * scale, y + p.dy * scale), p.r * scale, light);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CloudPainter old) => old.seconds != seconds;
}
