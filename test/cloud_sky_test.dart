import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiblem/app_theme.dart';

Widget _app({required bool disableAnimations, Size size = const Size(390, 844)}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: disableAnimations),
        child: Scaffold(
          body: ThemeBackground(theme: appThemeById('sky'), child: const Center(child: Text('içerik'))),
        ),
      ),
    );

void main() {
  testWidgets('gökyüzü teması bulutlarla çizilir ve hata vermez', (tester) async {
    await tester.pumpWidget(_app(disableAnimations: false));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('içerik'), findsOneWidget);
  });

  testWidgets('bulutlar hareket eder: kareler sürekli istenir', (tester) async {
    await tester.pumpWidget(_app(disableAnimations: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('sistemde animasyonlar kapalıysa bulutlar durağan kalır', (tester) async {
    await tester.pumpWidget(_app(disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  for (final size in const [Size(320, 568), Size(412, 915), Size(800, 1280)]) {
    testWidgets('bulutlar ${size.width.toInt()}x${size.height.toInt()} ekranda çizilir', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(disableAnimations: false, size: size));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  }
}
