import 'package:flutter/foundation.dart';
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

extension HadithL10n on Hadith {
  String get shownText => isEnglish ? textEn : text;
  String get shownSource => isEnglish ? sourceEn : source;
  String get shownTopic => isEnglish ? topicEn : topic;
}
