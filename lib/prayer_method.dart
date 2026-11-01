import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

// ---------------------------------------------------------------------------
// Hesaplama yöntemi: namaz vakitlerinin hangi kurumun açı/kural setiyle hesaplanacağı ve
// ikindinin hangi gölge kuralıyla bulunacağı. Hesap tamamen cihazda (adhan paketi) yapılır.
//
// "Otomatik" varsayılandır: Türkiye'de Diyanet İşleri Başkanlığı yöntemi (eski davranış), başka
// ülkede o ülkenin yaygın yöntemi. Seçim Ayarlar > Hesaplama Yöntemi'nden ya da kolay kurulumdan
// değiştirilebilir.
// ---------------------------------------------------------------------------

class PrayerMethod {
  final String id;
  final String tr;
  final String en;
  final CalculationParameters Function() build;

  /// Otomatik ikindi seçiminde bu yöntem için Hanefi (gölge 2 katı) kullanılsın mı.
  final bool hanafiAsr;

  const PrayerMethod(this.id, this.tr, this.en, this.build, {this.hanafiAsr = false});

  String get label => t(tr, en);
}

CalculationParameters _angles(double fajr, double isha) =>
    CalculationParameters(method: CalculationMethod.other, fajrAngle: fajr, ishaAngle: isha);

final List<PrayerMethod> prayerMethods = [
  // Türkiye'de Hanefi çoğunlukta: Otomatik ikindi Hanefi (gölge 2 katı). Diyanet takvimiyle birebir
  // vakit isteyenler İkindi Hesabı'ndan "Standart"ı seçer.
  PrayerMethod('turkey', 'Türkiye - Diyanet İşleri Başkanlığı', 'Turkey - Diyanet (Religious Affairs)',
      CalculationMethod.turkey.getParameters,
      hanafiAsr: true),
  PrayerMethod('muslim_world_league', 'Müslüman Dünya Ligi', 'Muslim World League',
      CalculationMethod.muslim_world_league.getParameters),
  PrayerMethod('egyptian', 'Mısır - Genel Araştırma Kurumu', 'Egypt - General Authority of Survey',
      CalculationMethod.egyptian.getParameters),
  PrayerMethod('karachi', 'Karaçi - İslam Bilimleri Üniversitesi', 'Karachi - University of Islamic Sciences',
      CalculationMethod.karachi.getParameters,
      hanafiAsr: true),
  PrayerMethod('north_america', 'Kuzey Amerika - ISNA', 'North America - ISNA',
      CalculationMethod.north_america.getParameters),
  PrayerMethod('umm_al_qura', "Suudi Arabistan - Ummü'l-Kura Üniversitesi", 'Saudi Arabia - Umm al-Qura University',
      CalculationMethod.umm_al_qura.getParameters),
  PrayerMethod('dubai', 'BAE - Birleşik Arap Emirlikleri', 'UAE - United Arab Emirates',
      CalculationMethod.dubai.getParameters),
  PrayerMethod('kuwait', 'Kuveyt - Vakıflar ve İslami İşler Bakanlığı', 'Kuwait - Ministry of Awqaf',
      CalculationMethod.kuwait.getParameters),
  PrayerMethod('qatar', 'Katar - Katar İslami İşler Bakanlığı', 'Qatar - Ministry of Awqaf',
      CalculationMethod.qatar.getParameters),
  PrayerMethod('singapore', 'Singapur - MUIS', 'Singapore - MUIS', CalculationMethod.singapore.getParameters),
  PrayerMethod('tehran', 'İran - Tahran Üniversitesi', 'Iran - University of Tehran',
      CalculationMethod.tehran.getParameters),
  PrayerMethod('moon_sighting_committee', 'Hilal Gözlem Komitesi', 'Moonsighting Committee',
      CalculationMethod.moon_sighting_committee.getParameters),
  PrayerMethod('france_uoif', 'Fransa - UOIF', 'France - UOIF', () => _angles(12, 12)),
  PrayerMethod('russia', 'Rusya - Müslümanların Ruhani İdaresi', 'Russia - Spiritual Administration of Muslims',
      () => _angles(16, 15)),
  PrayerMethod('indonesia', 'Endonezya - Kemenag', 'Indonesia - Kemenag', () => _angles(20, 18)),
  PrayerMethod('malaysia', 'Malezya - JAKIM', 'Malaysia - JAKIM', () => _angles(20, 18)),
  PrayerMethod('tunisia', 'Tunus - Dini İşler Bakanlığı', 'Tunisia - Ministry of Religious Affairs',
      () => _angles(18, 18)),
  PrayerMethod('algeria', 'Cezayir - Vakıflar ve Dini İşler Bakanlığı', 'Algeria - Ministry of Religious Affairs',
      () => _angles(18, 17)),
];

