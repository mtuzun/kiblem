import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiblem/prayer_method.dart';

PrayerTimes _times(CalculationParameters params, Coordinates c) =>
    PrayerTimes(c, DateComponents(2026, 11, 1), params);

void main() {
  final istanbul = Coordinates(41.0082, 28.9784);
  final jakarta = Coordinates(-6.2088, 106.8456);

  setUp(() {
    calcMethodNotifier.value = 'auto';
    asrMadhabNotifier.value = 'auto';
    calcCountryNotifier.value = 'TR';
  });

  test('varsayılan hesap: Diyanet açıları ve Hanefi ikindi', () {
    final expected = CalculationMethod.turkey.getParameters()..madhab = Madhab.hanafi;
    final a = _times(expected, istanbul);
    final b = _times(buildPrayerParams(), istanbul);
    for (final p in [Prayer.fajr, Prayer.sunrise, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha]) {
      expect(b.timeForPrayer(p), a.timeForPrayer(p), reason: p.name);
    }
  });

  test('Standart ikindi seçilince vakitler Diyanet takvimiyle aynı eski hesaba döner', () {
    asrMadhabNotifier.value = 'standard';
    final diyanet = _times(CalculationMethod.turkey.getParameters()..madhab = Madhab.shafi, istanbul);
    final b = _times(buildPrayerParams(), istanbul);
    for (final p in [Prayer.fajr, Prayer.sunrise, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha]) {
      expect(b.timeForPrayer(p), diyanet.timeForPrayer(p), reason: p.name);
    }
  });

  test('Otomatik yöntem ülkeye göre çözülür', () {
    expect(autoMethodIdForCountry('TR'), 'turkey');
    expect(autoMethodIdForCountry('sa'), 'umm_al_qura');
    expect(autoMethodIdForCountry('AE'), 'dubai');
    expect(autoMethodIdForCountry('US'), 'north_america');
    expect(autoMethodIdForCountry('PK'), 'karachi');
    expect(autoMethodIdForCountry('ID'), 'indonesia');
    expect(autoMethodIdForCountry('DE'), 'muslim_world_league');
    expect(autoMethodIdForCountry(null), 'muslim_world_league');

    calcCountryNotifier.value = 'SA';
    expect(resolvedMethod().id, 'umm_al_qura');
    calcCountryNotifier.value = null;
    expect(resolvedMethod().id, 'muslim_world_league');
  });

  test('Elle seçilen yöntem Otomatik olanı geçersiz kılar', () {
    calcCountryNotifier.value = 'SA';
    calcMethodNotifier.value = 'egyptian';
    expect(resolvedMethod().id, 'egyptian');
    expect(buildPrayerParams().fajrAngle, 19.5);
  });

  test('Hanefi ikindi standarttan geç çıkar; Otomatik Türkiye ve Karaçi Hanefi, diğerleri standart', () {
    asrMadhabNotifier.value = 'standard';
    final standard = _times(buildPrayerParams(), istanbul).asr;
    asrMadhabNotifier.value = 'hanafi';
    final hanafi = _times(buildPrayerParams(), istanbul).asr;
    expect(hanafi.isAfter(standard), isTrue);

    asrMadhabNotifier.value = 'auto';
    calcMethodNotifier.value = 'karachi';
    expect(resolvedMadhab(), Madhab.hanafi);
    calcMethodNotifier.value = 'turkey';
    expect(resolvedMadhab(), Madhab.hanafi);
    calcMethodNotifier.value = 'muslim_world_league';
    expect(resolvedMadhab(), Madhab.shafi);
  });

  test('her yöntem geçerli ve sıralı vakitler üretir', () {
    for (final c in [istanbul, jakarta]) {
      for (final m in prayerMethods) {
        final t = _times(m.build(), c);
        final order = [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha];
        for (var i = 1; i < order.length; i++) {
          expect(order[i].isAfter(order[i - 1]), isTrue, reason: '${m.id} @ ${c.latitude}: vakit $i sırasız');
        }
      }
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('seçim ekranı 320dp ve yazı x$scale ile taşmaz, seçim değişir', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!,
        ),
        home: PrayerMethodScreen(coordinates: istanbul, getPrayerName: (p) => p.name),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hesaplama Yöntemi'), findsWidgets);

      final egypt = find.text('Mısır - Genel Araştırma Kurumu');
      await tester.scrollUntilVisible(egypt, 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(egypt);
      await tester.pumpAndSettle();
      await tester.tap(egypt);
      await tester.pumpAndSettle();
      expect(calcMethodNotifier.value, 'egyptian');
    });
  }
}
