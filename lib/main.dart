import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:share_plus/share_plus.dart';
import 'package:home_widget/home_widget.dart';

import 'city_data.dart';
import 'hadith_data.dart';
import 'l10n.dart';
import 'offline_quran.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'text_zoom.dart';
import 'onboarding_screen.dart';
import 'qibla_screen.dart';
import 'ad_banner.dart';
import 'figures.dart';
import 'app_theme.dart';
export 'qibla_compass.dart' show QiblaCompass;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const MethodChannel ringtoneChannel = MethodChannel('com.metint.kiblem/ringtone');

/// İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı.
const int _prayerAlarmCount = 6;

/// Bir vakit için alarm ayarı: açık/kapalı, kaç dakika önce, hangi ses.
class PrayerAlarm {
  bool enabled;
  int minutes;
  String? soundUri;
  String? soundTitle;

  /// true: ses 1 dakika boyunca tekrar eder. false: ses dosyası bir kez çalar, bitince alarm susar.
  bool oneMinute;

  PrayerAlarm({this.enabled = false, this.minutes = 15, this.soundUri, this.soundTitle, this.oneMinute = false});
}

final GlobalKey qiblaButtonKey = GlobalKey();
final GlobalKey prayerListKey = GlobalKey();
final GlobalKey dailyAyahKey = GlobalKey();
final GlobalKey dailyHadithKey = GlobalKey();
final GlobalKey dailyTabsKey = GlobalKey();
// Dar ekranda açık sekme: 0 = Günün Ayeti, 1 = Vaktin Hadisi.
final ValueNotifier<int> dailyTabNotifier = ValueNotifier<int>(1);
final GlobalKey zikirButtonKey = GlobalKey();
final GlobalKey settingsButtonKey = GlobalKey();
final ValueNotifier<bool> showCoachMarks = ValueNotifier<bool>(false);
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> setThemeMode(ThemeMode mode) async {
  themeModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', mode.name);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    MobileAds.instance.initialize();
  }

  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  themeModeNotifier.value = ThemeMode.values.firstWhere(
    (m) => m.name == prefs.getString('theme_mode'),
    orElse: () => ThemeMode.system,
  );
  themeNotifier.value = appThemeById(prefs.getString('app_theme')).id;
  colorThemeNotifier.value = paletteById(prefs.getString('color_theme')).id;
  figureNotifier.value = figureById(prefs.getString('app_figure')).id;
  await loadSavedLanguage();
  await loadSavedTextZoom();
  unawaited(OfflineQuran.init());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Kıble ve Namaz Rehberim',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
            scaffoldBackgroundColor: const Color(0xFF8DCFB3),
            fontFamily: 'Montserrat',
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
            fontFamily: 'Montserrat',
          ),
          builder: (context, child) => ValueListenableBuilder<double?>(
            valueListenable: textZoomNotifier,
            builder: (context, zoom, _) {
              final mq = MediaQuery.of(context);
              final userScale = zoom ?? autoTextZoom(mq.size.width);
              // Telefonun kendi yazı boyutu ayarı korunur, üstüne çarpılır.
              final systemScale = mq.textScaler.scale(14) / 14;
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear((systemScale * userScale).clamp(1.0, 2.4))),
                child: child!,
              );
            },
          ),
          home: const AppEntry(),
        );
      },
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('has_seen_onboarding') ?? false;
    if (!seen) {
      showCoachMarks.value = true;
    }
  }

  Future<void> _finishCoachMarks() async {
    showCoachMarks.value = false;
    dailyTabNotifier.value = 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const MainScreen(),
        ValueListenableBuilder<bool>(
          valueListenable: showCoachMarks,
          builder: (context, visible, _) {
            if (!visible) return const SizedBox.shrink();
            return CoachMarkOverlay(onFinished: _finishCoachMarks);
          },
        ),
      ],
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String currentCity = "İstanbul";
  PrayerTimes? prayerTimes;
  Timer? timer;
  String timeLeft = "00:00:00";
  String nextPrayerName = "";
  Prayer? nextPrayer;
  Coordinates? activeCoordinates;
  bool isLocating = false;

  Map<String, dynamic>? dailyAyahData;
  final ValueNotifier<Map<String, dynamic>?> dailyAyahNotifier = ValueNotifier(null);
  
  bool isLoadingAyah = false;
  int? displayedAyahNumber;
  
  AudioPlayer? audioPlayer;
  bool isAutoPlaying = false;

  // Ses: Kur'an okunuşu (internetten), meal (telefonun sesli okuması / TTS) veya ikisi sırayla.
  final FlutterTts tts = FlutterTts();
  final ValueNotifier<String> audioModeNotifier = ValueNotifier('quran'); // quran | meal | both
  final ValueNotifier<String> audioMealNotifier = ValueNotifier('diyanet'); // diyanet | yazir | english
  final ValueNotifier<bool> audioPlayingNotifier = ValueNotifier(false);
  bool _quranPlaying = false;
  bool _ttsSpeaking = false;
  bool _mealAfterQuran = false;
  bool get isPlaying => audioPlayingNotifier.value;

  void _syncPlaying() {
    audioPlayingNotifier.value = _quranPlaying || _ttsSpeaking || _mealAfterQuran;
  }

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  List<PrayerAlarm> prayerAlarms = List.generate(_prayerAlarmCount, (_) => PrayerAlarm());
  bool get azanReminderEnabled => prayerAlarms.any((a) => a.enabled);
  // 'fullscreen': çalan tam ekran alarm, 'notification': sadece sesli bildirim.
  String alarmMode = 'fullscreen';
  String? _lastWidgetKey;

  int get _dailyTab => dailyTabNotifier.value;
  set _dailyTab(int v) => dailyTabNotifier.value = v;

  void _onDailyTabChanged() {
    if (mounted) setState(() {});
  }

  final ValueNotifier<String?> audioNotice = ValueNotifier(null);
  Timer? _audioNoticeTimer;

  void _showAudioNotice([String? message]) {
    audioNotice.value = message ??
        t(
          "Sesli okunuş için internet gerekiyor. Lütfen mobil veriyi veya Wi-Fi'ı aç.",
          "Audio recitation needs an internet connection. Please turn on mobile data or Wi-Fi.",
        );
    _audioNoticeTimer?.cancel();
    _audioNoticeTimer = Timer(const Duration(seconds: 6), () => audioNotice.value = null);
  }

  final ValueNotifier<String?> offlineNotice = ValueNotifier(null);

  // Wi-Fi bağlı değilse önce uyarır; kullanıcı onaylarsa mobil veriyle de indirebilir.
  Future<void> _requestOfflineDownload() async {
    if (OfflineQuran.state.value != OfflineState.none) return;
    offlineNotice.value = null;

    var connections = <ConnectivityResult>[];
    try {
      connections = await Connectivity().checkConnectivity();
    } catch (_) {}
    if (!mounted) return;
    final onWifi = connections.contains(ConnectivityResult.wifi) || connections.contains(ConnectivityResult.ethernet);
    if (!onWifi) {
      final noConnection = connections.isEmpty || connections.every((c) => c == ConnectivityResult.none);
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(noConnection
              ? t("İnternet bağlantısı yok", "No internet connection")
              : t("Wi-Fi bağlı değil", "Wi-Fi is not connected")),
          content: Text(noConnection
              ? t("İndirmek için mobil veriyi veya Wi-Fi'ı açman gerekiyor.", "Turn on mobile data or Wi-Fi to download.")
              : t("Kur'an metni yaklaşık 9 MB'tır ve mobil veriyle indirilirse kotandan düşer. Yine de indirmek ister misin?",
                  "The Quran text is about 9 MB and will use your mobile data. Download anyway?")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(noConnection ? t("Tamam", "OK") : t("Vazgeç", "Cancel"))),
            if (!noConnection)
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t("Yine de indir", "Download anyway"))),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final result = await OfflineQuran.download();
    if (!mounted) return;
    switch (result) {
      case OfflineResult.ok:
        _showSnackBar(t("Ayetler çevrimdışı kullanıma hazır.", "Verses are ready for offline use."));
      case OfflineResult.noInternet:
        offlineNotice.value = t(
          "İnternet bağlantısı yok. Mobil veriyi veya Wi-Fi'ı açıp tekrar dene.",
          "No internet connection. Turn on mobile data or Wi-Fi and try again.",
        );
        _showSnackBar(offlineNotice.value!);
      case OfflineResult.failed:
        offlineNotice.value = t(
          "İndirme tamamlanamadı. Bağlantını kontrol edip tekrar dene.",
          "The download could not be completed. Check your connection and try again.",
        );
        _showSnackBar(offlineNotice.value!);
    }
  }

  /// Ayet kartındaki küçük "indir" simgesi; indirildiyse hiç görünmez.
  Widget _buildOfflineDownloadIcon({bool onDark = false}) {
    return ValueListenableBuilder<OfflineState>(
      valueListenable: OfflineQuran.state,
      builder: (context, st, _) {
        if (kIsWeb || st == OfflineState.ready) return const SizedBox.shrink();
        if (st == OfflineState.downloading) {
          return ValueListenableBuilder<double>(
            valueListenable: OfflineQuran.progress,
            builder: (context, p, _) => Padding(
              padding: const EdgeInsets.only(left: 10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: p == 0 ? null : p,
                  color: onDark ? Colors.white : Colors.green,
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(left: 10),
          child: IconButton(
            icon: Icon(Icons.download, size: 20, color: onDark ? Colors.white : Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: t("Çevrimdışı okumak için indir (~9 MB)", "Download for offline reading (~9 MB)"),
            onPressed: _requestOfflineDownload,
          ),
        );
      },
    );
  }

  Widget _buildOfflineTile() {
    return ValueListenableBuilder<OfflineState>(
      valueListenable: OfflineQuran.state,
      builder: (context, st, _) {
        if (st == OfflineState.downloading) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_download_outlined),
            title: Text(t("Kur'an metni indiriliyor…", "Downloading Quran text…")),
            subtitle: ValueListenableBuilder<double>(
              valueListenable: OfflineQuran.progress,
              builder: (context, p, _) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(value: p == 0 ? null : p),
              ),
            ),
          );
        }
        if (st == OfflineState.ready) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.offline_pin, color: Colors.green),
            title: Text(t("Çevrimdışı Kur'an Metni", "Offline Quran Text")),
            subtitle: Text(t(
              "İndirildi: tüm ayetler internetsiz okunabilir. (Sesli okunuş internet ister.)",
              "Downloaded: all verses can be read without internet. (Audio recitation needs internet.)",
            )),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: t("Sil", "Delete"),
              onPressed: OfflineQuran.delete,
            ),
          );
        }
        return ValueListenableBuilder<String?>(
          valueListenable: offlineNotice,
          builder: (context, msg, _) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_download_outlined),
            title: Text(t("Çevrimdışı Kur'an Metni", "Offline Quran Text")),
            subtitle: Text(
              msg ??
                  t(
                    "Tüm ayetleri internetsiz okumak için indir (~9 MB indirme, ~5 MB yer). Wi-Fi önerilir.",
                    "Download all verses to read without internet (~9 MB download, ~5 MB storage). Wi-Fi recommended.",
                  ),
              style: msg == null ? null : TextStyle(color: Colors.red[700]),
            ),
            onTap: _requestOfflineDownload,
          ),
        );
      },
    );
  }

  void _onAppearanceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onLangChanged() {
    if (!mounted) return;
    setState(() {});
    _updateTimeLeft();
    if (azanReminderEnabled) _scheduleAzanReminders();
  }


  final List<String> _cities = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin', 'Aydın', 'Balıkesir', 
    'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 
    'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 
    'Isparta', 'Mersin', 'İstanbul', 'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir', 'Kocaeli', 
    'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir', 'Niğde', 'Ordu', 
    'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Şanlıurfa', 
    'Uşak', 'Van', 'Yozgat', 'Zonguldak', 'Aksaray', 'Bayburt', 'Karaman', 'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 
    'Ardahan', 'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce'
  ];

  @override
  void initState() {
    super.initState();
    dailyTabNotifier.addListener(_onDailyTabChanged);
    langNotifier.addListener(_onLangChanged);
    themeNotifier.addListener(_onAppearanceChanged);
    colorThemeNotifier.addListener(_onAppearanceChanged);
    figureNotifier.addListener(_onAppearanceChanged);
    _cities.sort();
    // Önce kayıtlı şehirle hesapla; konum izni verilmiş ve internet varsa konumu bulup güncelle.
    _loadSavedCity().then((_) {
      if (mounted) _autoLocate();
    });
    _initAyah();
    
    audioPlayer = AudioPlayer();
    audioPlayer!.onPlayerStateChanged.listen((state) {
      _quranPlaying = state == PlayerState.playing;
      _syncPlaying();
    });
    audioPlayer!.onPlayerComplete.listen((event) {
      _quranPlaying = false;
      if (!mounted) return;
      if (_mealAfterQuran) {
        // "İkisi de" seçiliyse Kur'an bitince aynı ayetin meali okunur.
        _mealAfterQuran = false;
        _speakMeal();
        return;
      }
      _syncPlaying();
      if (isAutoPlaying) {
        _nextAyah();
      }
    });
    _initTts();
    _loadAudioPrefs();
    
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      _updateTimeLeft();
      setState((){}); // forces build to update the top-right clock directly
    });

    _loadBannerAd();
    _checkForUpdate();
    _loadAzanReminderSetting();
  }

  @override
  void dispose() {
    _audioNoticeTimer?.cancel();
    dailyTabNotifier.removeListener(_onDailyTabChanged);
    langNotifier.removeListener(_onLangChanged);
    themeNotifier.removeListener(_onAppearanceChanged);
    colorThemeNotifier.removeListener(_onAppearanceChanged);
    figureNotifier.removeListener(_onAppearanceChanged);
    timer?.cancel();
    audioPlayer?.dispose();
    tts.stop();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    _bannerAd = BannerAd(
      adUnitId: Platform.isIOS
          ? 'ca-app-pub-9864338488985680/6030487575'
          : 'ca-app-pub-9864338488985680/1217505985',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint("Banner reklam yüklenemedi: $error");
        },
      ),
    )..load();
  }

  Future<void> _checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(days: 1),
              content: Text(t("Yeni bir sürüm indirildi.", "A new version has been downloaded.")),
              action: SnackBarAction(
                label: t("GÜNCELLE", "UPDATE"),
                onPressed: () => InAppUpdate.completeFlexibleUpdate(),
              ),
            ),
          );
        } else if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      debugPrint("Güncelleme kontrolü başarısız: $e");
    }
  }

  Future<void> _loadSavedCity() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString('saved_city');
    
    if (savedCity != null && _cities.contains(savedCity)) {
      setState(() {
        currentCity = savedCity;
      });
    } else {
      setState(() {
        currentCity = "İstanbul";
      });
    }
    
    await _calculatePrayerTimesForCity(currentCity);
  }

  Future<void> _saveCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_city', city);
  }

  Future<void> _calculatePrayerTimesForCity(String city) async {
    try {
      if (cityCoordinates.containsKey(city)) {
        final coords = cityCoordinates[city]!;
        setState(() {
          activeCoordinates = Coordinates(coords[0], coords[1]);
        });
        _calculatePrayerTimes(activeCoordinates!);
      } else {
        // Fallback to İstanbul
        final coords = cityCoordinates['İstanbul']!;
        setState(() {
          activeCoordinates = Coordinates(coords[0], coords[1]);
        });
        _calculatePrayerTimes(activeCoordinates!);
      }
    } catch (e) {
      debugPrint("Koordinat bulunamadı: $e");
    }
  }

  Future<void> _initAyah() async {
    final prefs = await SharedPreferences.getInstance();
    
    final currentDay = DateTime.now().difference(DateTime(2000, 1, 1)).inDays;
    int lastReadDate = prefs.getInt('last_read_date') ?? 0;
    int lastReadVerse = prefs.getInt('last_read_verse') ?? 0;
    
    if (lastReadDate == currentDay && lastReadVerse > 0) {
      displayedAyahNumber = lastReadVerse;
    } else {
      int installDay = prefs.getInt('install_epoch_day') ?? 0;
      if (installDay == 0) {
        installDay = currentDay;
        await prefs.setInt('install_epoch_day', installDay);
      }
      displayedAyahNumber = ((currentDay - installDay) % 6236) + 1;
    }
    
    _fetchAyah(displayedAyahNumber!);
  }

  Future<void> _saveLastReadVerse() async {
    if (displayedAyahNumber != null) {
      final prefs = await SharedPreferences.getInstance();
      final currentDay = DateTime.now().difference(DateTime(2000, 1, 1)).inDays;
      await prefs.setInt('last_read_date', currentDay);
      await prefs.setInt('last_read_verse', displayedAyahNumber!);
    }
  }

  Future<void> _fetchAyah(int ayahNumber) async {
    setState(() => isLoadingAyah = true);
    if (isPlaying) {
      _stopAllAudio();
    }

    await OfflineQuran.initFuture;
    final offlineAyah = OfflineQuran.getAyah(ayahNumber);
    if (offlineAyah != null) {
      if (!mounted) return;
      setState(() {
        dailyAyahData = offlineAyah;
        dailyAyahNotifier.value = offlineAyah;
        isLoadingAyah = false;
      });
      if (isAutoPlaying) {
        _playOnlyAudio();
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = "ayah_cache_uthmani_audio_en_$ayahNumber";
    
    if (prefs.containsKey(cacheKey)) {
      setState(() {
        dailyAyahData = json.decode(prefs.getString(cacheKey)!);
        dailyAyahNotifier.value = dailyAyahData;
        isLoadingAyah = false;
      });
      if (isAutoPlaying) {
        _playOnlyAudio();
      }
      return;
    }
    
    try {
      final response = await http.get(Uri.parse('https://api.alquran.cloud/v1/ayah/$ayahNumber/editions/quran-uthmani,tr.transliteration,tr.diyanet,tr.yazir,en.sahih,ar.alafasy'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data']; 
        final ayahSave = {
          'arabic': list[0]['text'],
          'transliteration': list[1]['text'],
          'turkish1': list[2]['text'],
          'turkish2': list[3]['text'],
          'english': list[4]['text'],
          'surah': list[2]['surah']['englishName'], 
          'numberInSurah': list[0]['numberInSurah'],
          'audioUrl': list[5]['audio']
        };
        
        await prefs.setString(cacheKey, json.encode(ayahSave));
        if (mounted) {
          setState(() {
            dailyAyahData = ayahSave;
            dailyAyahNotifier.value = dailyAyahData;
            isLoadingAyah = false;
          });
          if (isAutoPlaying) {
            _playOnlyAudio();
          }
        }
      } else {
        if (mounted) setState(() => isLoadingAyah = false);
      }
    } catch(e) {
       if (mounted) setState(() => isLoadingAyah = false);
    }
  }

  void _playOnlyAudio() => _startAyahAudio();

  Future<void> _initTts() async {
    tts.setCompletionHandler(() {
      _ttsSpeaking = false;
      _syncPlaying();
      if (mounted && isAutoPlaying) _nextAyah();
    });
    tts.setCancelHandler(() {
      _ttsSpeaking = false;
      _syncPlaying();
    });
    tts.setErrorHandler((_) {
      _ttsSpeaking = false;
      _syncPlaying();
    });
    try {
      await tts.setSpeechRate(0.45);
    } catch (_) {}
  }

  Future<void> _loadAudioPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('audio_mode');
    final meal = prefs.getString('audio_meal');
    if (mode == 'quran' || mode == 'meal' || mode == 'both') audioModeNotifier.value = mode!;
    if (meal == 'diyanet' || meal == 'yazir' || meal == 'english') audioMealNotifier.value = meal!;
  }

  Future<void> _setAudioMode(String mode) async {
    await _stopAllAudio();
    isAutoPlaying = false;
    audioModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_mode', mode);
  }

  Future<void> _setAudioMeal(String meal) async {
    await _stopAllAudio();
    isAutoPlaying = false;
    audioMealNotifier.value = meal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_meal', meal);
  }

  Future<void> _stopAllAudio() async {
    _mealAfterQuran = false;
    try {
      await audioPlayer?.stop();
      await tts.stop();
    } catch (_) {}
    _quranPlaying = false;
    _ttsSpeaking = false;
    _syncPlaying();
  }

  /// Seçili mealı telefonun sesli okuma özelliğiyle okutur.
  Future<void> _speakMeal() async {
    final data = dailyAyahData;
    if (data == null) {
      _syncPlaying();
      return;
    }
    final meal = audioMealNotifier.value;
    final key = meal == 'yazir' ? 'turkish2' : (meal == 'english' ? 'english' : 'turkish1');
    final text = (data[key] as String?)?.trim() ?? '';
    if (text.isEmpty) {
      _syncPlaying();
      return;
    }
    final lang = meal == 'english' ? 'en-US' : 'tr-TR';
    try {
      final available = await tts.isLanguageAvailable(lang);
      if (available != true && available != 1) {
        isAutoPlaying = false;
        final langTr = meal == 'english' ? 'İngilizce' : 'Türkçe';
        final langEn = meal == 'english' ? 'English' : 'Turkish';
        _showAudioNotice(_isIos
            ? t(
                "iPhone'unda $langTr ses bulunamadı. Ayarlar > Erişilebilirlik > Seslendirilen İçerik > Sesler bölümünden $langTr bir ses indir.",
                "No $langEn voice was found on your iPhone. Download one in Settings > Accessibility > Spoken Content > Voices.",
              )
            : t(
                "Telefonunda $langTr sesli okuma bulunamadı. Telefon ayarlarından \"Metin okuma\" için $langTr ses paketini indir.",
                "No $langEn text-to-speech voice was found. Install one in your phone's \"Text-to-speech\" settings.",
              ));
        _syncPlaying();
        return;
      }
      await tts.setLanguage(lang);
      _ttsSpeaking = true;
      _syncPlaying();
      await tts.speak(text);
    } catch (e) {
      debugPrint("TTS ERROR: $e");
      _ttsSpeaking = false;
      _syncPlaying();
    }
  }

  /// Kur'an okunuşunun adresi. Web'de cdn.islamic.network tarayıcının CORS engeline takıldığı
  /// için aynı hafızın (Mişarî el-Afâsî) sesini CORS izinli everyayah.com'dan alırız.
  String? _quranAudioUrl(Map<String, dynamic> data) {
    final n = displayedAyahNumber;
    if (kIsWeb && n != null) {
      final surahIndex = _getSurahIndex(n);
      final surah = (surahIndex + 1).toString().padLeft(3, '0');
      final ayah = (n - _surahStarts[surahIndex] + 1).toString().padLeft(3, '0');
      return 'https://everyayah.com/data/Alafasy_128kbps/$surah$ayah.mp3';
    }
    return data['audioUrl'] as String?;
  }

  /// Seçime göre bu ayetin sesini başlatır: yalnız Kur'an, yalnız meal ya da önce Kur'an sonra meal.
  Future<void> _startAyahAudio() async {
    final data = dailyAyahData;
    if (audioPlayer == null || data == null) return;
    final mode = audioModeNotifier.value;
    if (mode == 'meal') {
      await _speakMeal();
      return;
    }
    final audioUrl = _quranAudioUrl(data);
    if (audioUrl == null) {
      if (mode == 'both') await _speakMeal();
      return;
    }
    if (!await hasInternet()) {
      isAutoPlaying = false;
      _showAudioNotice();
      return;
    }
    _mealAfterQuran = mode == 'both';
    _syncPlaying();
    await audioPlayer!.play(UrlSource(audioUrl));
  }

  void _nextAyah() {
    if (displayedAyahNumber != null) {
      displayedAyahNumber = (displayedAyahNumber! % 6236) + 1;
      _saveLastReadVerse();
      _fetchAyah(displayedAyahNumber!);
    }
  }

  void _prevAyah() {
    if (displayedAyahNumber != null) {
      displayedAyahNumber = displayedAyahNumber! - 1;
      if (displayedAyahNumber! <= 0) displayedAyahNumber = 6236;
      _saveLastReadVerse();
      _fetchAyah(displayedAyahNumber!);
    }
  }

  static const List<int> _ayahCountPerSurah = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
    123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
    112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
    54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
    60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
    14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
    28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
    29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
    15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
    11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
    5, 4, 5, 6
  ];

  static final List<int> _surahStarts = (() {
    List<int> starts = [];
    int current = 1;
    for (int count in _ayahCountPerSurah) {
      starts.add(current);
      current += count;
    }
    return starts;
  })();

  int _getSurahIndex(int ayahNumber) {
    for (int i = 0; i < 114; i++) {
       if (i == 113) return 113;
       if (ayahNumber >= _surahStarts[i] && ayahNumber < _surahStarts[i+1]) {
         return i;
       }
    }
    return 0;
  }

  void _nextSurah() {
    if (displayedAyahNumber != null) {
      int sIndex = _getSurahIndex(displayedAyahNumber!);
      int nextIndex = (sIndex + 1) % 114;
      displayedAyahNumber = _surahStarts[nextIndex];
      _saveLastReadVerse();
      _fetchAyah(displayedAyahNumber!);
    }
  }

  void _prevSurah() {
    if (displayedAyahNumber != null) {
      int sIndex = _getSurahIndex(displayedAyahNumber!);
      int prevIndex = (sIndex - 1) % 114;
      if (prevIndex < 0) prevIndex += 114;
      displayedAyahNumber = _surahStarts[prevIndex];
      _saveLastReadVerse();
      _fetchAyah(displayedAyahNumber!);
    }
  }

  void _toggleAudio() async {
    if (audioPlayer == null || dailyAyahData == null) return;
    if (isPlaying) {
      isAutoPlaying = false;
      await _stopAllAudio();
    } else {
      isAutoPlaying = true;
      try {
        await _startAyahAudio();
      } catch (e) {
        debugPrint("AUDIO PLAY ERROR: $e");
      }
    }
  }

  /// Konumdan şehir bulur. Şehir adını bulmak internet ister; yoksa koordinata en yakın şehre düşülür.
  Future<({String city, bool geocoded})> _cityForPosition(Position position) async {
    List<Placemark> placemarks = [];
    try {
      placemarks = await placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
    final geocoded = placemarks.isNotEmpty;
    final place = geocoded ? placemarks[0] : null;
    String foundCity = place == null
        ? _nearestCity(position.latitude, position.longitude)
        : (place.administrativeArea ?? place.locality ?? "İstanbul");

    // "Istanbul Province" gibi İngilizce yanıtlardaki "Province" kelimesini at.
    if (foundCity.toLowerCase().contains("province")) {
      foundCity = foundCity.split(" ")[0];
    }

    // Kendi şehir listemizle eşleştir.
    final matched = _cities.firstWhere(
      (c) => c.toLowerCase() == foundCity.toLowerCase(),
      orElse: () => "İstanbul",
    );
    return (city: matched, geocoded: geocoded);
  }

  Future<void> _findLocationInBackground() async {
    setState(() {
      isLocating = true;
    });

    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(t("Konum servisleri kapalı.", "Location services are turned off."));
        setState(() => isLocating = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar(t("Konum izni reddedildi.", "Location permission was denied."));
          setState(() => isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(t("Konum izni kalıcı olarak reddedildi.", "Location permission was permanently denied."));
        setState(() => isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final found = await _cityForPosition(position);

      setState(() {
        currentCity = found.city;
        activeCoordinates = Coordinates(position.latitude, position.longitude);
      });
      await _saveCity(found.city);
      _calculatePrayerTimes(activeCoordinates!);
      _showSnackBar(found.geocoded
          ? t("${found.city} konumu bulundu.", "Location found: ${found.city}.")
          : t(
              "İnternet yok: konumuna en yakın şehir seçildi (${found.city}). Daha doğru sonuç için mobil veriyi veya Wi-Fi'ı aç.",
              "No internet: the nearest city was selected (${found.city}). Turn on mobile data or Wi-Fi for a more accurate result.",
            ));
    } catch (e) {
      _showSnackBar(e is TimeoutException
          ? t(
              "Konum alınamadı. Açık bir alana çıkıp konum servisinin açık olduğundan emin ol.",
              "Could not get a location fix. Move to an open area and make sure location services are on.",
            )
          : t("Konum alınırken hata oluştu.", "Could not get your location."));
    } finally {
      if (mounted) {
        setState(() {
          isLocating = false;
        });
      }
    }
  }

  bool _autoLocating = false;

  /// Açılışta arka planda çalışır; ekranda hiçbir şey göstermez (yükleme çarkı, mesaj yok) ve
  /// uygulamayı bekletmez. İzin istemez; yalnızca izin zaten verilmişse, konum servisi açıksa ve
  /// internet varsa devam eder. İnternet yoksa son seçili şehirle açık kalınır.
  ///
  /// Bulunan şehir mevcut şehirle aynıysa yalnızca koordinat inceltilir. Farklıysa kullanıcıya
  /// sorulur; "Kalsın" denirse aynı şehir için bir daha sorulmaz.
  Future<void> _autoLocate() async {
    if (_autoLocating || isLocating) return;
    _autoLocating = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) return;
      if (!await hasInternet()) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final found = await _cityForPosition(position);
      if (!mounted) return;

      if (found.city == currentCity) {
        // Aynı şehir: sadece konumu inceltip yeniden hesapla.
        setState(() {
          activeCoordinates = Coordinates(position.latitude, position.longitude);
        });
        _calculatePrayerTimes(activeCoordinates!);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('declined_location_city') == found.city) return;
      if (!mounted) return;

      final switchCity = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t("Konumun değişmiş görünüyor", "Your location seems to have changed")),
          content: Text(t(
            "Şu an ${found.city} civarındasın, ama vakitler $currentCity için hesaplanıyor. Vakitleri ${found.city} konumuna göre güncelleyelim mi?",
            "You appear to be near ${found.city}, but prayer times are calculated for $currentCity. Update them for ${found.city}?",
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t("$currentCity kalsın", "Keep $currentCity")),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t("${found.city} yap", "Use ${found.city}")),
            ),
          ],
        ),
      );
      if (!mounted) return;

      if (switchCity == true) {
        setState(() {
          currentCity = found.city;
          activeCoordinates = Coordinates(position.latitude, position.longitude);
        });
        await _saveCity(found.city);
        await prefs.remove('declined_location_city');
        _calculatePrayerTimes(activeCoordinates!);
      } else if (switchCity == false) {
        await prefs.setString('declined_location_city', found.city);
      }
    } catch (e) {
      // Arka plan işlemi: hata olursa sessizce kayıtlı şehirle devam edilir.
      debugPrint("Otomatik konum bulunamadı: $e");
    } finally {
      _autoLocating = false;
    }
  }

  String _nearestCity(double lat, double lon) {
    var best = "İstanbul";
    var bestDistance = double.infinity;
    for (final city in _cities) {
      final c = cityCoordinates[city];
      if (c == null) continue;
      final d = Geolocator.distanceBetween(lat, lon, c[0], c[1]);
      if (d < bestDistance) {
        bestDistance = d;
        best = city;
      }
    }
    return best;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Diyanet'in yayımladığı vakitlerle uyumlu hesap: Türkiye yöntemi ve standart (Şâfiî) ikindi.
  /// Hanefi ikindi (gölge boyu 2 katı) yaklaşık 45 dakika daha geç çıkar ve Diyanet takviminden farklıdır.
  CalculationParameters _prayerCalcParams() {
    return CalculationMethod.turkey.getParameters()..madhab = Madhab.shafi;
  }

  void _calculatePrayerTimes(Coordinates coordinates) {
    final params = _prayerCalcParams();
    
    final pTimes = PrayerTimes.today(coordinates, params);
    setState(() {
      prayerTimes = pTimes;
    });
    _updateTimeLeft();
    if (azanReminderEnabled) {
      _scheduleAzanReminders();
    }
  }

  Future<void> _loadAzanReminderSetting() async {
    final prefs = await SharedPreferences.getInstance();
    // Eski tek-alarm ayarlarını ilk açılışta her vakte aktar.
    final legacyEnabled = prefs.getBool('azan_reminder_enabled') ?? false;
    final legacyMinutes = prefs.getInt('azan_reminder_minutes') ?? 15;
    final legacyUri = prefs.getString('azan_sound_uri');
    final legacyTitle = prefs.getString('azan_sound_title');
    final loaded = List.generate(
      _prayerAlarmCount,
      (i) => PrayerAlarm(
        enabled: prefs.getBool('alarm_${i}_enabled') ?? (legacyEnabled && i != 1),
        minutes: prefs.getInt('alarm_${i}_minutes') ?? legacyMinutes,
        soundUri: prefs.getString('alarm_${i}_sound_uri') ?? legacyUri,
        soundTitle: prefs.getString('alarm_${i}_sound_title') ?? legacyTitle,
        oneMinute: prefs.getBool('alarm_${i}_one_minute') ?? false,
      ),
    );
    if (!mounted) return;
    setState(() {
      prayerAlarms = loaded;
      alarmMode = prefs.getString('alarm_mode') == 'notification' ? 'notification' : 'fullscreen';
    });
    if (azanReminderEnabled && prayerTimes != null) {
      _scheduleAzanReminders();
    }
  }

  Future<void> _savePrayerAlarm(int i) async {
    final prefs = await SharedPreferences.getInstance();
    final a = prayerAlarms[i];
    await prefs.setBool('alarm_${i}_enabled', a.enabled);
    await prefs.setInt('alarm_${i}_minutes', a.minutes);
    await prefs.setBool('alarm_${i}_one_minute', a.oneMinute);
    if (a.soundUri != null) {
      await prefs.setString('alarm_${i}_sound_uri', a.soundUri!);
    }
    if (a.soundTitle != null) {
      await prefs.setString('alarm_${i}_sound_title', a.soundTitle!);
    }
  }

  Future<void> _pickAlarmSound(int i) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.music_note_outlined),
              title: Text(t("Zil sesi seç", "Choose ringtone")),
              onTap: () => Navigator.pop(context, 'ringtone'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(t("Dosyadan seç", "Choose from file")),
              subtitle: Text(t("Telefondaki bir ses dosyası (ör. mp3)", "An audio file on your phone (e.g. mp3)")),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            if (prayerAlarms[i].soundUri != null)
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: Text(t("Varsayılan sese dön", "Reset to default")),
                onTap: () => Navigator.pop(context, 'reset'),
              ),
          ],
        ),
      ),
    );
    if (source == 'ringtone') {
      await _pickRingtoneSound(i);
    } else if (source == 'file') {
      await _pickFileSound(i);
    } else if (source == 'reset') {
      setState(() {
        prayerAlarms[i].soundUri = null;
        prayerAlarms[i].soundTitle = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_${i}_sound_uri');
      await prefs.remove('alarm_${i}_sound_title');
      await _scheduleAzanReminders();
    }
  }

  Future<void> _pickFileSound(int i) async {
    try {
      final picked = await ringtoneChannel.invokeMethod<Map<Object?, Object?>>('pickAudioFile');
      if (picked == null) return;
      final uri = picked['uri'] as String?;
      if (uri == null) return;
      if (!mounted) return;
      setState(() {
        prayerAlarms[i].soundUri = uri;
        prayerAlarms[i].soundTitle = (picked['title'] as String?) ?? t('Özel Ses', 'Custom sound');
      });
      await _savePrayerAlarm(i);
      await _scheduleAzanReminders();
    } catch (e) {
      debugPrint("Ses dosyası seçilemedi: $e");
    }
  }

  Future<void> _pickRingtoneSound(int i) async {
    try {
      final pickedUri = await ringtoneChannel.invokeMethod<String>(
        'pickRingtone',
        {
          'currentUri': prayerAlarms[i].soundUri,
          'title': t('Alarm Sesi Seç', 'Choose Alarm Sound'),
        },
      );
      if (pickedUri == null) return;

      final title = await ringtoneChannel.invokeMethod<String>(
            'getRingtoneTitle',
            {'uri': pickedUri},
          ) ??
          t('Özel Ses', 'Custom sound');

      if (!mounted) return;
      setState(() {
        prayerAlarms[i].soundUri = pickedUri;
        prayerAlarms[i].soundTitle = title;
      });
      await _savePrayerAlarm(i);
      _scheduleAzanReminders();
    } catch (e) {
      debugPrint("Alarm sesi seçilemedi: $e");
    }
  }

  Future<void> _requestAlarmPermissions() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    if (_isIos) {
      final iosPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(alert: true, sound: true);
      if (granted == false && mounted) {
        _showSnackBar(t(
          "Bildirim izni verilmedi. Hatırlatıcı için Ayarlar'dan bildirimlere izin ver.",
          "Notification permission was not granted. Allow notifications in Settings for the reminder.",
        ));
      }
    }

    if (!kIsWeb && Platform.isAndroid) {
      final canScheduleExact = await ringtoneChannel.invokeMethod<bool>('canScheduleExactAlarms') ?? true;
      if (!canScheduleExact && mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t('İzin Gerekli', 'Permission Required')),
            content: Text(t(
              'Ezan hatırlatıcısının tam zamanında çalabilmesi için "Alarmlar ve Hatırlatıcılar" iznini açman gerekiyor. Açılan ayarlar ekranından bu uygulamaya izin ver.',
              'To ring exactly on time, the azan reminder needs the "Alarms & reminders" permission. Please allow it for this app in the settings screen that opens.',
            )),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t('Vazgeç', 'Cancel')),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ringtoneChannel.invokeMethod('requestExactAlarmPermission');
                },
                child: Text(t('Ayarları Aç', 'Open Settings')),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _setAlarmEnabled(int i, bool value) async {
    final wasAnyEnabled = azanReminderEnabled;
    setState(() {
      prayerAlarms[i].enabled = value;
    });
    await _savePrayerAlarm(i);
    if (value && !wasAnyEnabled) {
      await _requestAlarmPermissions();
    }
    await _scheduleAzanReminders();
  }

  Future<void> _setAlarmMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_mode', mode);
    setState(() {
      alarmMode = mode;
    });
    await _scheduleAzanReminders();
  }

  Future<void> _setAlarmMinutes(int i, int minutes) async {
    setState(() {
      prayerAlarms[i].minutes = minutes;
    });
    await _savePrayerAlarm(i);
    await _scheduleAzanReminders();
  }

  Future<void> _pickAlarmMinutes(int i) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(t("Ne kadar önce uyarılsın?", "How long before?")),
        children: [
          for (final m in _alarmMinuteOptions)
            ListTile(
              title: Text(_minutesLabel(m)),
              trailing: prayerAlarms[i].minutes == m ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, m),
            ),
        ],
      ),
    );
    if (picked != null) await _setAlarmMinutes(i, picked);
  }

  String _durationLabel(PrayerAlarm a) =>
      a.oneMinute ? t("1 dk. çalsın", "Rings 1 min") : t("Ses bitene kadar", "Until sound ends");

  Future<void> _pickAlarmDuration(int i) async {
    final picked = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(t("Alarm ne kadar çalsın?", "How long should it ring?")),
        children: [
          ListTile(
            title: Text(t("Ses bitene kadar", "Until the sound ends")),
            subtitle: Text(t("Ses dosyası bir kez çalar, bitince alarm susar.", "The sound plays once and the alarm stops.")),
            trailing: !prayerAlarms[i].oneMinute ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, false),
          ),
          ListTile(
            title: Text(t("1 dakika", "1 minute")),
            subtitle: Text(t("Ses 1 dakika boyunca tekrar eder.", "The sound repeats for 1 minute.")),
            trailing: prayerAlarms[i].oneMinute ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() {
      prayerAlarms[i].oneMinute = picked;
    });
    await _savePrayerAlarm(i);
    await _scheduleAzanReminders();
  }

  static const List<int> _alarmMinuteOptions = [0, 1, 5, 10, 15, 20, 30, 45, 60];

  String _minutesLabel(int m) =>
      m == 0 ? t("Vaktinde", "On time") : t("${m}dk. önce", "$m min before");

  String _alarmLabel(int i) {
    const tr = ["İmsaktan", "Güneşten", "Öğleden", "İkindiden", "Akşamdan", "Yatsıdan"];
    return isEnglish ? _getPrayerName(_prayerFromIndex(i)) : tr[i];
  }

  DateTime _prayerTimeAt(PrayerTimes times, int i) => [
        times.fajr,
        times.sunrise,
        times.dhuhr,
        times.asr,
        times.maghrib,
        times.isha,
      ][i];

  Future<void> _scheduleAzanReminders() async {
    if (kIsWeb) return;
    if (!azanReminderEnabled) {
      await _cancelAzanReminders();
      return;
    }
    if (prayerTimes == null) return;
    if (_isIos) {
      await _scheduleIosReminders();
      return;
    }
    await _cancelAzanReminders();

    for (var i = 0; i < _prayerAlarmCount; i++) {
      final alarm = prayerAlarms[i];
      if (!alarm.enabled) continue;
      final reminderTime = _prayerTimeAt(prayerTimes!, i).subtract(Duration(minutes: alarm.minutes));
      if (reminderTime.isBefore(DateTime.now())) continue;

      final prayerName = _getPrayerName(_prayerFromIndex(i));
      await ringtoneChannel.invokeMethod('scheduleAzanAlarm', {
        'id': i,
        'triggerAtMillis': reminderTime.millisecondsSinceEpoch,
        'prayerName': prayerName,
        'title': alarm.minutes == 0
            ? t("$prayerName Vakti", "$prayerName time")
            : t("$prayerName vaktine ${alarm.minutes} dakika kaldı", "${alarm.minutes} minutes until $prayerName"),
        'body': t(
          "Durdurmak için dokunun",
          "Tap to stop",
        ),
        'stopLabel': t("Durdur", "Stop"),
        'soundUri': alarm.soundUri,
        'mode': alarmMode,
        'repeat': alarm.oneMinute,
      });
    }
  }

  Prayer _prayerFromIndex(int index) {
    switch (index) {
      case 0: return Prayer.fajr;
      case 1: return Prayer.sunrise;
      case 2: return Prayer.dhuhr;
      case 3: return Prayer.asr;
      case 4: return Prayer.maghrib;
      default: return Prayer.isha;
    }
  }

  // Mağaza ekran görüntüleri web'den çekilirken iOS metinlerini göstermek için
  // (--dart-define=STORE_SHOT_IOS=true). Normal derlemelerde false.
  static const bool _storeShotIos = bool.fromEnvironment('STORE_SHOT_IOS');
  bool get _isIos => _storeShotIos || (!kIsWeb && Platform.isIOS);

  Rect _shareOrigin() {
    final s = MediaQuery.sizeOf(context);
    return Rect.fromCenter(center: Offset(s.width / 2, s.height / 2), width: 1, height: 1);
  }

  // iOS'ta uygulama kapalıyken telefon gibi çalan alarm kurulamaz; bunun yerine ezandan
  // önce sesli bildirim gönderilir. Uygulama açılmasa da sürsün diye 7 gün önceden kurulur.
  Future<void> _scheduleIosReminders() async {
    final coords = activeCoordinates;
    if (coords == null) return;
    await _cancelAzanReminders();

    final params = _prayerCalcParams();
    final now = DateTime.now();
    var id = 0;
    for (var day = 0; day < 7; day++) {
      final date = now.add(Duration(days: day));
      final times = PrayerTimes(coords, DateComponents(date.year, date.month, date.day), params);
      for (var i = 0; i < _prayerAlarmCount; i++) {
        final alarm = prayerAlarms[i];
        if (!alarm.enabled) continue;
        final at = _prayerTimeAt(times, i).subtract(Duration(minutes: alarm.minutes));
        if (at.isBefore(now)) continue;
        final name = _getPrayerName(_prayerFromIndex(i));
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: id++,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          // Ses verilmediği için iOS'un varsayılan bildirim sesi çalar. Üçüncü taraf uygulamalar
          // sistem zil sesini ya da alarm sesini kullanamaz; özel ses ancak uygulama paketine
          // eklenen (en fazla 30 sn.) bir dosyayla mümkündür.
          notificationDetails: const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              presentBanner: true,
              presentList: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          title: alarm.minutes == 0
              ? t("$name vakti geldi", "It's $name time")
              : t("$name vakti yaklaşıyor", "$name time is approaching"),
          body: alarm.minutes == 0
              ? t("Namaz vakti girdi.", "Prayer time has begun.")
              : t(
                  "Namaz vaktine ${alarm.minutes} dakika kaldı.",
                  "${alarm.minutes} minutes until prayer time.",
                ),
        );
      }
    }
  }

  Future<void> _cancelAzanReminders() async {
    if (kIsWeb) return;
    if (_isIos) {
      await flutterLocalNotificationsPlugin.cancelAll();
      return;
    }
    for (int id = 0; id < _prayerAlarmCount; id++) {
      await ringtoneChannel.invokeMethod('cancelAzanAlarm', {'id': id});
    }
  }


  void _showSettingsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setPageState) => ValueListenableBuilder<String>(
            valueListenable: langNotifier,
            builder: (context, _, _) => _buildSettingsPage(context, setPageState),
          ),
        ),
      ),
    );
  }

  Widget _settingsSection(BuildContext context, String? title, List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(title, style: TextStyle(fontSize: 17, color: cs.onSurfaceVariant)),
          )
        else
          const SizedBox(height: 16),
        Material(
          color: cs.surface,
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ),
      ],
    );
  }

  Widget _alarmRow(BuildContext context, int i, StateSetter setPageState) {
    final cs = Theme.of(context).colorScheme;
    final alarm = prayerAlarms[i];
    final textColor = alarm.enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.45);
    final linkStyle = TextStyle(
      fontSize: 15,
      color: textColor,
      decoration: TextDecoration.underline,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Switch(
            value: alarm.enabled,
            onChanged: (value) async {
              await _setAlarmEnabled(i, value);
              setPageState(() {});
            },
          ),
          const SizedBox(width: 8),
          // Dar ekranda ya da büyük yazı boyutunda bağlantılar alt satıra iner; böylece
          // vakit adı kesilmez. Yer varsa eskisi gibi aynı satırda, sağda durur.
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 2,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _alarmLabel(i),
                      style: TextStyle(fontSize: 16, color: textColor),
                    ),
                    Text(
                      // iOS'ta uygulamalar sistem zil sesini kullanamaz; varsayılan bildirim sesi çalar.
                      _isIos
                          ? t("Varsayılan ses", "Default sound")
                          : (alarm.soundTitle ?? t("Varsayılan", "Default")),
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () async {
                        await _pickAlarmMinutes(i);
                        setPageState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(_minutesLabel(alarm.minutes), style: linkStyle),
                      ),
                    ),
                    if (!_isIos)
                      InkWell(
                        onTap: () async {
                          await _pickAlarmSound(i);
                          setPageState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(t("Sesi Değiştir", "Change Sound"), style: linkStyle),
                        ),
                      ),
                  ],
                ),
                // Alarm süresi yalnızca Android'de ve tam ekran alarm modunda anlamlıdır.
                if (!_isIos && alarmMode == 'fullscreen')
                  InkWell(
                    onTap: () async {
                      await _pickAlarmDuration(i);
                      setPageState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(_durationLabel(alarm), style: linkStyle),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPage(BuildContext context, StateSetter setPageState) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Color.alphaBlend(cs.surfaceContainerHighest.withValues(alpha: 0.5), cs.surface),
      appBar: AppBar(
        title: Text(t("Ayarlar", "Settings")),
        backgroundColor: cs.surface,
        scrolledUnderElevation: 1,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _settingsSection(
              context,
              t("Vakitlerden Önce Uyarılar", "Alerts Before Prayer Times"),
              [
                if (!_isIos) ...[
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 'notification',
                        icon: const Icon(Icons.notifications_outlined),
                        label: Text(t("Bildirim", "Notification")),
                      ),
                      ButtonSegment(
                        value: 'fullscreen',
                        icon: const Icon(Icons.alarm),
                        label: Text(t("Tam Ekran Alarm", "Full-screen Alarm")),
                      ),
                    ],
                    selected: {alarmMode},
                    onSelectionChanged: (selected) async {
                      await _setAlarmMode(selected.first);
                      setPageState(() {});
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Text(
                      alarmMode == 'fullscreen'
                          ? t("Vakitte telefon alarm gibi çalar, kilit ekranında tam ekran açılır (süreyi her vakit için seçebilirsin).",
                              "The phone rings like an alarm and opens full-screen over the lock screen (you can choose the length for each prayer).")
                          : t("Vakitte seçtiğin zil sesiyle normal bir bildirim gelir.",
                              "A normal notification arrives with the ringtone you chose."),
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const Divider(height: 1),
                ],
                for (var i = 0; i < _prayerAlarmCount; i++) ...[
                  _alarmRow(context, i, setPageState),
                  if (i < _prayerAlarmCount - 1) const Divider(height: 1),
                ],
              ],
            ),
            _settingsSection(
              context,
              t("Dil", "Language"),
              [
                const SizedBox(height: 4),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'tr', label: Text("Türkçe")),
                    ButtonSegment(value: 'en', label: Text("English")),
                  ],
                  selected: {langNotifier.value},
                  onSelectionChanged: (selected) => setLanguage(selected.first),
                ),
                const SizedBox(height: 8),
              ],
            ),
            _settingsSection(
              context,
              t("Yazı Boyutu", "Text Size"),
              [
                ValueListenableBuilder<double?>(
                  valueListenable: textZoomNotifier,
                  builder: (context, zoom, _) => Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(t("Otomatik (ekran boyutuna göre)", "Automatic (by screen size)")),
                        value: zoom == null,
                        onChanged: (auto) => setTextZoom(auto ? null : 1.0),
                      ),
                      if (zoom != null)
                        Row(
                          children: [
                            const Text("A", style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Slider(
                                value: zoom,
                                min: minTextZoom,
                                max: maxTextZoom,
                                divisions: 6,
                                label: "${(zoom * 100).round()}%",
                                onChanged: (v) => textZoomNotifier.value = v,
                                onChangeEnd: setTextZoom,
                              ),
                            ),
                            const Text("A", style: TextStyle(fontSize: 22)),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            _settingsSection(
              context,
              t("Görünüm", "Appearance"),
              [
                const SizedBox(height: 4),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier,
                  builder: (context, mode, _) {
                    return SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: ThemeMode.light, label: Text(t("Açık", "Light"))),
                        ButtonSegment(value: ThemeMode.dark, label: Text(t("Koyu", "Dark"))),
                        ButtonSegment(value: ThemeMode.system, label: Text(t("Sistem", "System"))),
                      ],
                      selected: {mode},
                      onSelectionChanged: (selected) => setThemeMode(selected.first),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
            _settingsSection(
              context,
              t("Tema", "Theme"),
              [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(t(appThemeById(themeNotifier.value).tr, appThemeById(themeNotifier.value).en)),
                  subtitle: Text(t("Tema seçmek için dokun", "Tap to choose a theme")),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showThemePicker,
                ),
              ],
            ),
            _settingsSection(
              context,
              t("Klasik Tema Rengi", "Classic Theme Color"),
              [
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: colorThemeNotifier,
                  builder: (context, selected, _) => Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: [
                      for (final p in appPalettes)
                        Tooltip(
                          message: t(p.tr, p.en),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setColorTheme(p.id),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.hue == null ? null : p.swatch,
                                gradient: p.hue == null
                                    ? const SweepGradient(colors: [
                                        Color(0xFFB57EDC), Color(0xFF6DAF89), Color(0xFF6C9BD1),
                                        Color(0xFFE59A5B), Color(0xFFD97B9F), Color(0xFFB57EDC),
                                      ])
                                    : null,
                                border: Border.all(
                                  color: selected == p.id ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: selected == p.id
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : (p.hue == null
                                      ? const Icon(Icons.auto_awesome, color: Colors.white, size: 20)
                                      : null),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t("\"Otomatik\" seçiliyken renk her gün değişir.", "With \"Automatic\" the color changes every day."),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
              ],
            ),
            _settingsSection(
              context,
              t("Figür", "Figure"),
              [
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: figureNotifier,
                  builder: (context, selected, _) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in appFigures)
                        ChoiceChip(
                          avatar: f.id == 'none'
                              ? const Icon(Icons.block, size: 18)
                              : SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CustomPaint(
                                    painter: FigurePainter(f.id, color: Theme.of(context).colorScheme.onSurface),
                                  ),
                                ),
                          label: Text(t(f.tr, f.en)),
                          selected: selected == f.id,
                          onSelected: (_) => setFigure(f.id),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
            _settingsSection(
              context,
              null,
              [
                _buildOfflineTile(),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle_outline),
                  title: Text(t("Uygulama Tanıtımını Göster", "Show App Tour")),
                  onTap: () {
                    Navigator.pop(context);
                    showCoachMarks.value = true;
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateTimeLeft() {
    if (prayerTimes == null || activeCoordinates == null) return;
    
    final now = DateTime.now();
    nextPrayer = prayerTimes!.nextPrayer();
    DateTime? nextPrayerTime = prayerTimes!.timeForPrayer(nextPrayer!);

    if (nextPrayer == Prayer.none || nextPrayerTime == null) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final params = _prayerCalcParams();
      final tomorrowTimes = PrayerTimes(activeCoordinates!, DateComponents(tomorrow.year, tomorrow.month, tomorrow.day), params);
      
      nextPrayer = Prayer.fajr;
      nextPrayerTime = tomorrowTimes.fajr;
    }

    final diff = nextPrayerTime.difference(now);
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(diff.inHours);
    final minutes = twoDigits(diff.inMinutes.remainder(60));
    final seconds = twoDigits(diff.inSeconds.remainder(60));

    setState(() {
      timeLeft = "$hours:$minutes:$seconds";
      nextPrayerName = _getPrayerName(nextPrayer!);
    });

    final widgetKey = "$nextPrayerName-${nextPrayerTime.millisecondsSinceEpoch}-$currentCity-$isEnglish";
    if (widgetKey != _lastWidgetKey) {
      _lastWidgetKey = widgetKey;
      _updateHomeWidget(nextPrayerName, nextPrayerTime);
    }
  }

  Future<void> _updateHomeWidget(String prayerName, DateTime prayerTime) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final timeStr =
          "${prayerTime.hour.toString().padLeft(2, '0')}:${prayerTime.minute.toString().padLeft(2, '0')}";
      await HomeWidget.saveWidgetData<String>('widget_city', currentCity);
      await HomeWidget.saveWidgetData<String>('widget_prayer_name', prayerName);
      await HomeWidget.saveWidgetData<String>('widget_language', isEnglish ? 'en' : 'tr');
      final cityUpper = currentCity.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
      await HomeWidget.saveWidgetData<String>(
        'widget_label',
        t("SONRAKİ VAKİT • $cityUpper", "NEXT PRAYER • $cityUpper"),
      );
      await HomeWidget.saveWidgetData<String>('widget_prayer_time', timeStr);
      await HomeWidget.saveWidgetData<String>(
        'widget_prayer_timestamp',
        prayerTime.millisecondsSinceEpoch.toString(),
      );
      final now = DateTime.now();
      final timeline = <Map<String, Object>>[];
      final coordinates = activeCoordinates;
      if (coordinates != null) {
        final params = _prayerCalcParams();
        // Keep upcoming prayers available while the app is closed.
        for (var day = 0; day < 7; day++) {
          final date = DateTime(now.year, now.month, now.day + day);
          final times = PrayerTimes(
            coordinates,
            DateComponents(date.year, date.month, date.day),
            params,
          );
          for (final prayer in [Prayer.fajr, Prayer.sunrise, Prayer.dhuhr,
            Prayer.asr, Prayer.maghrib, Prayer.isha]) {
            final time = times.timeForPrayer(prayer);
            if (time == null || !time.isAfter(now)) continue;
            timeline.add({
              'name': _getPrayerName(prayer),
              'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              'timestamp': time.millisecondsSinceEpoch,
            });
          }
        }
      }
      await HomeWidget.saveWidgetData<String>('widget_prayer_timeline', jsonEncode(timeline));
      await HomeWidget.updateWidget(androidName: 'PrayerWidgetProvider');
    } catch (e) {
      debugPrint("Widget güncellenemedi: $e");
    }
  }

  String _getPrayerName(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr: return t("İmsak", "Fajr");
      case Prayer.sunrise: return t("Güneş", "Sunrise");
      case Prayer.dhuhr: return t("Öğle", "Dhuhr");
      case Prayer.asr: return t("İkindi", "Asr");
      case Prayer.maghrib: return t("Akşam", "Maghrib");
      case Prayer.isha: return t("Yatsı", "Isha");
      case Prayer.none: return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemeById(themeNotifier.value);

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThemeBackground(
        theme: theme,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 900) {
                      return SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  KeyedSubtree(key: prayerListKey, child: _buildPrayerList()),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                    child: KeyedSubtree(key: dailyHadithKey, child: _buildDailyHadith()),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 20, bottom: 20),
                                child: KeyedSubtree(key: dailyAyahKey, child: _buildDailyAyah()),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          KeyedSubtree(key: prayerListKey, child: _buildPrayerList()),
                          KeyedSubtree(key: dailyTabsKey, child: _buildDailyTabs()),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _buildBottomMenu(),
              if (_isBannerAdLoaded && _bannerAd != null)
                SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFigure() {
    return CustomPaint(size: const Size(150, 150), painter: FigurePainter(figureNotifier.value));
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Positioned(
          right: -20,
          bottom: 0,
          child: Opacity(
            opacity: 0.2,
            child: _buildFigure(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: DropdownButton<String>(
                      value: currentCity,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      dropdownColor: const Color(0xFF6DAF89),
                      underline: const SizedBox(), // Remove default underline
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: _cities.map((String city) {
                        return DropdownMenuItem<String>(
                          value: city,
                          child: Text(city),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != currentCity) {
                          setState(() {
                            currentCity = newValue;
                            prayerTimes = null; // show loading
                          });
                          _saveCity(newValue);
                          _calculatePrayerTimesForCity(newValue);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: CountdownView(theme: appThemeById(themeNotifier.value), s: _homeSnapshot()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomMenu() {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: isLocating
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2))
                  : const Icon(Icons.my_location_outlined, size: 30, color: Colors.black87),
              tooltip: t("Mevcut Konumu Bul", "Find My Location"),
              onPressed: isLocating ? null : _findLocationInBackground,
            ),
            IconButton(
              key: qiblaButtonKey,
              icon: const Icon(Icons.explore_outlined, size: 30, color: Colors.black87),
              tooltip: t("Kıble Yönü", "Qibla Direction"),
              onPressed: () {
                if (kIsWeb) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t('Kıble pusulası web tarayıcılarında desteklenmez. Lütfen mobilde deneyin.', 'The qibla compass is not supported in web browsers. Please try it on mobile.'))),
                  );
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (context) => const QiblaScreen()));
              },
            ),
            IconButton(
              key: zikirButtonKey,
              icon: const Icon(Icons.timer_outlined, size: 30, color: Colors.black87),
              tooltip: t("Zikirmatik / Sayaç", "Dhikr Counter"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ZikirmatikScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.palette_outlined, size: 30, color: Colors.black87),
              tooltip: t("Tema", "Theme"),
              onPressed: _showThemePicker,
            ),
            IconButton(
              key: settingsButtonKey,
              icon: const Icon(Icons.settings_outlined, size: 30, color: Colors.black87),
              tooltip: t("Ayarlar", "Settings"),
              onPressed: _showSettingsDialog,
            ),
          ],
        ),
      ),
    );
  }

  String _ayahRef(Map<String, dynamic> data) =>
      t("${data['surah']}, ${data['numberInSurah']}. Ayet", "${data['surah']}, Verse ${data['numberInSurah']}");

  Widget _buildDailyAyah() {
    if (isLoadingAyah) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (dailyAyahData == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t("Ayet bulunamadı. İnternete bağlanıp çevrimdışı metni indirebilirsin.",
                  "Verse not found. Connect to the internet to download the offline text."),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            _buildOfflineDownloadIcon(onDark: true),
          ],
        ),
      );
    }

    final isLastAyah = displayedAyahNumber == 6236;
    
    return GestureDetector(
      onDoubleTap: () => _showAyahDialog(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isLastAyah ? Colors.red[100]?.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(t("Ayet-i Kerime", "Quran Verse"), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    _buildOfflineDownloadIcon(),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _prevAyah,
                    ),
                    const SizedBox(width: 5),
                    Text(_ayahRef(dailyAyahData!), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 5),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _nextAyah,
                    ),
                  ]
                )
              ],
            ),
            const SizedBox(height: 15),
            Text(
              dailyAyahData!['arabic'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            if (!isEnglish) ...[
              const SizedBox(height: 8),
              Text(
                dailyAyahData!['transliteration'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.green[800], fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
              ),
              const Divider(height: 16),
              const Text("Diyanet İşleri Meali:", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 4),
              Text(
                dailyAyahData!['turkish1'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
              const SizedBox(height: 8),
              const Text("Elmalılı Hamdi Yazır Meali:", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 4),
              Text(
                dailyAyahData!['turkish2'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
            ] else
              const Divider(height: 16),
            const SizedBox(height: 8),
            Text(t("English Translation (Sahih Int.):", "Translation (Sahih International):"), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 4),
            Text(
              dailyAyahData!['english'] ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
            const SizedBox(height: 15),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_double_arrow_left, size: 22, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _prevSurah,
                ),
                const SizedBox(width: 15),
                Text(t("Sure Değiştir", "Change Surah"), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(width: 15),
                IconButton(
                  icon: const Icon(Icons.keyboard_double_arrow_right, size: 22, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _nextSurah,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTabs() {
    Widget tab(String label, int index) {
      final selected = _dailyTab == index;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _dailyTab = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: selected ? 0.95 : 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.green[800] : Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              tab(t("Ayet-i Kerime", "Quran Verse"), 0),
              const SizedBox(width: 8),
              tab(t("Vaktin Hadisi", "Hadith of the Hour"), 1),
            ],
          ),
        ),
        _dailyTab == 0 ? _buildDailyAyah() : _buildDailyHadith(),
      ],
    );
  }

  static const int _hadithMaxLines = 6;

  void _showHadithDialog(Hadith h) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(h.shownTopic, style: const TextStyle(fontSize: 16, color: Colors.green)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h.shownText, style: const TextStyle(fontSize: 15, height: 1.45)),
              const SizedBox(height: 12),
              Text(t("Kaynak: ${h.source}", "Source: ${h.shownSource}"), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                _hadithCredit,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.green),
            tooltip: t("Paylaş", "Share"),
            onPressed: () => _shareHadith(h),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t("Kapat", "Close"))),
        ],
      ),
    );
  }

  String get _hadithCredit => t(
        "Türkçe metin kaynaklardan serbest çeviridir. Ayrıntı için kaynak eserlere bakınız.",
        "Free translation from the cited sources. Please consult the original works for details.",
      );

  void _shareHadith(Hadith h) {
    final text = t(
      "${h.text}\n\n"
          "Kaynak: ${h.source}\n\n"
          "Kıble ve Namaz Rehberim uygulamasından paylaşıldı.",
      "${h.shownText}\n\n"
          "Source: ${h.shownSource}\n\n"
          "Shared from the Qibla & Prayer Guide app.",
    );
    SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: _shareOrigin()));
  }

  /// Şu an içinde bulunulan vaktin sırası: 0 imsak … 5 yatsı. Vakitler henüz yoksa null.
  /// Gece yarısından imsaka kadar yatsı vaktinin devamı sayılır.
  int? _currentPrayerIndex() {
    final times = prayerTimes;
    if (times == null) return null;
    final now = DateTime.now();
    for (var i = _prayerAlarmCount - 1; i >= 0; i--) {
      if (!now.isBefore(_prayerTimeAt(times, i))) return i;
    }
    return _prayerAlarmCount - 1;
  }

  Widget _buildDailyHadith() {
    final prayerIndex = _currentPrayerIndex();
    if (prayerIndex == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day).difference(DateTime(2024)).inDays;
    final h = hadithForPrayer(day, prayerIndex);
    final prayerName = _getPrayerName(_prayerFromIndex(prayerIndex));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t("$prayerName Vaktinin Hadisi", "Hadith for $prayerName"), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              IconButton(
                icon: const Icon(Icons.share, size: 18, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: t("Paylaş", "Share"),
                onPressed: () => _shareHadith(h),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const textStyle = TextStyle(fontSize: 15, height: 1.4, color: Colors.black87);
              final painter = TextPainter(
                text: TextSpan(text: h.shownText, style: textStyle),
                maxLines: _hadithMaxLines,
                textDirection: ui.TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: constraints.maxWidth);
              final truncated = painter.didExceedMaxLines;
              return Column(
                children: [
                  Text(
                    h.shownText,
                    textAlign: TextAlign.center,
                    maxLines: _hadithMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                  if (truncated)
                    TextButton(
                      onPressed: () => _showHadithDialog(h),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(t("Tamamını oku", "Read more"), style: const TextStyle(fontSize: 13)),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            h.shownTopic,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.green[800], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            t("Kaynak: ${h.source}", "Source: ${h.shownSource}"),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  HomeSnapshot _homeSnapshot() {
    final now = DateTime.now();
    final entries = <PrayerEntry>[];
    if (prayerTimes != null) {
      final format = DateFormat("HH:mm");
      Prayer currentP = prayerTimes!.currentPrayer();
      if (currentP == Prayer.none && now.isAfter(prayerTimes!.isha)) {
        currentP = Prayer.isha;
      } else if (currentP == Prayer.none && now.isBefore(prayerTimes!.fajr)) {
        currentP = Prayer.isha;
      }
      for (var i = 0; i < _prayerAlarmCount; i++) {
        final prayer = _prayerFromIndex(i);
        entries.add(PrayerEntry(_getPrayerName(prayer), format.format(_prayerTimeAt(prayerTimes!, i)), currentP == prayer));
      }
    }
    return HomeSnapshot(
      city: currentCity,
      nextPrayerName: nextPrayerName,
      timeLeft: timeLeft,
      now: now,
      prayers: entries,
    );
  }

  void _showThemePicker() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ThemePickerScreen(snapshot: _homeSnapshot())),
    );
  }

  Widget _buildPrayerList() {
    if (prayerTimes == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 50.0),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return PrayerTimesView(theme: appThemeById(themeNotifier.value), s: _homeSnapshot());
  }

  void _shareAyah(Map<String, dynamic> data) {
    final text = t(
      "${_ayahRef(data)}\n\n"
          "${data['arabic']}\n\n"
          "${data['turkish1'] ?? ''}\n\n"
          "Kıble ve Namaz Rehberim uygulamasından paylaşıldı.",
      "${_ayahRef(data)}\n\n"
          "${data['arabic']}\n\n"
          "${data['english'] ?? ''}\n\n"
          "Shared from the Qibla & Prayer Guide app.",
    );
    SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: _shareOrigin()));
  }

  void _showAyahDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PopScope(
          // Sayfa kapanınca ses de durur.
          onPopInvokedWithResult: (didPop, _) {
            isAutoPlaying = false;
            _stopAllAudio();
          },
          child: ValueListenableBuilder<String>(
            valueListenable: langNotifier,
            builder: (context, _, _) => ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: dailyAyahNotifier,
              builder: (context, data, _) => _buildAyahScreen(context, data),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAyahScreen(BuildContext context, Map<String, dynamic>? data) {
    if (data == null) return const Scaffold(body: SizedBox());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyTextColor = isDark ? Colors.grey[300] : Colors.grey[800];
    final translitColor = isDark ? Colors.green[300] : Colors.green[800];

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
        );
    Widget body(String? text) => Text(text ?? '',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: bodyTextColor, height: 1.5));
    Widget navButton(IconData icon, double size, VoidCallback onPressed) => IconButton(
          icon: Icon(icon, size: size, color: Colors.grey),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(t("Ayet-i Kerime", "Quran Verse")),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.green),
            tooltip: t("Paylaş", "Share"),
            onPressed: () => _shareAyah(data),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAudioBar(context),
          // Reklam, ses düğmelerinin altında ve onlardan boşlukla ayrılmış durur.
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const SafeArea(top: false, child: Center(child: AdBanner())),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              _ayahRef(data),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                navButton(Icons.keyboard_double_arrow_left, 26, _prevSurah),
                const SizedBox(width: 25),
                navButton(Icons.arrow_back_ios, 22, _prevAyah),
                const SizedBox(width: 40),
                navButton(Icons.arrow_forward_ios, 22, _nextAyah),
                const SizedBox(width: 25),
                navButton(Icons.keyboard_double_arrow_right, 26, _nextSurah),
              ],
            ),
            const Divider(height: 30),
            Text(
              data['arabic'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontFamily: 'Amiri', fontWeight: FontWeight.bold, height: 2.0),
            ),
            if (!isEnglish) ...[
              const SizedBox(height: 20),
              Text(
                data['transliteration'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: translitColor, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
              ),
              const Divider(height: 30),
              heading("Diyanet İşleri Meali"),
              body(data['turkish1']),
              const SizedBox(height: 15),
              heading("Elmalılı Hamdi Yazır Meali"),
              body(data['turkish2']),
            ] else
              const Divider(height: 30),
            const SizedBox(height: 15),
            heading(t("English Translation (Sahih Int.)", "Translation (Sahih International)")),
            body(data['english']),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Alttaki ses çubuğu: oynat/durdur, ne dinleneceği (Kur'an / meal / ikisi) ve hangi meal.
  Widget _buildAudioBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mealLabels = {
      'diyanet': t("Diyanet", "Diyanet"),
      'yazir': t("Elmalılı", "Elmalılı"),
      'english': t("İngilizce (Sahih Int.)", "English (Sahih Int.)"),
    };
    return Material(
      color: cs.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: audioPlayingNotifier,
                    builder: (context, playing, _) => IconButton(
                      iconSize: 46,
                      icon: Icon(playing ? Icons.stop_circle : Icons.play_circle,
                          color: playing ? Colors.red : Colors.green),
                      tooltip: playing ? t("Durdur", "Stop") : t("Dinle", "Listen"),
                      onPressed: _toggleAudio,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: audioModeNotifier,
                      builder: (context, mode, _) => SegmentedButton<String>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                        segments: [
                          ButtonSegment(value: 'quran', label: Text(t("Kur'an", "Quran"))),
                          ButtonSegment(value: 'meal', label: Text(t("Meal", "Translation"))),
                          ButtonSegment(value: 'both', label: Text(t("İkisi", "Both"))),
                        ],
                        selected: {mode},
                        onSelectionChanged: (s) => _setAudioMode(s.first),
                      ),
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<String>(
                valueListenable: audioModeNotifier,
                builder: (context, mode, _) => mode == 'quran'
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ValueListenableBuilder<String>(
                          valueListenable: audioMealNotifier,
                          builder: (context, meal, _) => Column(
                            children: [
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final e in mealLabels.entries)
                                    ChoiceChip(
                                      label: Text(e.value),
                                      selected: meal == e.key,
                                      onSelected: (_) => _setAudioMeal(e.key),
                                    ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  t("Meal, telefonunun sesli okuma özelliğiyle okunur.",
                                      "The translation is read with your phone's text-to-speech."),
                                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              ValueListenableBuilder<String?>(
                valueListenable: audioNotice,
                builder: (context, msg, _) => msg == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          msg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ZikirmatikScreen extends StatefulWidget {
  const ZikirmatikScreen({super.key});

  @override
  State<ZikirmatikScreen> createState() => _ZikirmatikScreenState();
}

class _ZikirmatikScreenState extends State<ZikirmatikScreen> {
  int _count = 0;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefsAndLoad();
  }

  Future<void> _initPrefsAndLoad() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _count = _prefs?.getInt('zikir_count') ?? 0;
      });
    }
  }

  void _incrementCount() {
    setState(() {
      _count++;
    });
    _prefs?.setInt('zikir_count', _count);
  }

  void _resetCount() {
    setState(() {
      _count = 0;
    });
    _prefs?.setInt('zikir_count', 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(
          t("Zikirmatik", "Dhikr Counter"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: _resetCount,
            icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
            label: Text(
              t("Sıfırla", "Reset"),
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
          children: [
            // Reklam üstte durur: sürekli basılan büyük "BAS" düğmesinden en uzak nokta burasıdır.
            const AdBanner(bottomGap: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    t("SAYAC", "COUNT"),
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 14,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$_count",
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonSize = (constraints.maxHeight * 0.75).clamp(180.0, 320.0);
                    final innerSize = buttonSize * 0.78;
                    final iconSize = buttonSize * 0.28;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _incrementCount,
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withValues(alpha: 0.35),
                        highlightColor: const Color(0xFF34D399).withValues(alpha: 0.25),
                        child: Ink(
                          width: buttonSize,
                          height: buttonSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                blurRadius: 30,
                                spreadRadius: 8,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: innerSize,
                              height: innerSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.25),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.touch_app, color: Colors.white, size: iconSize),
                                  const SizedBox(height: 8),
                                  Text(
                                    t("BAS", "TAP"),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
