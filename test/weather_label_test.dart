import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiblem/app_theme.dart';
import 'package:kiblem/l10n.dart';
import 'package:kiblem/weather.dart';

void main() {
  tearDown(() => langNotifier.value = 'tr');

  test('hava durumu sembolleri kısa açıklamaya çevrilir', () {
    const expected = {
      'clearsky': 'Güneşli',
      'fair': 'Açık',
      'partlycloudy': 'Az bulutlu',
      'cloudy': 'Bulutlu',
      'fog': 'Sisli',
      'lightrain': 'Az yağmurlu',
      'rain': 'Yağmurlu',
      'heavyrain': 'Sağanak',
      'rainshowers': 'Sağanak',
      'lightrainshowers': 'Sağanak',
      'sleet': 'Sulu kar',
      'lightsleet': 'Sulu kar',
      'snow': 'Karlı',
      'heavysnow': 'Karlı',
      'rainandthunder': 'Fırtına',
      'lightrainshowersandthunder': 'Fırtına',
    };
    expected.forEach((symbol, label) => expect(weatherLabel(symbol), label, reason: symbol));
  });

  test('İngilizce dilinde İngilizce açıklama döner', () {
    langNotifier.value = 'en';
    expect(weatherLabel('fog'), 'Foggy');
    expect(weatherLabel('heavyrain'), 'Showers');
    expect(weatherLabel('partlycloudy'), 'Partly cloudy');
  });

  for (final theme in appThemes) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${theme.id} hava durumu şeridi açıklamalarıyla taşmaz: yazı x$scale', (tester) async {
        tester.view.physicalSize = const Size(640, 1600);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        weatherNotifier.value = [
          WeatherDay(DateTime(2026, 10, 18), 15, 13, 'partlycloudy'),
          WeatherDay(DateTime(2026, 10, 19), 17, 13, 'lightrainshowersandthunder'),
          WeatherDay(DateTime(2026, 10, 20), 21, 12, 'heavyrain'),
        ];
        addTearDown(() => weatherNotifier.value = const []);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(body: Align(alignment: Alignment.topLeft, child: WeatherStrip(theme: theme))),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Az bulutlu'), findsOneWidget);
        expect(find.text('Fırtına'), findsOneWidget);
        expect(find.text('Sağanak'), findsOneWidget);
      });
    }
  }
}