PrayerMethod methodById(String id) => prayerMethods.firstWhere((m) => m.id == id, orElse: () => prayerMethods.first);

/// İki harfli ülke koduna göre otomatik yöntem. Bilinmiyorsa Müslüman Dünya Ligi.
String autoMethodIdForCountry(String? code) {
  switch (code?.toUpperCase()) {
    case 'TR':
    case 'CY':
      return 'turkey';
    case 'SA':
      return 'umm_al_qura';
    case 'AE':
      return 'dubai';
    case 'KW':
      return 'kuwait';
    case 'QA':
      return 'qatar';
    case 'SG':
      return 'singapore';
    case 'IR':
      return 'tehran';
    case 'EG':
    case 'SD':
    case 'LY':
    case 'SY':
    case 'LB':
    case 'PS':
    case 'IQ':
      return 'egyptian';
    case 'PK':
    case 'BD':
    case 'IN':
    case 'AF':
      return 'karachi';
    case 'US':
    case 'CA':
      return 'north_america';
    case 'FR':
      return 'france_uoif';
    case 'RU':
      return 'russia';
    case 'ID':
      return 'indonesia';
    case 'MY':
    case 'BN':
      return 'malaysia';
    case 'TN':
      return 'tunisia';
    case 'DZ':
      return 'algeria';
    default:
      return 'muslim_world_league';
  }
}

/// Seçili yöntem: 'auto' ya da [prayerMethods] içindeki bir kimlik.
final ValueNotifier<String> calcMethodNotifier = ValueNotifier<String>('auto');

/// İkindi hesabı: 'auto', 'standard' (Şâfiî, Mâlikî, Hanbelî) ya da 'hanafi'.
final ValueNotifier<String> asrMadhabNotifier = ValueNotifier<String>('auto');

/// Son bulunan ya da seçilen konumun ülke kodu; "Otomatik" yöntem buna bakar. Varsayılan Türkiye.
final ValueNotifier<String?> calcCountryNotifier = ValueNotifier<String?>('TR');

Future<void> loadPrayerMethodSettings() async {
  final prefs = await SharedPreferences.getInstance();
  final method = prefs.getString('calc_method') ?? 'auto';
  calcMethodNotifier.value = (method == 'auto' || prayerMethods.any((m) => m.id == method)) ? method : 'auto';
  final asr = prefs.getString('asr_madhab') ?? 'auto';
  asrMadhabNotifier.value = const ['auto', 'standard', 'hanafi'].contains(asr) ? asr : 'auto';
  calcCountryNotifier.value = prefs.containsKey('calc_country') ? prefs.getString('calc_country') : 'TR';
}

Future<void> setCalcMethod(String id) async {
  calcMethodNotifier.value = id;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('calc_method', id);
}

Future<void> setAsrMadhab(String value) async {
  asrMadhabNotifier.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('asr_madhab', value);
}

/// Bulunan ya da seçilen konumun ülkesini kaydeder; null "bilinmiyor" demektir.
Future<void> setCalcCountry(String? code) async {
  if (calcCountryNotifier.value == code) return;
  calcCountryNotifier.value = code;
  final prefs = await SharedPreferences.getInstance();
  if (code == null) {
    await prefs.remove('calc_country');
  } else {
    await prefs.setString('calc_country', code);
  }
}

/// Şu an geçerli yöntem ("Otomatik" ise ülkeye göre çözülmüş hâli).
PrayerMethod resolvedMethod() {
  final id = calcMethodNotifier.value;
  return methodById(id == 'auto' ? autoMethodIdForCountry(calcCountryNotifier.value) : id);
}

/// Şu an geçerli ikindi kuralı.
Madhab resolvedMadhab() {
  switch (asrMadhabNotifier.value) {
    case 'hanafi':
      return Madhab.hanafi;
    case 'standard':
      return Madhab.shafi;
    default:
      return resolvedMethod().hanafiAsr ? Madhab.hanafi : Madhab.shafi;
  }
}

