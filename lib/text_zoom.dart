import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının seçtiği yazı büyütme oranı. null = otomatik (ekran genişliğine göre).
final ValueNotifier<double?> textZoomNotifier = ValueNotifier<double?>(null);

const double minTextZoom = 1.0;
const double maxTextZoom = 1.6;

/// Telefonlarda yazılar zaten okunaklı olduğu için 1.0 kalır; geniş ekranlarda
/// (tablet, yatay, masaüstü) yazı ekrana göre küçük kaldığından biraz büyütülür.
double autoTextZoom(double widthDp) {
  if (widthDp.isNaN || widthDp <= 0) return 1.0;
  if (widthDp >= 900) return 1.25;
  if (widthDp >= 600) return 1.15;
  return 1.0;
}

Future<void> loadSavedTextZoom() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getDouble('text_zoom');
  textZoomNotifier.value = saved?.clamp(minTextZoom, maxTextZoom).toDouble();
}

/// Kaydırırken sadece değeri günceller; kalıcı kayıt için [setTextZoom] kullanılır.
Future<void> setTextZoom(double? zoom) async {
  textZoomNotifier.value = zoom;
  final prefs = await SharedPreferences.getInstance();
  if (zoom == null) {
    await prefs.remove('text_zoom');
  } else {
    await prefs.setDouble('text_zoom', zoom);
  }
}
