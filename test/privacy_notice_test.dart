import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiblem/privacy_notice.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('bilgilendirme 320dp ve yazı x$scale ile taşmaz', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => showPrivacyDetails(context), child: const Text('aç')),
          ),
        ),
      ));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      expect(find.text('Gizlilik ve KVKK Bilgilendirmesi'), findsOneWidget);
      expect(find.textContaining('Hesap gerekmez'), findsOneWidget);
      expect(find.text('Tam politikayı aç'), findsOneWidget);

      final last = find.textContaining('Bu metin bilgilendirme amaçlıdır');
      await tester.scrollUntilVisible(last, 200, scrollable: find.byType(Scrollable).first);
      expect(last, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
