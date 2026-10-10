import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Ayet seslerini çalmadan önce diske indirip oradan çalmamızı sağlayan önbellek.
///
/// Amaç: internet akışı (streaming) sırasında bağlantı kesilirse (ör. metroda tünelde
/// kalmak) sesin ortasında donmasını önlemek. Bunun yerine her ayet TAMAMEN indirilip
/// yerel dosyadan çalınır; otomatik dinlemede sıradaki birkaç ayet de önceden (arka
/// planda) indirilerek birkaç dakikalık bir "ön tampon" oluşturulur. Böylece kısa
/// kesintilerde (bir iki durak arası gibi) dinleme hiç kesilmeden sürer; uzun
/// kesintilerde ise bağlantı dönünce kullanıcı müdahalesi olmadan kaldığı yerden devam
/// edilir (bkz. main.dart: _waitForInternetThenResume).
class AyahAudioCache {
  AyahAudioCache._();
  static final AyahAudioCache instance = AyahAudioCache._();

  Directory? _dir;
  final Set<int> _downloading = {};

  /// Aynı anda yalnızca bir ayet aktif olarak indirilsin diye (yavaş bağlantıda bant
  /// genişliği bölünmesin); sıradaki ayetler bu kuyruğa girip sırayla indirilir.
  Future<void> _queue = Future.value();

  Future<Directory> _cacheDir() async {
    final d = _dir;
    if (d != null) return d;
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/ayah_audio_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<File> _fileFor(int ayahNumber) async {
    final dir = await _cacheDir();
    return File('${dir.path}/$ayahNumber.mp3');
  }

  /// Diskte zaten varsa yolunu döner; yoksa null.
  Future<String?> localPath(int ayahNumber) async {
    try {
      final f = await _fileFor(ayahNumber);
      if (await f.exists() && await f.length() > 0) return f.path;
    } catch (_) {}
    return null;
  }

  /// [ayahNumber] diskte yoksa indirir. Zaten varsa ya da indirme sırasında biri
  /// bu ayeti indirmeye çalışıyorsa hemen döner. Başarısız olursa sessizce yutar
  /// (çağıran taraf localPath() ile kontrol edip akışa (streaming) düşebilir).
  Future<String?> ensureDownloaded(int ayahNumber, String url) async {
    final existing = await localPath(ayahNumber);
    if (existing != null) return existing;
    if (_downloading.contains(ayahNumber)) {
      // Zaten indiriliyor; bitene kadar kısa aralıklarla kontrol et.
      for (var i = 0; i < 100; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        final p = await localPath(ayahNumber);
        if (p != null) return p;
        if (!_downloading.contains(ayahNumber)) break;
      }
      return localPath(ayahNumber);
    }
    _downloading.add(ayahNumber);
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      final f = await _fileFor(ayahNumber);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsBytes(res.bodyBytes, flush: true);
      await tmp.rename(f.path);
      return f.path;
    } catch (e) {
      debugPrint('Ayet sesi indirilemedi ($ayahNumber): $e');
      return null;
    } finally {
      _downloading.remove(ayahNumber);
    }
  }

  /// Otomatik dinleme sırasında sıradaki birkaç ayeti arka planda, sırayla indirir
  /// (ortalama ayet uzunluğuna göre kabaca 3-4 dakikalık bir "ön tampon" hedeflenir).
  /// Hatalar yutulur; bu tamamen en iyi çaba (best effort) bir ön yüklemedir.
  void prefetchAhead(int fromAyahNumber, String Function(int) urlForAyah, {int count = 10}) {
    _queue = _queue.then((_) async {
      for (var i = 1; i <= count; i++) {
        final n = ((fromAyahNumber - 1 + i) % 6236) + 1;
        if (await localPath(n) != null) continue;
        await ensureDownloaded(n, urlForAyah(n));
      }
    });
  }

  /// Önbellek büyümesin diye şu an çalınan ayetin etrafındaki pencere dışında kalan
  /// dosyaları siler. Ayet dosyaları küçük olduğundan agresif bir sınıra gerek yok.
  Future<void> trim(int aroundAyahNumber, {int keepWindow = 30}) async {
    try {
      final dir = await _cacheDir();
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final n = int.tryParse(name.replaceAll('.mp3', '').replaceAll('.tmp', ''));
        if (n == null) continue;
        var dist = (n - aroundAyahNumber).abs();
        dist = dist > 6236 - dist ? 6236 - dist : dist;
        if (dist > keepWindow) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
