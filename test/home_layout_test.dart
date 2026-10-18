import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiblem/app_theme.dart';

/// Ana ekranın sayaç ve vakit bölümlerinin dar ekran ve büyük yazı ayarlarında
/// taşmadığını doğrular (taşma, Flutter'da test sırasında istisna olarak yakalanır).
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
  final file = File(
    '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  );
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

HomeSnapshot _snapshot() => HomeSnapshot(
  city: 'İstanbul',
  nextPrayerName: 'Akşam',
  timeLeft: '12:34:56',
  now: DateTime(2026, 10, 18, 10, 45),
  prayers: const [
    PrayerEntry('İmsak', '05:47', false),
    PrayerEntry('Güneş', '07:12', true),
    PrayerEntry('Öğle', '12:54', false),
    PrayerEntry('İkindi', '15:54', false),
    PrayerEntry('Akşam', '18:26', false),
    PrayerEntry('Yatsı', '19:45', false),
  ],
);

void main() {
  setUpAll(_loadRoboto);

  for (final theme in appThemes) {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3, 1.6, 2.0]) {
        testWidgets('${theme.id} sığar: ${width}dp, yazı x$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width * 2, 1600);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'Roboto'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: CountdownView(
                            theme: theme,
                            s: _snapshot(),
                            onDateTap: () {},
                          ),
                        ),
                        const SizedBox(height: 20),
                        PrayerTimesView(theme: theme, s: _snapshot()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  // Vakitleri düz metin olarak sıralayan temalarda (Okyanus, Siyah) vakitler dar alanda tek tek
  // küçülüp birbirine yapışmamalı.
  for (final themeId in ['ocean', 'black']) {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3, 1.6, 2.0]) {
        testWidgets(
          '$themeId vakitleri birbirine yapışmaz: ${width}dp, yazı x$scale',
          (tester) async {
            tester.view.physicalSize = Size(width * 2, 1600);
            tester.view.devicePixelRatio = 2;
            addTearDown(tester.view.reset);

            final theme = appThemeById(themeId);
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(fontFamily: 'Roboto'),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: PrayerTimesView(theme: theme, s: _snapshot()),
                  ),
                ),
              ),
            );
            final prayers = _snapshot().prayers;
            final rects = [
              for (final e in prayers) tester.getRect(find.text(e.time)),
            ];
            for (var i = 0; i < rects.length; i++) {
              for (var j = i + 1; j < rects.length; j++) {
                // Farklı satırdaki vakitler karşılaştırılmaz.
                if ((rects[i].center.dy - rects[j].center.dy).abs() >= 4) {
                  continue;
                }
                final gap = rects[i].left < rects[j].left
                    ? rects[j].left - rects[i].right
                    : rects[i].left - rects[j].right;
                expect(
                  gap,
                  greaterThanOrEqualTo(4),
                  reason:
                      '${prayers[i].time} ile ${prayers[j].time} arası boşluk',
                );
              }
            }
          },
        );
      }
    }
  }
}
