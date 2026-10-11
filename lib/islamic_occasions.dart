import 'package:hijri/hijri_calendar.dart';

import 'l10n.dart';

// ---------------------------------------------------------------------------
// Kandil geceleri ve dini bayramlar. Tarihler hicri takvimden (Umm al-Qura, hijriDateString
// ile aynı yöntem) hesaplanır; tamamen yerel, internet ya da ek bir izin gerekmez. Diyanet'in
// resmi ilan ettiği tarihten ay görünümüne bağlı olarak ±1 gün sapabilir.
// ---------------------------------------------------------------------------

class IslamicOccasion {
  final String nameTr;
  final String nameEn;

  /// Kandilin/bayramın hicri karşılığı olan ilk miladi gün (saat bileşeni yok).
  final DateTime date;

  /// Bayramlarda birden fazla gün sürer (Ramazan 3, Kurban 4); kandillerde 1.
  final int spanDays;

  const IslamicOccasion(this.nameTr, this.nameEn, this.date, {this.spanDays = 1});

  String get name => t(nameTr, nameEn);
  DateTime get lastDay => date.add(Duration(days: spanDays - 1));
  bool get isEid => spanDays > 1;
}

DateTime _d(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// hijri paketinin "hicri → miladi" (hijriToGregorian) ve "miladi → hicri" (fromDate, ekrandaki
/// hicriDateString'in de kullandığı yöntem) dönüşümleri birbirinden ±birkaç gün sapabiliyor.
/// Üstteki hicri tarihle (ve dolayısıyla kullanıcının gördüğü ayla) tutarlı olmak için, hicri
/// (year, month, day)'a karşılık gelen gün, hijriToGregorian'ın verdiği tahminin etrafında
/// fromDate ile taranarak bulunur.
DateTime _hijriToGregorian(HijriCalendar cal, int year, int month, int day) {
  final guess = _d(cal.hijriToGregorian(year, month, day));
  for (var offset = -3; offset <= 3; offset++) {
    final candidate = guess.add(Duration(days: offset));
    final h = HijriCalendar.fromDate(candidate);
    if (h.hYear == year && h.hMonth == month && h.hDay == day) return candidate;
  }
  return guess; // beklenmedik şekilde bulunamazsa ilk tahmine düşülür
}

/// [hijriYear] içindeki tüm kandil ve bayramları miladi karşılıklarıyla döner.
List<IslamicOccasion> occasionsInHijriYear(int hijriYear) {
  final cal = HijriCalendar();
  DateTime g(int month, int day) => _hijriToGregorian(cal, hijriYear, month, day);

  // Regaib Kandili: Receb ayının ilk Cuma gecesi.
  final rajab1 = g(7, 1);
  final daysUntilFriday = (DateTime.friday - rajab1.weekday + 7) % 7;
  final regaib = rajab1.add(Duration(days: daysUntilFriday));

  return [
    IslamicOccasion('Regaib Kandili', 'Laylat al-Raghaib', regaib),
    IslamicOccasion('Mirac Kandili', "Laylat al-Mi'raj", g(7, 27)),
    IslamicOccasion('Berat Kandili', "Laylat al-Bara'ah", g(8, 15)),
    IslamicOccasion('Mevlid Kandili', 'Mawlid al-Nabi', g(3, 12)),
    IslamicOccasion('Kadir Gecesi', 'Laylat al-Qadr', g(9, 27)),
    IslamicOccasion('Ramazan Bayramı', 'Eid al-Fitr', g(10, 1), spanDays: 3),
    IslamicOccasion('Kurban Bayramı', 'Eid al-Adha', g(12, 10), spanDays: 4),
  ];
}

/// [around] tarihinin bir önceki, kendi ve bir sonraki hicri yılındaki tüm özel günleri,
/// tarih sırasına göre döner (geçmiş kandillerin aynı isimle tekrar bulunabilmesi için).
List<IslamicOccasion> nearbyOccasions(DateTime around) {
  final hYear = HijriCalendar.fromDate(around).hYear;
  final all = [
    ...occasionsInHijriYear(hYear - 1),
    ...occasionsInHijriYear(hYear),
    ...occasionsInHijriYear(hYear + 1),
  ];
  all.sort((a, b) => a.date.compareTo(b.date));
  return all;
}

/// [now] bir kandilin/bayramın gününe ya da gecesine denk geliyorsa onu döner, değilse null.
/// Hicri gün gün batımıyla başladığından, kandilin ilk gününden bir önceki akşam vaktinden
/// ([maghrib], o günün akşam namazı vakti) itibaren "gece başladı" kabul edilir.
IslamicOccasion? activeOccasion(DateTime now, DateTime maghrib) {
  final today = _d(now);
  for (final o in nearbyOccasions(now)) {
    final start = _d(o.date);
    final end = _d(o.lastDay);
    if (!today.isBefore(start) && !today.isAfter(end)) return o;
    final eve = start.subtract(const Duration(days: 1));
    if (today == eve && !now.isBefore(maghrib)) return o;
  }
  return null;
}

/// [date] tam olarak bu güne denk gelen özel günü döner (takvim ekranında etiketlemek için);
/// gece/akşam kuralı uygulanmaz, yalnızca gündüz tarihine bakılır.
IslamicOccasion? occasionOnDate(DateTime date) {
  final day = _d(date);
  for (final o in nearbyOccasions(date)) {
    if (!day.isBefore(_d(o.date)) && !day.isAfter(_d(o.lastDay))) return o;
  }
  return null;
}
