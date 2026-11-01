import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiblem/rate_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openDialog(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () => askForRating(context), child: const Text('aç')),
      ),
    ),
  ));
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('5. açılışta sorulur, ilk 4 açılışta sorulmaz', () async {
    for (var i = 1; i <= 4; i++) {
      expect(await countLaunchAndCheckRatingDue(), isFalse, reason: 'açılış $i');
    }
    expect(await countLaunchAndCheckRatingDue(), isTrue);
  });

  testWidgets('Daha sonra: 10 açılış sonra tekrar sorulur, en fazla 3 kez', (tester) async {
    SharedPreferences.setMockInitialValues({'launch_count': 4});
    expect(await countLaunchAndCheckRatingDue(), isTrue); // 5. açılış

    for (var ask = 1; ask <= 3; ask++) {
      await _openDialog(tester);
      expect(find.text('Uygulamamız hakkında yorum yazmak ve puanlamak ister misiniz?'), findsOneWidget);
      await tester.tap(find.text('Daha sonra'));
      await tester.pumpAndSettle();

      if (ask == 3) break;
      for (var i = 1; i < 10; i++) {
        expect(await countLaunchAndCheckRatingDue(), isFalse, reason: 'soru $ask, açılış +$i');
      }
      expect(await countLaunchAndCheckRatingDue(), isTrue, reason: 'soru $ask sonrası 10. açılış');
    }
    for (var i = 0; i < 30; i++) {
      expect(await countLaunchAndCheckRatingDue(), isFalse);
    }
  });

  testWidgets('320dp ve çift yazı boyunda taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(2.0)),
        child: w!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => askForRating(context), child: const Text('aç')),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Yıldıza dokununca: puan istenir ve bir daha sorulmaz', (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.britannio.in_app_review'),
      (call) async {
        calls.add(call.method);
        return call.method == 'isAvailable' ? true : null;
      },
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.britannio.in_app_review'), null));

    SharedPreferences.setMockInitialValues({'launch_count': 4});
    expect(await countLaunchAndCheckRatingDue(), isTrue);
    await _openDialog(tester);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    await tester.tap(find.byIcon(Icons.star_rounded).at(3));
    await tester.pumpAndSettle();

    expect(calls, contains('requestReview'));
    for (var i = 0; i < 40; i++) {
      expect(await countLaunchAndCheckRatingDue(), isFalse);
    }
  });
}
