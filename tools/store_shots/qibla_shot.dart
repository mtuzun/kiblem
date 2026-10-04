// Mağaza ekran görüntüsü aracı: Kıble pusulası ekranını sensör olmadan, sabit
// örnek verilerle çizer. Uygulamaya dahil değildir.
//   flutter build web --release -t tools/store_shots/qibla_shot.dart --output build/web_qibla
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:kiblem/l10n.dart';
import 'package:kiblem/main.dart' show QiblaCompass;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedLanguage();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: const Color(0xFF8DCFB3),
        fontFamily: 'Montserrat',
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(t('Kıble Yönü', 'Qibla Direction')),
          backgroundColor: const Color(0xFF6DAF89),
        ),
        // İstanbul'dan Kâbe yönü ~151.6°; telefon bu yöne bakıyor (hizalı).
        body: QiblaCompass(stream: Stream.value(const QiblahDirection(0.4, 152.0, 151.6))),
      ),
    ),
  );
}
