import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

enum OfflineState { none, downloading, ready }

enum OfflineResult { ok, noInternet, failed }

/// api.alquran.cloud erişimi var mı? (Sadece DNS çözümlemesine bakar.)
Future<bool> hasInternet() async {
  if (kIsWeb) return true;
  try {
    final r = await InternetAddress.lookup('api.alquran.cloud').timeout(const Duration(seconds: 3));
    return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Tüm Kur'an metnini (Arapça, okunuş, 2 Türkçe meal, İngilizce) bir kez indirip
/// cihazda saklar; sonrasında ayetler internetsiz okunur.
class OfflineQuran {
  static final ValueNotifier<OfflineState> state = ValueNotifier(OfflineState.none);
  static final ValueNotifier<double> progress = ValueNotifier(0);

  static const _editions = ['quran-uthmani', 'tr.transliteration', 'tr.diyanet', 'tr.yazir', 'en.sahih'];
  static const _fileName = 'quran_offline_v1.json';
  static const int totalAyahs = 6236;

  static List<dynamic>? _ayahs;
  static List<dynamic>? _surahNames;

  /// main() içinde başlatılır; ayet yüklemeden önce beklenir.
  static Future<void> initFuture = Future.value();

  static Future<void> init() {
    return initFuture = _init();
  }

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> _init() async {
    if (kIsWeb) return;
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final data = await compute(_decode, await f.readAsString());
      final ayahs = data['ayahs'] as List<dynamic>;
      if (ayahs.length != totalAyahs) return;
      _ayahs = ayahs;
      _surahNames = data['surahs'] as List<dynamic>;
      state.value = OfflineState.ready;
    } catch (e) {
      debugPrint('Çevrimdışı Kur\'an yüklenemedi: $e');
    }
  }

  /// Uygulamadaki ayet kartının kullandığı biçimde döner; indirilmemişse null.
  static Map<String, dynamic>? getAyah(int number) {
    final ayahs = _ayahs;
    if (ayahs == null || number < 1 || number > totalAyahs) return null;
    final a = ayahs[number - 1] as List<dynamic>;
    return {
      'arabic': a[2],
      'transliteration': a[3],
      'turkish1': a[4],
      'turkish2': a[5],
      'english': a[6],
      'surah': _surahNames![a[0] as int],
      'numberInSurah': a[1],
      'audioUrl': 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$number.mp3',
    };
  }

  static Future<OfflineResult> download() async {
    if (kIsWeb || state.value == OfflineState.downloading) return OfflineResult.failed;
    if (!await hasInternet()) return OfflineResult.noInternet;

    state.value = OfflineState.downloading;
    progress.value = 0;
    try {
      final parsed = <Map<String, dynamic>>[];
      for (var i = 0; i < _editions.length; i++) {
        final r = await http
            .get(Uri.parse('https://api.alquran.cloud/v1/quran/${_editions[i]}'))
            .timeout(const Duration(seconds: 90));
        if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
        final p = await compute(_parseEdition, r.body);
        if ((p['texts'] as List).length != totalAyahs) throw Exception('eksik veri');
        parsed.add(p);
        progress.value = (i + 1) / _editions.length;
      }

      final first = parsed[0];
      final ayahs = <List<dynamic>>[];
      for (var n = 0; n < totalAyahs; n++) {
        ayahs.add([
          (first['surahOf'] as List)[n],
          (first['numInSurah'] as List)[n],
          for (final p in parsed) (p['texts'] as List)[n],
        ]);
      }
      final json = jsonEncode({'surahs': first['names'], 'ayahs': ayahs});

      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(f.path);

      _ayahs = ayahs;
      _surahNames = first['names'] as List<dynamic>;
      state.value = OfflineState.ready;
      return OfflineResult.ok;
    } catch (e) {
      debugPrint('Kur\'an indirilemedi: $e');
      state.value = _ayahs == null ? OfflineState.none : OfflineState.ready;
      return OfflineResult.failed;
    }
  }

  static Future<void> delete() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
    _ayahs = null;
    _surahNames = null;
    state.value = OfflineState.none;
  }
}

Map<String, dynamic> _decode(String s) => jsonDecode(s) as Map<String, dynamic>;

Map<String, dynamic> _parseEdition(String body) {
  final surahs = (jsonDecode(body)['data']['surahs'] as List);
  final names = <String>[];
  final surahOf = <int>[];
  final numInSurah = <int>[];
  final texts = <String>[];
  for (var i = 0; i < surahs.length; i++) {
    names.add(surahs[i]['englishName'] as String);
    for (final a in surahs[i]['ayahs'] as List) {
      surahOf.add(i);
      numInSurah.add(a['numberInSurah'] as int);
      texts.add(a['text'] as String);
    }
  }
  return {'names': names, 'surahOf': surahOf, 'numInSurah': numInSurah, 'texts': texts};
}
