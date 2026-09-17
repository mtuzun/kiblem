import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' show pi, cos, sin;
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
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:share_plus/share_plus.dart';
import 'package:home_widget/home_widget.dart';

import 'city_data.dart';
import 'onboarding_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const MethodChannel ringtoneChannel = MethodChannel('com.metint.kiblem/ringtone');

final GlobalKey qiblaButtonKey = GlobalKey();
final GlobalKey prayerListKey = GlobalKey();
final GlobalKey dailyAyahKey = GlobalKey();
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
  MobileAds.instance.initialize();

  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  themeModeNotifier.value = ThemeMode.values.firstWhere(
    (m) => m.name == prefs.getString('theme_mode'),
    orElse: () => ThemeMode.system,
  );

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
  bool isPlaying = false;
  bool isAutoPlaying = false;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  bool azanReminderEnabled = false;
  int azanReminderMinutes = 15;
  String? azanSoundTitle;
  String? _lastWidgetKey;

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
    _cities.sort();
    _loadSavedCity();
    _initAyah();
    
    audioPlayer = AudioPlayer();
    audioPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
      }
    });
    audioPlayer!.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
        if (isAutoPlaying) {
          _nextAyah();
        }
      }
    });
    
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
    timer?.cancel();
    audioPlayer?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-8893360722009141/9012768354',
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
    if (kIsWeb) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(days: 1),
              content: const Text("Yeni bir sürüm indirildi."),
              action: SnackBarAction(
                label: "GÜNCELLE",
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
      audioPlayer?.stop();
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

  void _playOnlyAudio() async {
    if (audioPlayer == null || dailyAyahData == null) return;
    final audioUrl = dailyAyahData!['audioUrl'];
    if (audioUrl != null) {
      await audioPlayer!.play(UrlSource(audioUrl));
    }
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
    final audioUrl = dailyAyahData!['audioUrl'];
    if (audioUrl == null) return;
    
    if (isPlaying) {
      isAutoPlaying = false;
      await audioPlayer!.stop();
    } else {
      isAutoPlaying = true;
      try {
        await audioPlayer!.play(UrlSource(audioUrl));
      } catch (e) {
        debugPrint("AUDIO PLAY ERROR: $e");
      }
    }
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
        _showSnackBar("Konum servisleri kapalı.");
        setState(() => isLocating = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Konum izni reddedildi.");
          setState(() => isLocating = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Konum izni kalıcı olarak reddedildi.");
        setState(() => isLocating = false);
        return;
      } 

      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String foundCity = place.administrativeArea ?? place.locality ?? "İstanbul";
        
        // Clean up "Province" word from English locale responses e.g. "Istanbul Province"
        if (foundCity.toLowerCase().contains("province")) {
          foundCity = foundCity.split(" ")[0];
        }

        // Match with our city list
        String matchedCity = _cities.firstWhere(
          (c) => c.toLowerCase() == foundCity.toLowerCase(),
          orElse: () => "İstanbul"
        );

        setState(() {
          currentCity = matchedCity;
          activeCoordinates = Coordinates(position.latitude, position.longitude);
        });

        await _saveCity(matchedCity);
        _calculatePrayerTimes(activeCoordinates!);
        _showSnackBar("$matchedCity konumu bulundu.");
      }
    } catch (e) {
      _showSnackBar("Konum alınırken hata oluştu.");
    } finally {
      setState(() {
        isLocating = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _calculatePrayerTimes(Coordinates coordinates) {
    final params = CalculationMethod.turkey.getParameters();
    params.madhab = Madhab.hanafi;
    
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
    final enabled = prefs.getBool('azan_reminder_enabled') ?? false;
    setState(() {
      azanReminderEnabled = enabled;
      azanReminderMinutes = prefs.getInt('azan_reminder_minutes') ?? 15;
      azanSoundTitle = prefs.getString('azan_sound_title');
    });
    if (enabled && prayerTimes != null) {
      _scheduleAzanReminders();
    }
  }

  Future<void> _pickAzanSound() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUri = prefs.getString('azan_sound_uri');

      final pickedUri = await ringtoneChannel.invokeMethod<String>(
        'pickRingtone',
        {'currentUri': currentUri},
      );
      if (pickedUri == null) return;

      final title = await ringtoneChannel.invokeMethod<String>(
            'getRingtoneTitle',
            {'uri': pickedUri},
          ) ??
          'Özel Ses';

      await ringtoneChannel.invokeMethod('setChannelSound', {'uri': pickedUri});
      await prefs.setString('azan_sound_uri', pickedUri);
      await prefs.setString('azan_sound_title', title);

      if (!mounted) return;
      setState(() {
        azanSoundTitle = title;
      });
    } catch (e) {
      debugPrint("Ezan sesi seçilemedi: $e");
    }
  }

  Future<void> _setAzanReminderEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('azan_reminder_enabled', value);
    setState(() {
      azanReminderEnabled = value;
    });

    if (value) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      _scheduleAzanReminders();
    } else {
      await _cancelAzanReminders();
    }
  }

  Future<void> _scheduleAzanReminders() async {
    if (prayerTimes == null) return;
    await _cancelAzanReminders();

    final prayers = <int, DateTime>{
      0: prayerTimes!.fajr,
      1: prayerTimes!.dhuhr,
      2: prayerTimes!.asr,
      3: prayerTimes!.maghrib,
      4: prayerTimes!.isha,
    };

    for (final entry in prayers.entries) {
      final reminderTime = entry.value.subtract(Duration(minutes: azanReminderMinutes));
      if (reminderTime.isBefore(DateTime.now())) continue;

      final prayerName = _getPrayerName(_prayerFromIndex(entry.key));
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: entry.key,
        title: 'Namaz Vakti Yaklaşıyor',
        body: '$prayerName vaktine $azanReminderMinutes dakika kaldı.',
        scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'azan_reminder',
            'Ezan Hatırlatıcı',
            channelDescription: 'Namaz vaktine seçtiğin süre kala bildirim gönderir.',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _setAzanReminderMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('azan_reminder_minutes', minutes);
    setState(() {
      azanReminderMinutes = minutes;
    });
    if (azanReminderEnabled) {
      _scheduleAzanReminders();
    }
  }

  Prayer _prayerFromIndex(int index) {
    switch (index) {
      case 0: return Prayer.fajr;
      case 1: return Prayer.dhuhr;
      case 2: return Prayer.asr;
      case 3: return Prayer.maghrib;
      default: return Prayer.isha;
    }
  }

  Future<void> _cancelAzanReminders() async {
    for (int id = 0; id < 5; id++) {
      await flutterLocalNotificationsPlugin.cancel(id: id);
    }
  }


  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Ayarlar"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Ezan Hatırlatıcısı"),
                    subtitle: Text("Namaz vaktine $azanReminderMinutes dakika kala bildirim gönder."),
                    value: azanReminderEnabled,
                    onChanged: (value) async {
                      await _setAzanReminderEnabled(value);
                      setDialogState(() {});
                    },
                  ),
                  if (azanReminderEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Ezana $azanReminderMinutes dakika kala uyarı verilecektir.",
                              style: TextStyle(color: Colors.green[700], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          const Text("Süre:", style: TextStyle(fontSize: 13)),
                          Expanded(
                            child: Slider(
                              value: azanReminderMinutes.toDouble(),
                              min: 1,
                              max: 15,
                              divisions: 14,
                              label: "$azanReminderMinutes dk",
                              onChanged: (value) {
                                setDialogState(() {
                                  azanReminderMinutes = value.round();
                                });
                              },
                              onChangeEnd: (value) => _setAzanReminderMinutes(value.round()),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text("$azanReminderMinutes dk", style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.music_note_outlined),
                      title: const Text("Ezan Sesini Seç"),
                      subtitle: Text(
                        azanSoundTitle != null
                            ? "Seçili ses: $azanSoundTitle"
                            : "Sadece bu hatırlatıcı için bir ses seç (telefonunun zil/bildirim sesini değiştirmez).",
                      ),
                      onTap: () async {
                        await _pickAzanSound();
                        setDialogState(() {});
                      },
                    ),
                  ],
                  const Divider(height: 24),
                  const Text("Görünüm", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeModeNotifier,
                    builder: (context, mode, _) {
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text("Açık")),
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text("Koyu")),
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest), label: Text("Sistem")),
                        ],
                        selected: {mode},
                        onSelectionChanged: (selected) => setThemeMode(selected.first),
                      );
                    },
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text("Uygulama Tanıtımını Göster"),
                    onTap: () {
                      Navigator.pop(context);
                      showCoachMarks.value = true;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Kapat"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateTimeLeft() {
    if (prayerTimes == null || activeCoordinates == null) return;
    
    final now = DateTime.now();
    nextPrayer = prayerTimes!.nextPrayer();
    DateTime? nextPrayerTime = prayerTimes!.timeForPrayer(nextPrayer!);

    if (nextPrayer == Prayer.none || nextPrayerTime == null) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final params = CalculationMethod.turkey.getParameters();
      params.madhab = Madhab.hanafi;
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

    final widgetKey = "$nextPrayerName-${nextPrayerTime.hour}:${nextPrayerTime.minute}";
    if (widgetKey != _lastWidgetKey) {
      _lastWidgetKey = widgetKey;
      _updateHomeWidget(nextPrayerName, nextPrayerTime);
    }
  }

  Future<void> _updateHomeWidget(String prayerName, DateTime prayerTime) async {
    if (kIsWeb) return;
    try {
      final timeStr =
          "${prayerTime.hour.toString().padLeft(2, '0')}:${prayerTime.minute.toString().padLeft(2, '0')}";
      await HomeWidget.saveWidgetData<String>('widget_city', currentCity);
      await HomeWidget.saveWidgetData<String>('widget_prayer_name', prayerName);
      await HomeWidget.saveWidgetData<String>('widget_prayer_time', timeStr);
      await HomeWidget.updateWidget(androidName: 'PrayerWidgetProvider');
    } catch (e) {
      debugPrint("Widget güncellenemedi: $e");
    }
  }

  String _getPrayerName(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr: return "İmsak";
      case Prayer.sunrise: return "Güneş";
      case Prayer.dhuhr: return "Öğle";
      case Prayer.asr: return "İkindi";
      case Prayer.maghrib: return "Akşam";
      case Prayer.isha: return "Yatsı";
      case Prayer.none: return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    // Base hue based on day of year (0-360)
    final baseHue = (dayOfYear * (360 / 365)) % 360;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = HSLColor.fromAHSL(1.0, baseHue, 0.4, isDark ? 0.28 : 0.6).toColor();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomPaint(
        painter: MotifPainter(dayOfYear),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      KeyedSubtree(key: prayerListKey, child: _buildPrayerList()),
                      KeyedSubtree(key: dailyAyahKey, child: _buildDailyAyah()),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
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

  Widget _buildHeader() {
    return Stack(
      children: [
        Positioned(
          right: -20,
          bottom: 0,
          child: Opacity(
            opacity: 0.2,
            child: Icon(Icons.mosque, size: 150, color: Colors.white),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                      const SizedBox(width: 10),
                      IconButton(
                        icon: isLocating 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.my_location, color: Colors.white),
                        onPressed: isLocating ? null : _findLocationInBackground,
                        tooltip: "Mevcut Konumu Bul",
                      ),
                      IconButton(
                        key: qiblaButtonKey,
                        icon: const Icon(Icons.explore, color: Colors.white),
                        tooltip: "Kıble Yönü",
                        onPressed: () {
                          if (kIsWeb) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kıble pusulası web tarayıcılarında desteklenmez. Lütfen mobilde deneyin.')),
                            );
                            return;
                          }
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const QiblaScreen()));
                        },
                      ),
                      IconButton(
                        key: zikirButtonKey,
                        icon: const Icon(Icons.timer, color: Colors.white),
                        tooltip: "Zikirmatik / Sayaç",
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => const ZikirmatikDialog(),
                          );
                        },
                      ),
                      IconButton(
                        key: settingsButtonKey,
                        icon: const Icon(Icons.settings, color: Colors.white),
                        tooltip: "Ayarlar",
                        onPressed: _showSettingsDialog,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$nextPrayerName vaktine kalan süre",
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        timeLeft,
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 32, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                  _buildClockNode(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClockNode() {
    final now = DateTime.now();
    const ayIsimleri = ["", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    final dateStr = "${now.day.toString().padLeft(2, '0')} ${ayIsimleri[now.month]} ${now.year}";
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(dateStr, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDailyAyah() {
    if (isLoadingAyah) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (dailyAyahData == null) {
      return const Center(child: Text("Ayet bulunamadı.", style: TextStyle(color: Colors.white)));
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
                const Text("Ayet-i Kerime", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _prevAyah,
                    ),
                    const SizedBox(width: 5),
                    Text("${dailyAyahData!['surah']}, ${dailyAyahData!['numberInSurah']}. Ayet", style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
            const SizedBox(height: 8),
            const Text("English Translation (Sahih Int.):", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
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
                const Text("Sure Değiştir", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(width: 15),
                IconButton(
                  icon: const Icon(Icons.keyboard_double_arrow_right, size: 22, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _nextSurah,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerList() {
    if (prayerTimes == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 50.0),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final format = DateFormat("HH:mm");
    
    Prayer currentP = prayerTimes!.currentPrayer();
    if(currentP == Prayer.none && DateTime.now().isAfter(prayerTimes!.isha)) {
      currentP = Prayer.isha;
    } else if (currentP == Prayer.none && DateTime.now().isBefore(prayerTimes!.fajr)) {
      currentP = Prayer.isha;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          _prayerItem("İmsak", format.format(prayerTimes!.fajr), currentP == Prayer.fajr),
          _prayerItem("Güneş", format.format(prayerTimes!.sunrise), currentP == Prayer.sunrise),
          _prayerItem("Öğle", format.format(prayerTimes!.dhuhr), currentP == Prayer.dhuhr),
          _prayerItem("İkindi", format.format(prayerTimes!.asr), currentP == Prayer.asr),
          _prayerItem("Akşam", format.format(prayerTimes!.maghrib), currentP == Prayer.maghrib),
          _prayerItem("Yatsı", format.format(prayerTimes!.isha), currentP == Prayer.isha),
        ],
      ),
    );
  }

  Widget _prayerItem(String name, String time, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF6DAF89) : Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 15,
              color: isActive ? Colors.white : Colors.grey[700],
            ),
          ),
          Row(
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 15,
                  color: isActive ? Colors.white : Colors.grey[700],
                ),
              ),
              const SizedBox(width: 40),
              Icon(
                isActive ? Icons.check_circle : Icons.history, // placeholder icons
                size: 20,
                color: isActive ? Colors.white : Colors.grey[500],
              ),
            ],
          )
        ],
      ),
    );
  }

  void _shareAyah(Map<String, dynamic> data) {
    final text = "${data['surah']}, ${data['numberInSurah']}. Ayet\n\n"
        "${data['arabic']}\n\n"
        "${data['turkish1'] ?? ''}\n\n"
        "Kıble ve Namaz Rehberim uygulamasından paylaşıldı.";
    SharePlus.instance.share(ShareParams(text: text));
  }

  void _showAyahDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: dailyAyahNotifier,
          builder: (context, dynamicData, child) {
            if (dynamicData == null) return const SizedBox();
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bodyTextColor = isDark ? Colors.grey[300] : Colors.grey[800];
            final translitColor = isDark ? Colors.green[300] : Colors.green[800];
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          Text(
                            "Ayet-i Kerime\n(${dynamicData['surah']}, ${dynamicData['numberInSurah']}. Ayet)", 
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.keyboard_double_arrow_left, size: 26, color: Colors.grey),
                                onPressed: _prevSurah,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 25),
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios, size: 22, color: Colors.grey),
                                onPressed: _prevAyah,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 40),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, size: 22, color: Colors.grey),
                                onPressed: _nextAyah,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 25),
                              IconButton(
                                icon: const Icon(Icons.keyboard_double_arrow_right, size: 26, color: Colors.grey),
                                onPressed: _nextSurah,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 30),
                      Text(
                        dynamicData['arabic'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, fontFamily: 'Amiri', fontWeight: FontWeight.bold, height: 2.0),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        dynamicData['transliteration'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: translitColor, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                      ),
                      const Divider(height: 30),
                      const Text("Diyanet İşleri Meali", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 5),
                      Text(
                        dynamicData['turkish1'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: bodyTextColor, height: 1.5),
                      ),
                      const SizedBox(height: 15),
                      const Text("Elmalılı Hamdi Yazır Meali", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 5),
                      Text(
                        dynamicData['turkish2'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: bodyTextColor, height: 1.5),
                      ),
                      const SizedBox(height: 15),
                      const Text("English Translation (Sahih Int.)", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 5),
                      Text(
                        dynamicData['english'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: bodyTextColor, height: 1.5),
                      ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      StreamBuilder<PlayerState>(
                        stream: audioPlayer?.onPlayerStateChanged,
                        builder: (context, snapshot) {
                          final currentIsPlaying = snapshot.data == PlayerState.playing;
                          return IconButton(
                            iconSize: 50,
                            icon: Icon(
                              currentIsPlaying ? Icons.stop : Icons.play_arrow,
                              color: currentIsPlaying ? Colors.red : Colors.green,
                            ),
                            onPressed: _toggleAudio,
                          );
                        }
                      ),
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.share, color: Colors.green),
                        tooltip: "Paylaş",
                        onPressed: () => _shareAyah(dynamicData),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          isAutoPlaying = false;
                          audioPlayer?.stop();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                        child: const Text("Kapat", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
          }
        );
      }
    );
  }
}

