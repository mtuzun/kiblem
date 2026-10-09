import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hadith_data.dart';

/// Uygulama dili: 'tr' (varsayılan) veya 'en'.
final ValueNotifier<String> langNotifier = ValueNotifier<String>('tr');

bool get isEnglish => langNotifier.value == 'en';

/// Türkçe / İngilizce metin seçici.
String t(String turkish, String english) => isEnglish ? english : turkish;

Future<void> setLanguage(String code) async {
  langNotifier.value = code;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('app_language', code);
}

/// Kayıtlı seçim yoksa telefonun dillerine bakar: Türkçe yüklüyse 'tr', değilse 'en'.
/// Dil bilgisi alınamazsa Türkçe kalır.
String _detectLanguage() {
  try {
    final locales = PlatformDispatcher.instance.locales;
    if (locales.isEmpty) return 'tr';
    return locales.any((l) => l.languageCode == 'tr') ? 'tr' : 'en';
  } catch (_) {
    return 'tr';
  }
}

Future<void> loadSavedLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('app_language');
  langNotifier.value = (saved == 'tr' || saved == 'en') ? saved! : _detectLanguage();
}

const List<String> _monthsTr = ["", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
const List<String> _monthsEn = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

String shortMonth(int month) => (isEnglish ? _monthsEn : _monthsTr)[month];

const List<String> _longMonthsTr = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
const List<String> _longMonthsEn = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

String longMonth(int month) => (isEnglish ? _longMonthsEn : _longMonthsTr)[month];

const List<String> _hijriMonthsTr = [
  "", "Muharrem", "Safer", "Rebi-ül Evvel", "Rebi-ül Ahir", "Cemaziyel Evvel", "Cemaziyel Ahir",
  "Recep", "Şaban", "Ramazan", "Şevval", "Zilkade", "Zilhicce",
];
const List<String> _hijriMonthsEn = [
  "", "Muharram", "Safar", "Rabi' al-awwal", "Rabi' al-thani", "Jumada al-awwal", "Jumada al-thani",
  "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah",
];

/// Miladi tarihi Umm al-Qura takvimine göre hicri tarihe çevirir.
/// Diyanet'in ilan ettiği tarihten ±1 gün sapabilir.
String hijriDateString(DateTime date) {
  final h = HijriCalendar.fromDate(date);
  final name = (isEnglish ? _hijriMonthsEn : _hijriMonthsTr)[h.hMonth];
  return "${h.hDay} $name ${h.hYear}";
}

extension HadithL10n on Hadith {
  String get shownText => isEnglish ? textEn : text;
  String get shownSource => isEnglish ? sourceEn : source;
  String get shownTopic => isEnglish ? topicEn : topic;
}