/// Seçime göre hesaplama parametreleri. Varsayılan (Otomatik, Türkiye): Diyanet açıları ve Hanefi
/// ikindi. Standart (Şâfiî) ikindi yaklaşık 45 dakika daha erken çıkar ve Diyanet takvimiyle aynıdır.
CalculationParameters buildPrayerParams() {
  final params = resolvedMethod().build();
  params.madhab = resolvedMadhab();
  return params;
}

/// Ayarlar satırında ve kurulumda gösterilen kısa özet.
String methodSummary() {
  final m = resolvedMethod();
  return calcMethodNotifier.value == 'auto' ? t('Otomatik: ${m.label}', 'Automatic: ${m.label}') : m.label;
}

String madhabLabel(String value) {
  switch (value) {
    case 'standard':
      return t('Standart (Şâfiî, Mâlikî, Hanbelî)', 'Standard (Shafi, Maliki, Hanbali)');
    case 'hanafi':
      return t('Hanefî (gölge 2 katı)', 'Hanafi (shadow twice the length)');
    default:
      final auto = resolvedMadhab() == Madhab.hanafi ? madhabLabel('hanafi') : madhabLabel('standard');
      return t('Otomatik: $auto', 'Automatic: $auto');
  }
}

/// Ayarlar > Hesaplama Yöntemi: üstte seçili yönteme göre bugünün vakitleri (seçim değiştikçe
/// anında güncellenir), altta yöntem ve ikindi seçenekleri.
class PrayerMethodScreen extends StatelessWidget {
  final Coordinates coordinates;
  final String Function(Prayer prayer) getPrayerName;

  const PrayerMethodScreen({super.key, required this.coordinates, required this.getPrayerName});

  static const _prayers = [Prayer.fajr, Prayer.sunrise, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t('Hesaplama Yöntemi', 'Calculation Method'))),
      body: ValueListenableBuilder<String>(
        valueListenable: langNotifier,
        builder: (context, _, _) => AnimatedBuilder(
          animation: Listenable.merge([calcMethodNotifier, asrMadhabNotifier, calcCountryNotifier]),
          builder: (context, _) {
            final now = DateTime.now();
            final times = PrayerTimes(coordinates, DateComponents(now.year, now.month, now.day), buildPrayerParams());
            final format = DateFormat('HH:mm');
            final date = "${now.day.toString().padLeft(2, '0')} ${longMonth(now.month)} ${now.year}";
            return ListView(
              padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).padding.bottom),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  color: cs.surfaceContainerHighest,
                  child: Column(
                    children: [
                      Text("$date   •   ${hijriDateString(now)}", style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final p in _prayers)
                            Container(
                              width: 92,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Text(getPrayerName(p), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                                  const SizedBox(height: 2),
                                  Text(
                                    format.format(times.timeForPrayer(p) ?? now),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                _header(context, t('Hesaplama Yöntemi', 'Calculation Method')),
                _option(
                  context,
                  title: t('Otomatik', 'Automatic'),
                  subtitle: autoMethodLabel(),
                  selected: calcMethodNotifier.value == 'auto',
                  onTap: () => setCalcMethod('auto'),
                ),
                for (final m in prayerMethods)
                  _option(
                    context,
                    title: m.label,
                    selected: calcMethodNotifier.value == m.id,
                    onTap: () => setCalcMethod(m.id),
                  ),
                _header(context, t('İkindi Hesabı - Mezhep', 'Asr Calculation - Madhab')),
                for (final v in const ['auto', 'standard', 'hanafi'])
                  _option(
                    context,
                    title: madhabLabel(v),
                    selected: asrMadhabNotifier.value == v,
                    onTap: () => setAsrMadhab(v),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    t(
                      'Vakitler cihazınızda hesaplanır, internet gerekmez.',
                      'Prayer times are calculated on your device; no internet is needed.',
                    ),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// "Otomatik" satırının altında, şu an hangi yönteme çözüldüğü.
  static String autoMethodLabel() => methodById(autoMethodIdForCountry(calcCountryNotifier.value)).label;

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _option(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final green = Theme.of(context).brightness == Brightness.dark ? Colors.green[300]! : Colors.green[700]!;
    return ListTile(
      dense: true,
      title: Text(title, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: selected ? Icon(Icons.check, color: green) : null,
      onTap: onTap,
    );
  }
}