class MotifPainter extends CustomPainter {
  final int dayOfYear;
  MotifPainter(this.dayOfYear);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.8;

    final numPoints = 4 + (dayOfYear % 8); 
    final rotationSteps = 3 + (dayOfYear % 6);

    for (int r = 0; r < rotationSteps; r++) {
      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate((pi / rotationSteps) * r + (dayOfYear * 0.01));
      
      final path = Path();
      for (int i = 0; i < numPoints; i++) {
        final angle = (2 * pi / numPoints) * i;
        final x = cos(angle) * radius;
        final y = sin(angle) * radius;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
      
      canvas.drawCircle(Offset.zero, radius * 0.5, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MotifPainter oldDelegate) {
    return oldDelegate.dayOfYear != dayOfYear;
  }
}

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

enum _QiblaReadiness { noSensor, serviceDisabled, permissionDenied, permissionDeniedForever, ready }

class _QiblaScreenState extends State<QiblaScreen> {
  late Future<_QiblaReadiness> _readinessFuture;

  @override
  void initState() {
    super.initState();
    _readinessFuture = _prepare();
  }

  void _retry() {
    setState(() {
      _readinessFuture = _prepare();
    });
  }

  Future<_QiblaReadiness> _prepare() async {
    final sensorOk = await FlutterQiblah.androidDeviceSensorSupport() ?? true;
    if (!sensorOk) return _QiblaReadiness.noSensor;

    if (!await Geolocator.isLocationServiceEnabled()) {
      return _QiblaReadiness.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return _QiblaReadiness.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return _QiblaReadiness.permissionDeniedForever;
    }
    return _QiblaReadiness.ready;
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey[500]),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kıble Yönü'),
        backgroundColor: const Color(0xFF6DAF89),
      ),
      body: FutureBuilder<_QiblaReadiness>(
        future: _readinessFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          switch (snapshot.data) {
            case _QiblaReadiness.noSensor:
              return _buildMessage(
                icon: Icons.explore_off,
                message: "Cihazınızda pusula sensörü bulunmuyor.",
              );
            case _QiblaReadiness.serviceDisabled:
              return _buildMessage(
                icon: Icons.location_off,
                message: "Kıble yönünü bulabilmemiz için telefonunun konum servisini açman gerekiyor.",
                actionLabel: "Konum Ayarlarını Aç",
                onAction: () async {
                  await Geolocator.openLocationSettings();
                  _retry();
                },
              );
            case _QiblaReadiness.permissionDenied:
              return _buildMessage(
                icon: Icons.location_disabled,
                message: "Kıble yönünü hesaplayabilmemiz için konum iznine ihtiyacımız var.",
                actionLabel: "İzin Ver",
                onAction: _retry,
              );
            case _QiblaReadiness.permissionDeniedForever:
              return _buildMessage(
                icon: Icons.location_disabled,
                message: "Konum izni reddedilmiş. Kıble yönünü gösterebilmemiz için uygulama ayarlarından konum iznini açman gerekiyor.",
                actionLabel: "Uygulama Ayarlarını Aç",
                onAction: () async {
                  await Geolocator.openAppSettings();
                  _retry();
                },
              );
            case _QiblaReadiness.ready:
              return const QiblaCompass();
            default:
              return const SizedBox();
          }
        },
      ),
    );
  }
}

