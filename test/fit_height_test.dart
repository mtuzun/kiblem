import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiblem/fit_height.dart';

Widget _host(double maxHeight, {double boxHeight = 300}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          child: FitHeight(
            maxHeight: maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(key: const Key('kutu'), width: 100, height: boxHeight),
                const Text('alt yazı'),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('sığıyorsa olduğu gibi bırakır', (tester) async {
    await tester.pumpWidget(_host(1000));
    expect(tester.getSize(find.byType(FitHeight)).height, lessThan(1000));
    expect(tester.getRect(find.byKey(const Key('kutu'))).height, 300);
  });

  testWidgets('yükseklik sınırı aşılırsa oranlı küçülür ve sınırın içinde kalır', (tester) async {
    await tester.pumpWidget(_host(200));
    final h = tester.getSize(find.byType(FitHeight)).height;
    expect(h, lessThanOrEqualTo(200.01));
    final box = tester.getRect(find.byKey(const Key('kutu')));
    expect(box.height, lessThan(300));
    expect(box.width / box.height, closeTo(100 / 300, 0.01));
  });

  testWidgets('en küçük ölçeğin altına inmez', (tester) async {
    await tester.pumpWidget(_host(10));
    final box = tester.getRect(find.byKey(const Key('kutu')));
    expect(box.height, closeTo(300 * 0.55, 0.5));
  });
}
