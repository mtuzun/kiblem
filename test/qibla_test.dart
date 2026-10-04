import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:kiblem/qibla_compass.dart';
import 'package:kiblem/qibla_geometry.dart';
import 'package:kiblem/qibla_screen.dart';

void main() {
  testWidgets(
    'location details, calibration and map controls work on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const sensor = MethodChannel('ml.medyas.flutter_qiblah');
      const location = MethodChannel('flutter.baseflow.com/geolocator');
      const compass = EventChannel('hemanthraj/flutter_compass');
      const updates = EventChannel('flutter.baseflow.com/geolocator_updates');
      messenger.setMockMethodCallHandler(sensor, (call) async => true);
      messenger.setMockMethodCallHandler(location, (call) async {
        switch (call.method) {
          case 'isLocationServiceEnabled':
            return true;
          case 'checkPermission':
            return 2;
          case 'getCurrentPosition':
            return {
              'latitude': 41.0082,
              'longitude': 28.9784,
              'timestamp': DateTime(2026).millisecondsSinceEpoch,
              'accuracy': 5.0,
              'altitude': 0.0,
              'altitude_accuracy': 0.0,
              'heading': 0.0,
              'heading_accuracy': 0.0,
              'speed': 0.0,
              'speed_accuracy': 0.0,
              'is_mocked': false,
            };
        }
        return null;
      });
      messenger.setMockStreamHandler(
        compass,
        MockStreamHandler.inline(
          onListen: (arguments, sink) => sink.success([135.0, 0.0, 15.0]),
        ),
      );
      messenger.setMockStreamHandler(
        updates,
        MockStreamHandler.inline(onListen: (arguments, sink) {}),
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(sensor, null);
        messenger.setMockMethodCallHandler(location, null);
        messenger.setMockStreamHandler(compass, null);
        messenger.setMockStreamHandler(updates, null);
      });
      await tester.pumpWidget(const MaterialApp(home: QiblaScreen()));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Pusula'), findsOneWidget);
      expect(find.textContaining('Kâbe’ye yaklaşık'), findsOneWidget);
      await tester.ensureVisible(find.text('Konum ayrıntıları'));
      await tester.tap(find.text('Konum ayrıntıları'));
      await tester.pumpAndSettle();
      expect(find.textContaining('41.00820° K'), findsOneWidget);
      expect(find.textContaining('28.97840° D'), findsOneWidget);
      await tester.ensureVisible(find.text('Kalibrasyon yardımı'));
      await tester.tap(find.text('Kalibrasyon yardımı'));
      await tester.pumpAndSettle();
      expect(find.text('Pusula kalibrasyonu'), findsOneWidget);
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Harita'));
      await tester.tap(find.text('Harita'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('Konumuma dön'), findsOneWidget);
      expect(find.byTooltip('Kâbe yönünü göster'), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  test('Istanbul bearing and distance follow the great circle to Kaaba', () {
    const istanbul = LatLng(41.0082, 28.9784);
    expect(qiblaBearing(istanbul), closeTo(151.6, 0.3));
    expect(
      const Distance(calculator: Haversine())(istanbul, kaabaLocation) / 1000,
      inInclusiveRange(2390, 2410),
    );
    final route = qiblaRoute(istanbul);
    expect(route.first, istanbul);
    expect(route.last, kaabaLocation);
    // The local map line must initially point toward the compass bearing.
    expect(route[1].latitude, lessThan(istanbul.latitude));
    expect(route[1].longitude, greaterThan(istanbul.longitude));
  });

  test('turn direction crosses north correctly', () {
    expect(signedQiblaTurn(350, 10), 20);
    expect(signedQiblaTurn(10, 350), -20);
  });

  test('alignment feedback rejects poor accuracy and edge jitter', () {
    final alignment = QiblaAlignment();
    final now = DateTime(2026);
    expect(alignment.update(1, now, reliable: false), isFalse);
    expect(alignment.update(2, now), isTrue);
    expect(alignment.update(4, now.add(const Duration(seconds: 4))), isFalse);
    expect(alignment.update(2, now.add(const Duration(seconds: 5))), isFalse);
    expect(alignment.update(10, now.add(const Duration(seconds: 6))), isFalse);
    expect(alignment.update(1, now.add(const Duration(seconds: 7))), isTrue);
  });

  testWidgets(
    'small screen compass remains visible and gives correct turn instruction',
    (tester) async {
      tester.view.physicalSize = const Size(280, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directions = StreamController<QiblahDirection>();
      addTearDown(directions.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: QiblaCompass(stream: directions.stream),
            ),
          ),
        ),
      );
      directions.add(const QiblahDirection(345, 135, 150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.textContaining('15° sağa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