class QiblaCompass extends StatelessWidget {
  const QiblaCompass({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FlutterQiblah.qiblahStream,
      builder: (_, AsyncSnapshot<QiblahDirection> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_disabled, size: 56, color: Colors.grey[700]),
                  const SizedBox(height: 20),
                  const Text(
                    "Konumuna ulaşamadık. Konum servisinin açık olduğundan emin olup tekrar dener misin?",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text("Pusula sensörü verisi bekleniyor. (Konumun açık olduğundan emin olun.)"));
        }

        final qiblahDirection = snapshot.data!;

        // qiblahDirection.qiblah = heading - offset (mod 360): how far the
        // Kaaba marker sits from the device's current heading, measured the
        // opposite way round from the compass ring's own rotation. Negating
        // it here keeps both rotations in the same clockwise convention, so
        // the marker lands at the Kaaba's true screen position instead of
        // its mirror image.
        final markerAngle = qiblahDirection.qiblah * (pi / 180) * -1;

        // Signed remaining angle to rotate to face the Kaaba exactly, in (-180, 180].
        var remaining = qiblahDirection.qiblah % 360;
        if (remaining > 180) remaining -= 360;
        final isAligned = remaining.abs() <= 3;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isAligned ? Colors.green.shade700 : Colors.black87,
                ),
                child: Text(
                  isAligned
                      ? "Kıbleyi Buldunuz!"
                      : "Kıbleye dönmek için ${remaining.abs().toStringAsFixed(0)}° ${remaining > 0 ? 'sağa' : 'sola'} çevirin",
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Kıble, kuzeyden ${qiblahDirection.offset.toStringAsFixed(1)}° yönünde",
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),
              Stack(
                alignment: Alignment.center,
                children: [
                  // Background container just for aesthetics
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isAligned
                          ? Colors.green.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.2),
                      border: isAligned
                          ? Border.all(color: Colors.green, width: 3)
                          : null,
                    ),
                  ),
                  // Dial with directions
                  Transform.rotate(
                    angle: (qiblahDirection.direction * (pi / 180) * -1),
                    child: CustomPaint(
                      size: const Size(300, 300),
                      painter: CompassRingPainter(),
                    ),
                  ),
                  // Kaaba Indicator
                  Transform.rotate(
                    angle: markerAngle,
                    child: Container(
                      width: 300,
                      height: 300,
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Icon(
                          Icons.mosque,
                          size: isAligned ? 58 : 50,
                          color: isAligned ? Colors.amber.shade700 : Colors.green,
                        ),
                      ),
                    ),
                  ),
                  // Phone heading indicator (fixed at top)
                  const Positioned(
                    top: -15,
                    child: Icon(Icons.arrow_drop_up, size: 40, color: Colors.black54),
                  ),
                  Icon(Icons.fiber_manual_record, size: 15, color: isAligned ? Colors.amber.shade700 : Colors.green),
                ],
              ),
              const SizedBox(height: 40),
              const Text("Pusulayı hizalamak için cihazınızı uzak tutun ve yatay çevirin.", textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }
}

class CompassRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = Colors.green.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, ringPaint);

    final tickPaint = Paint()..color = Colors.green.shade900..strokeWidth = 2;
    for (int i = 0; i < 360; i += 45) {
      if (i % 90 != 0) {
        final angle = i * pi / 180;
        final outer = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
        final inner = Offset(center.dx + (radius - 12) * cos(angle), center.dy + (radius - 12) * sin(angle));
        canvas.drawLine(inner, outer, tickPaint);
      }
    }

    const textStyle = TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold);
    _drawText(canvas, "K", center, Offset(0, -radius + 25), textStyle); 
    _drawText(canvas, "G", center, Offset(0, radius - 25), textStyle); 
    _drawText(canvas, "D", center, Offset(radius - 25, 0), textStyle); 
    _drawText(canvas, "B", center, Offset(-radius + 25, 0), textStyle); 
  }

  void _drawText(Canvas canvas, String text, Offset center, Offset offset, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    canvas.save();
    canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ZikirmatikDialog extends StatefulWidget {
  const ZikirmatikDialog({super.key});

  @override
  State<ZikirmatikDialog> createState() => _ZikirmatikDialogState();
}

class _ZikirmatikDialogState extends State<ZikirmatikDialog> {
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
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.90;
    final dialogHeight = screenSize.height * 0.90;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: const Color(0xFF1E293B),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _resetCount,
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
                  label: const Text(
                    "Sıfırla",
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const Text(
                  "Zikirmatik",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                  const Text(
                    "SAYAC",
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 14,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$_count",
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
                                  const Text(
                                    "BAS",
                                    style: TextStyle(
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
    );
  }
}

