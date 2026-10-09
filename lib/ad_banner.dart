import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ayet, kıble ve zikirmatik sayfalarının ortak banner reklam birimi ("Ayet Sayfasi Banner").
/// Ana ekranın banner'ı ayrı bir birim kullanır.
const String _contentBannerAndroid = 'ca-app-pub-9864338488985680/1558711322';
const String _contentBannerIos = 'ca-app-pub-9864338488985680/1910065110';

/// İnce (320x50) bir banner. Reklam yüklenemezse ya da platform desteklemiyorsa (web, masaüstü)
/// hiç yer kaplamaz. Üstte ve altta küçük bir boşluk bırakır; sayfalardaki düğmelere
/// yanlışlıkla dokunulmasın diye bu boşluğu azaltmayın.
class AdBanner extends StatefulWidget {
  /// Reklam yüklendiğinde altına eklenen ek boşluk (reklam yoksa boşluk da yoktur).
  final double bottomGap;

  const AdBanner({super.key, this.bottomGap = 0});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    _ad = BannerAd(
      adUnitId: Platform.isIOS ? _contentBannerIos : _contentBannerAndroid,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
          debugPrint('İçerik banner reklamı yüklenemedi: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + widget.bottomGap),
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
