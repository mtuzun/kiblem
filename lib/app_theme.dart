import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'figures.dart';
import 'l10n.dart';
import 'weather.dart';

// ---------------------------------------------------------------------------
// Tema: arka plan, sayaç stili ve vakit düzeni birlikte seçilir.
// ---------------------------------------------------------------------------

class AppTheme {
  final String id;
  final String tr;
  final String en;

  /// Aktif vakti vurgulayan renk.
  final Color accent;
  const AppTheme(this.id, this.tr, this.en, this.accent);
}

const List<AppTheme> appThemes = [
  AppTheme('classic', 'Klasik', 'Classic', Color(0xFF6DAF89)),
  AppTheme('leather', 'Deri', 'Leather', Color(0xFF1FA3B5)),
  AppTheme('ocean', 'Okyanus', 'Ocean', Color(0xFF7FE9F2)),
  AppTheme('night', 'Gece', 'Night', Color(0xFFE8C468)),
];

AppTheme appThemeById(String? id) =>
    appThemes.firstWhere((th) => th.id == id, orElse: () => appThemes.first);

final ValueNotifier<String> themeNotifier = ValueNotifier<String>('classic');

Future<void> setAppTheme(String id) async {
  themeNotifier.value = id;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('app_theme', id);
}

/// Ekrandaki verilerin anlık görüntüsü. Gerçek ana ekran ve tema önizlemesi
/// aynı görünümleri bununla çizer.
class PrayerEntry {
  final String name;
  final String time;
  final bool active;
  const PrayerEntry(this.name, this.time, this.active);
}

class HomeSnapshot {
  final String city;
  final String nextPrayerName;
  final String timeLeft; // SS:DD:ss
  final DateTime now;
  final List<PrayerEntry> prayers;
  const HomeSnapshot({
    required this.city,
    required this.nextPrayerName,
    required this.timeLeft,
    required this.now,
    required this.prayers,
  });

  String get clock =>
      "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  String get gregorian => "${now.day.toString().padLeft(2, '0')} ${longMonth(now.month)} ${now.year}";
  String get hijri => hijriDateString(now);
}

String _trUpper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

// --- arka planlar -----------------------------------------------------------

class ThemeBackground extends StatelessWidget {
  final AppTheme theme;
  final Widget child;
  const ThemeBackground({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    switch (theme.id) {
      case 'leather':
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.1,
              colors: [Color(0xFF254B45), Color(0xFF0D2320)],
            ),
          ),
          child: CustomPaint(painter: const _LeatherPainter(), child: child),
        );
      case 'ocean':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF187394), Color(0xFF105876)],
            ),
          ),
          child: child,
        );
      case 'night':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF09132B), Color(0xFF24326E)],
            ),
          ),
          child: CustomPaint(painter: const _StarsPainter(), child: child),
        );
      default:
        final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
        final hue = paletteById(colorThemeNotifier.value).hue ?? (dayOfYear * (360 / 365)) % 360;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          color: HSLColor.fromAHSL(1.0, hue, 0.4, isDark ? 0.28 : 0.6).toColor(),
          child: CustomPaint(painter: MotifPainter(dayOfYear), child: child),
        );
    }
  }
}

/// Deri doku: ince noktalar ve köşelerde laleler.
class _LeatherPainter extends CustomPainter {
  const _LeatherPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7);
    final dot = Paint();
    for (var i = 0; i < 900; i++) {
      dot.color = (rnd.nextBool() ? Colors.white : Colors.black).withValues(alpha: 0.03 + rnd.nextDouble() * 0.04);
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.6 + rnd.nextDouble() * 1.4,
        dot,
      );
    }

    // [center] lalenin merkezi; dönüş merkez etrafında olur.
    void tulip(Offset center, double s, double angle, Color color) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.translate(-s / 2, -s / 2);
      FigurePainter('tulip', color: color).paint(canvas, Size(s, s));
      canvas.restore();
    }

    const pink = Color(0xFFD9506B);
    const salmon = Color(0xFFE9967A);
    final w = size.width, h = size.height;
    tulip(Offset(w * .06, h * .90), w * .30, -0.55, salmon.withValues(alpha: .5));
    tulip(Offset(w * .20, h * .95), w * .36, 0.12, pink.withValues(alpha: .7));
    tulip(Offset(w * .94, h * .90), w * .30, 0.55, salmon.withValues(alpha: .5));
    tulip(Offset(w * .80, h * .95), w * .36, -0.12, pink.withValues(alpha: .7));
  }

  @override
  bool shouldRepaint(covariant _LeatherPainter old) => false;
}

