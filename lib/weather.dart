import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'l10n.dart';

// ---------------------------------------------------------------------------
// 3 günlük hava durumu. Veri: MET Norway (api.met.no), CC BY 4.0 — ücretsiz ve ticari kullanıma
// açık, anahtar gerektirmez. Kullanım şartı gereği kimlik belirten User-Agent gönderilir,
// koordinatlar en çok 4 ondalığa kırpılır ve yanıtlar önbelleğe alınır.
// ---------------------------------------------------------------------------

const String weatherAttribution = 'MET Norway (CC BY 4.0)';
const String _userAgent = 'KibleveNamazRehberim/1.2 (com.metint.kiblem)';
const Duration _minRefresh = Duration(hours: 3);

class WeatherDay {
  final DateTime date; // yalnızca gün
  final int max;
  final int min;
  final String symbol; // clearsky, partlycloudy, rain...
  const WeatherDay(this.date, this.max, this.min, this.symbol);

  Map<String, dynamic> toJson() => {
    'd':
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'max': max,
    'min': min,
    's': symbol,
  };

  static WeatherDay fromJson(Map<String, dynamic> j) {
    final p = (j['d'] as String).split('-').map(int.parse).toList();
    return WeatherDay(
      DateTime(p[0], p[1], p[2]),
      j['max'] as int,
      j['min'] as int,
      j['s'] as String,
    );
  }
}

/// Ana ekrandaki hava durumu kartının verisi; boşsa kart gizlenir.
final ValueNotifier<List<WeatherDay>> weatherNotifier =
    ValueNotifier<List<WeatherDay>>(const []);

bool _loading = false;

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

double _trunc(double v) => (v * 10000).truncateToDouble() / 10000;

List<WeatherDay> _upcoming(List<WeatherDay> days) =>
    days.where((d) => !d.date.isBefore(_today())).take(3).toList();

/// Konum ya da gün değiştiğinde çağrılır. Aynı konum için 3 saatten yeni ve bugüne ait veri varsa
/// ağa gitmez; internet yoksa kayıtlı veriden hâlâ geçerli olan günleri gösterir.
Future<void> refreshWeather(double lat, double lon) async {
  if (_loading) return;
  _loading = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';
    List<WeatherDay> cached = const [];
    DateTime? fetchedAt;
    try {
      final raw = prefs.getString('weather_cache');
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        if (j['key'] == key) {
          cached = _upcoming([
            for (final d in j['days'] as List)
              WeatherDay.fromJson(d as Map<String, dynamic>),
          ]);
          fetchedAt = DateTime.fromMillisecondsSinceEpoch(j['at'] as int);
        }
      }
    } catch (_) {}
    weatherNotifier.value = cached;

    final fresh =
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _minRefresh &&
        cached.isNotEmpty &&
        cached.first.date == _today();
    if (fresh) return;

    final res = await http
        .get(
          Uri.parse(
            'https://api.met.no/weatherapi/locationforecast/2.0/compact'
            '?lat=${_trunc(lat)}&lon=${_trunc(lon)}',
          ),
          headers: {'User-Agent': _userAgent},
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return;
    final days = _upcoming(
      _parse(jsonDecode(res.body) as Map<String, dynamic>),
    );
    if (days.isEmpty) return;
    weatherNotifier.value = days;
    await prefs.setString(
      'weather_cache',
      jsonEncode({
        'key': key,
        'at': DateTime.now().millisecondsSinceEpoch,
        'days': [for (final d in days) d.toJson()],
      }),
    );
  } catch (e) {
    debugPrint('Hava durumu alınamadı: $e');
  } finally {
    _loading = false;
  }
}

List<WeatherDay> _parse(Map<String, dynamic> json) {
  final series = (json['properties']['timeseries'] as List)
      .cast<Map<String, dynamic>>();
  final temps = <DateTime, List<double>>{};
  final symbols = <DateTime, List<MapEntry<DateTime, String>>>{};
  final now = DateTime.now();
  for (final e in series) {
    final time = DateTime.parse(e['time'] as String).toLocal();
    final day = DateTime(time.year, time.month, time.day);
    final data = e['data'] as Map<String, dynamic>;
    final t = data['instant']?['details']?['air_temperature'];
    if (t is num) temps.putIfAbsent(day, () => []).add(t.toDouble());
    for (final span in ['next_6_hours', 'next_12_hours', 'next_1_hours']) {
      final code = data[span]?['summary']?['symbol_code'];
      if (code is String) {
        symbols.putIfAbsent(day, () => []).add(MapEntry(time, code));
        break;
      }
    }
  }
  final out = <WeatherDay>[];
  for (final day in temps.keys.toList()..sort()) {
    final list = temps[day]!;
    final syms = symbols[day];
    if (syms == null || syms.isEmpty) continue;
    // Günün temsilcisi: öğleye en yakın kayıt (bugün öğle geçtiyse şimdiye en yakın).
    final target = day == _today() && now.hour >= 13
        ? now
        : DateTime(day.year, day.month, day.day, 13);
    syms.sort(
      (a, b) => a.key
          .difference(target)
          .abs()
          .compareTo(b.key.difference(target).abs()),
    );
    final code = syms.first.value.split('_').first;
    list.sort();
    out.add(WeatherDay(day, list.last.round(), list.first.round(), code));
  }
  return out;
}

IconData weatherIcon(String symbol) {
  if (symbol.contains('thunder')) return Icons.thunderstorm;
  if (symbol.contains('snow')) return Icons.ac_unit;
  if (symbol.contains('sleet')) return Icons.cloudy_snowing;
  if (symbol.contains('heavyrain')) return Icons.grain;
  if (symbol.contains('rain')) return Icons.water_drop;
  if (symbol == 'fog') return Icons.foggy;
  if (symbol == 'cloudy') return Icons.cloud;
  if (symbol == 'partlycloudy') return Icons.wb_cloudy;
  if (symbol == 'fair') return Icons.wb_sunny_outlined;
  return Icons.wb_sunny;
}

const _daysTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Üç günlük sıcaklık şeridi; her temada o temaya uygun bir görünümle çizilir.
class WeatherStrip extends StatelessWidget {
  final AppTheme theme;
  const WeatherStrip({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<WeatherDay>>(
      valueListenable: weatherNotifier,
      builder: (context, days, _) {
        if (days.isEmpty) return const SizedBox.shrink();
        final dark = theme.id == 'leather' || theme.id == 'night';
        final accent = theme.id == 'night' ? theme.accent : Colors.white;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: theme.id == 'ocean'
              ? null
              : BoxDecoration(
                  color: dark
                      ? Colors.black.withValues(alpha: 0.30)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final d in days) _cell(d, accent)],
            ),
          ),
        );
      },
    );
  }

  Widget _cell(WeatherDay d, Color color) {
    final name = (isEnglish ? _daysEn : _daysTr)[d.date.weekday - 1];
    const style = TextStyle(fontSize: 11, height: 1.2);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$name ${d.date.day}/${d.date.month}',
            style: style.copyWith(color: color),
          ),
          Icon(weatherIcon(d.symbol), size: 24, color: color),
          Text(
            '${d.max}/${d.min}°',
            style: style.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
