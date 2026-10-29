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

  // Deri temasında "saat" / "dk" yazısı rakamın yanında durmalı ve sayaç bloğu alçak kalmalı;
  // yoksa ana ekranın alt kısmındaki ayrıntılar ekrana sığmaz.
  testWidgets('leather sayaç kutuları: yazı rakamın yanında, blok alçak', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final snapshot = HomeSnapshot(
      city: 'İstanbul',
      nextPrayerName: 'Akşam',
      timeLeft: '02:08:30',
      now: DateTime(2026, 10, 18, 10, 45),
      prayers: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              child: CountdownView(theme: appThemeById('leather'), s: snapshot, onDateTap: () {}),
            ),
          ),
        ),
      ),
    );

    final digits = tester.getRect(find.text('02'));
    final caption = tester.getRect(find.text('saat'));
    expect(caption.left, greaterThanOrEqualTo(digits.right), reason: 'yazı rakamın sağında olmalı');
    expect((caption.bottom - digits.bottom).abs(), lessThan(12), reason: 'yazı rakamla aynı satırda olmalı');
    final label = tester.getRect(find.text('Akşam vaktine kalan süre'));
    final chip = tester.getRect(find.byType(DateChip));
    expect(chip.bottom - label.top, lessThan(150), reason: 'etiketten tarih kutusunun altına kadar yükseklik');
  });

  // Klasik ve Gece: altı kart rahat sığıyorsa tek satır, sığmıyorsa (dar ekran / büyük yazı) 3'erli iki satır.
  for (final themeId in ['classic', 'night']) {
    for (final c in [(412.0, 1.0, 1), (320.0, 1.0, 2), (360.0, 1.3, 2), (360.0, 2.0, 2)]) {
      testWidgets('$themeId vakit kartları ${c.$3} satır: ${c.$1}dp, yazı x${c.$2}', (tester) async {
        tester.view.physicalSize = Size(c.$1 * 2, 1600);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(c.$2)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: PrayerTimesView(theme: appThemeById(themeId), s: _snapshot()),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final rows = {
          for (final e in _snapshot().prayers) tester.getRect(find.text(e.time)).center.dy.round() ~/ 10,
        };
        expect(rows.length, c.$3);
      });
    }
  }

  // Büyütülmüş yazıda vakit bloğu ekranı doldurmamalı: altı vakit en çok iki satıra sığar.
  for (final themeId in ['ocean', 'black']) {
    for (final scale in [1.6, 2.0]) {
      testWidgets('$themeId vakit bloğu alçak kalır: 360dp, yazı x$scale', (tester) async {
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: PrayerTimesView(theme: appThemeById(themeId), s: _snapshot()),
              ),
            ),
          ),
        );
        final rows = {
          for (final e in _snapshot().prayers) tester.getRect(find.text(e.time)).center.dy.round() ~/ 10,
        };
        expect(rows.length, lessThanOrEqualTo(2), reason: 'en çok iki satır');
      });
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