/// Gece gökyüzü: dağınık küçük yıldızlar.
class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(3);
    final p = Paint();
    for (var i = 0; i < 90; i++) {
      p.color = Colors.white.withValues(alpha: 0.25 + rnd.nextDouble() * 0.6);
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.5 + rnd.nextDouble() * 1.5,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => false;
}

// --- sayaç ------------------------------------------------------------------

class DateChip extends StatelessWidget {
  final HomeSnapshot s;
  final bool fill;
  const DateChip(this.s, {super.key, this.fill = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: fill ? Colors.black.withValues(alpha: 0.35) : null,
        border: Border.all(color: Colors.white70, width: fill ? 2 : 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text("${s.gregorian}   ${s.hijri}", style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }
}

class CountdownView extends StatelessWidget {
  final AppTheme theme;
  final HomeSnapshot s;
  const CountdownView({super.key, required this.theme, required this.s});

  List<String> get _parts {
    final p = s.timeLeft.split(':');
    return p.length == 3 ? p : ['00', '00', '00'];
  }

  String get _label => t("${s.nextPrayerName} vaktine kalan süre", "Time until ${s.nextPrayerName}");

  @override
  Widget build(BuildContext context) {
    switch (theme.id) {
      case 'leather':
        return _flip();
      case 'ocean':
        return _thin();
      default:
        return _classic();
    }
  }

  Widget _classic() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(_label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  s.timeLeft,
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(s.clock, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        DateChip(s),
      ],
    );
  }

  Widget _flipBox(String digits, String caption) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(digits, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.0)),
          ),
          Text(caption, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _flip() {
    final p = _parts;
    return Column(
      children: [
        Text(_label, style: const TextStyle(color: Colors.white, fontSize: 15)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _flipBox(p[0], t("saat", "hr")),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(":", style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
            ),
            _flipBox(p[1], t("dk", "min")),
          ],
        ),
        const SizedBox(height: 14),
        DateChip(s, fill: true),
      ],
    );
  }

  Widget _thin() {
    final p = _parts;
    return Column(
      children: [
        Text(_label, style: const TextStyle(color: Colors.white, fontSize: 18)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("${p[0]}:${p[1]}:",
                  style: const TextStyle(color: Colors.white, fontSize: 92, fontWeight: FontWeight.w200, height: 1.1)),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(p[2], style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w300)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text("${s.gregorian} - ${s.hijri}", style: const TextStyle(color: Colors.white, fontSize: 15)),
      ],
    );
  }
}

// --- vakitler ---------------------------------------------------------------

class PrayerTimesView extends StatelessWidget {
  final AppTheme theme;
  final HomeSnapshot s;
  const PrayerTimesView({super.key, required this.theme, required this.s});

  @override
  Widget build(BuildContext context) {
    switch (theme.id) {
      case 'leather':
        return _grid();
      case 'ocean':
        return _text();
      default:
        return _row();
    }
  }

  Widget _card(PrayerEntry e, {required double nameSize, required double timeSize, required double vPad}) {
    final active = e.active;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: EdgeInsets.symmetric(vertical: vPad),
      decoration: BoxDecoration(
        color: active ? theme.accent : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              e.name,
              style: TextStyle(
                fontSize: nameSize,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              e.time,
              style: TextStyle(
                fontSize: timeSize,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final e in s.prayers) Expanded(child: _card(e, nameSize: 13, timeSize: 15, vPad: 10)),
        ],
      ),
    );
  }

  Widget _grid() {
    Widget line(List<PrayerEntry> items) => Row(
          children: [
            for (final e in items) Expanded(child: _card(e, nameSize: 20, timeSize: 26, vPad: 16)),
          ],
        );
    final p = s.prayers;
    if (p.length < 6) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          line(p.sublist(0, 3)),
          const SizedBox(height: 8),
          line(p.sublist(3, 6)),
        ],
      ),
    );
  }

  Widget _text() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (final e in s.prayers)
            Expanded(
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _trUpper(e.name),
                      style: TextStyle(fontSize: 14, color: e.active ? theme.accent : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      e.time,
                      style: TextStyle(fontSize: 22, color: e.active ? theme.accent : Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// --- tema seçici ------------------------------------------------------------

class ThemePickerScreen extends StatefulWidget {
  final HomeSnapshot snapshot;
  const ThemePickerScreen({super.key, required this.snapshot});

  @override
  State<ThemePickerScreen> createState() => _ThemePickerScreenState();
}

class _ThemePickerScreenState extends State<ThemePickerScreen> {
  late int _index;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _index = appThemes.indexWhere((th) => th.id == themeNotifier.value).clamp(0, appThemes.length - 1);
    _controller = PageController(initialPage: _index, viewportFraction: 0.86);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _preview(AppTheme theme) {
    final s = widget.snapshot;
    final content = SizedBox(
      width: 360,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: 130,
            child: Opacity(
              opacity: 0.2,
              child: CustomPaint(size: const Size(150, 150), painter: FigurePainter(figureNotifier.value)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.city, style: const TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Align(alignment: Alignment.centerRight, child: WeatherStrip(theme: theme))),
                  ],
                ),
                const SizedBox(height: 20),
                CountdownView(theme: theme, s: s),
                const SizedBox(height: 20),
                PrayerTimesView(theme: theme, s: s),
                const SizedBox(height: 16),
                // Ana ekranın alt kısmını anımsatan sade örnek içerik.
                Row(
                  children: [
                    for (final label in [t("Ayet-i Kerime", "Verse"), t("Vaktin Hadisi", "Hadith")])
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ThemeBackground(
          theme: theme,
          child: IgnorePointer(
            child: FittedBox(fit: BoxFit.fitWidth, alignment: Alignment.topCenter, child: content),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const teal = Color(0xFF2EB8A6);
    return Scaffold(
      backgroundColor: cs.surfaceContainerHighest,
      appBar: AppBar(title: Text(t("Tema", "Theme")), backgroundColor: cs.surface),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: appThemes.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _preview(appThemes[i]),
            ),
          ),
          Material(
            color: cs.surface,
            child: SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: appThemes.length,
                itemBuilder: (context, i) {
                  final selected = i == _index;
                  return InkWell(
                    onTap: () => _controller.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      color: selected ? teal : null,
                      child: Text(
                        _trUpper(t(appThemes[i].tr, appThemes[i].en)),
                        style: TextStyle(
                          fontSize: 16,
                          color: selected ? Colors.white : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            color: cs.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: 220,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF229BA6)),
                  onPressed: () async {
                    await setAppTheme(appThemes[_index].id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(t("AYARLA", "APPLY"), style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Klasik tema: renk paleti ve arka plan deseni.
// ---------------------------------------------------------------------------

/// Renk paleti: [hue] null ise günlük değişen otomatik renk kullanılır.
class AppPalette {
  final String id;
  final String tr;
  final String en;
  final double? hue;
  const AppPalette(this.id, this.tr, this.en, this.hue);

  Color get swatch => HSLColor.fromAHSL(1.0, hue ?? 0, hue == null ? 0.0 : 0.4, 0.55).toColor();
}

const List<AppPalette> appPalettes = [
  AppPalette('auto', 'Otomatik', 'Automatic', null),
  AppPalette('purple', 'Mor', 'Purple', 280),
  AppPalette('green', 'Yeşil', 'Green', 140),
  AppPalette('blue', 'Mavi', 'Blue', 210),
  AppPalette('navy', 'Lacivert', 'Navy', 235),
  AppPalette('orange', 'Turuncu', 'Orange', 25),
  AppPalette('rose', 'Gül', 'Rose', 335),
];

AppPalette paletteById(String? id) =>
    appPalettes.firstWhere((p) => p.id == id, orElse: () => appPalettes.first);

final ValueNotifier<String> colorThemeNotifier = ValueNotifier<String>('auto');
final ValueNotifier<String> figureNotifier = ValueNotifier<String>('mosque');

Future<void> setColorTheme(String id) async {
  colorThemeNotifier.value = id;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('color_theme', id);
}

Future<void> setFigure(String id) async {
  figureNotifier.value = id;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('app_figure', id);
}


class MotifPainter extends CustomPainter {
  final int dayOfYear;
  MotifPainter(this.dayOfYear);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.8;

    final numPoints = 4 + (dayOfYear % 8); 
    final rotationSteps = 3 + (dayOfYear % 6);

    for (int r = 0; r < rotationSteps; r++) {
      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate((pi / rotationSteps) * r + (dayOfYear * 0.01));
      
      final path = Path();
      for (int i = 0; i < numPoints; i++) {
        final angle = (2 * pi / numPoints) * i;
        final x = cos(angle) * radius;
        final y = sin(angle) * radius;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
      
      canvas.drawCircle(Offset.zero, radius * 0.5, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MotifPainter oldDelegate) {
    return oldDelegate.dayOfYear != dayOfYear;
  }
}

