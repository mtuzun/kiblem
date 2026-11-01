import 'package:flutter/material.dart';

import 'figures.dart';
import 'l10n.dart';
import 'main.dart' show PrayerAlarm, setupActions, showPrivacyDetails, setThemeMode, themeModeNotifier;
import 'weather.dart' show setWeatherEnabled;

/// Yeni kurulumun ilk açılışında gösterilen kolay kurulum sihirbazı: konum, vakit uyarıları,
/// hava durumu, görünüm ve gizlilik bilgisi. Her adım atlanabilir; seçimlerin hepsi sonradan
/// Ayarlar'dan değiştirilebilir ve adım metinleri bunu açıkça söyler.
///
/// Görsel dil uygulamanın kendisinden gelir: yeşil zemin, başlıktaki dekoratif figürler
/// (cami, kandil, lale, Selçuklu yıldızı, hilal) ve ana ekrandaki gibi yuvarlak köşeli beyaz kartlar.
class SetupWizard extends StatefulWidget {
  final VoidCallback onFinished;

  const SetupWizard({super.key, required this.onFinished});

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  static const int _pageCount = 5;
  static const Color _gold = Color(0xFFE9C46A);

  int _page = 0;
  bool _busy = false;

  /// Alarm adımında "Evet" denince vakit listesi açılır.
  bool _alarmSetup = false;

  void _next() {
    if (!mounted) return;
    if (_page >= _pageCount - 1) {
      widget.onFinished();
    } else {
      setState(() => _page++);
    }
  }

  /// Uzun süren bir işlemi (izin penceresi, alarm kurma) yaparken düğmeleri kilitler.
  Future<void> _run(Future<void> Function() action, {bool advance = true}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('Kolay kurulum adımı tamamlanamadı: $e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (advance) _next();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: langNotifier,
      builder: (context, _, _) {
        final step = _steps(context)[_page];
        return Material(
          color: step.dark,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [step.dark, step.mid],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final heroHeight = (constraints.maxHeight * 0.28).clamp(110.0, 260.0);
                  return Column(
                    children: [
                      const SizedBox(height: 14),
                      _dots(),
                      SizedBox(
                        height: heroHeight,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(animation), child: child),
                          ),
                          child: _Hero(key: ValueKey(_page), figure: step.figure, height: heroHeight),
                        ),
                      ),
                      Expanded(child: _sheet(context, step)),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dots() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < _pageCount; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: i == _page ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: i == _page ? _gold : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
    ],
  );

  /// Alttaki yuvarlak köşeli beyaz kart: başlık ve metin kayar, düğmeler altta sabit durur.
  Widget _sheet(BuildContext context, _Step step) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Color.lerp(step.mid, Colors.white, 0.5)! : Color.lerp(step.mid, Colors.black, 0.2)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey(_page),
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 26, 26, 8),
                  child: Column(
                    children: [
                      Text(
                        step.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: titleColor, height: 1.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.body,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, height: 1.5, color: cs.onSurface.withValues(alpha: 0.85)),
                      ),
                      if (step.extra != null) ...[const SizedBox(height: 18), step.extra!],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 6, 26, 10),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: step.mid,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        ),
                        onPressed: _busy ? null : step.onPrimary,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(step.primary, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(
                      height: step.secondary == null ? 6 : 44,
                      child: step.secondary == null
                          ? null
                          : TextButton(
                              onPressed: _busy ? null : step.onSecondary,
                              child: Text(step.secondary!, style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Alarm adımı: önce "kullanmak ister misiniz?" sorulur; "Evet" denince beş vakit varsayılan olarak
  /// açılır ve hangi vakitlerde, ne zaman çalacağı bu adımda seçilir (Ayarlar'daki aynı seçimler).
  _Step _alarmStep() {
    const dark = Color(0xFF4A2C0F);
    const mid = Color(0xFFB8741F);
    if (!_alarmSetup) {
      return _Step(
        figure: 'lantern',
        dark: dark,
        mid: mid,
        title: t("Alarm kullanmak ister misiniz?", "Would you like to use alarms?"),
        body: t(
          "Vakit girince sizi uyaralım. Hangi vakitte ve ne zaman çalacağını birazdan siz seçersiniz.",
          "We can alert you when a prayer time comes. In a moment you choose which prayers and when.",
        ),
        primary: t("Evet", "Yes"),
        onPrimary: () => _run(() async {
          await setupActions.enableAlarms?.call();
          if (mounted) setState(() => _alarmSetup = true);
        }, advance: false),
        secondary: t("Hayır, şimdilik kalsın", "No, maybe later"),
        onSecondary: _next,
      );
    }
    return _Step(
      figure: 'lantern',
      dark: dark,
      mid: mid,
      title: t("Vakitleri seçin", "Choose the prayers"),
      body: t(
        "Zamanı dokunarak değiştirin. Ayarlar'dan her zaman değiştirebilirsiniz.",
        "Tap a time to change it. You can always change this in Settings.",
      ),
      extra: _alarmList(),
      primary: t("Devam Et", "Continue"),
      onPrimary: _next,
    );
  }

  Widget _alarmList() {
    final alarms = setupActions.alarms?.call() ?? const <PrayerAlarm>[];
    return Column(
      children: [
        for (var i = 0; i < alarms.length; i++)
          Row(
            children: [
              Switch(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                value: alarms[i].enabled,
                onChanged: (v) async {
                  await setupActions.setAlarmEnabled?.call(i, v);
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(setupActions.alarmName?.call(i) ?? "", style: const TextStyle(fontSize: 16))),
              TextButton(
                onPressed: alarms[i].enabled
                    ? () async {
                        await setupActions.pickAlarmMinutes?.call(i);
                        if (mounted) setState(() {});
                      }
                    : null,
                child: Text(setupActions.minutesLabel?.call(alarms[i].minutes, alarms[i].after) ?? ""),
              ),
            ],
          ),
      ],
    );
  }

  List<_Step> _steps(BuildContext context) => [
    _Step(
      figure: 'mosque',
      dark: const Color(0xFF0E3B2A),
      mid: const Color(0xFF1F7A4D),
      title: t('Hoş geldiniz!', 'Welcome!'),
      body: t(
        "Konumunuzla bulunduğunuz yerin vakitlerini hemen bulalım.",
        "Let us find the prayer times for where you are, using your location.",
      ),
      primary: t('Devam Et', 'Continue'),
      onPrimary: () => _run(() async => await setupActions.locate?.call()),
      secondary: t('Listeden Seç', 'Choose from List'),
      onSecondary: () => _run(() async => await setupActions.pickCity?.call()),
    ),
    _alarmStep(),
    _Step(
      figure: 'tulip',
      dark: const Color(0xFF0B2E4F),
      mid: const Color(0xFF2C77B3),
      title: t('Hava nasıl, bakalım mı?', 'Curious about the weather?'),
      body: t(
        "3 günlük hava durumunu gösterelim. Ayarlar'dan istediğiniz zaman kapatabilirsiniz.",
        "Show a 3-day forecast? You can turn it off any time in Settings.",
      ),
      primary: t('Gösterin', 'Yes, show it'),
      onPrimary: () => _run(() => setWeatherEnabled(true)),
      secondary: t('Gerek yok', 'No, thanks'),
      onSecondary: () => _run(() => setWeatherEnabled(false)),
    ),
    _Step(
      figure: 'star8',
      dark: const Color(0xFF2E1A47),
      mid: const Color(0xFF7348AD),
      title: t('Kendinize göre ayarlayalım', 'Make it yours'),
      body: t(
        "Dil ve temayı seçin. Ayarlar'dan değiştirebilirsiniz.",
        "Pick a language and theme. You can change them in Settings.",
      ),
      extra: Column(
        children: [
          ValueListenableBuilder<String>(
            valueListenable: langNotifier,
            builder: (context, lang, _) => SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'tr', label: Text('Türkçe')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {lang},
              onSelectionChanged: (s) => setLanguage(s.first),
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) => SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: ThemeMode.light, label: Text(t('Açık', 'Light'))),
                ButtonSegment(value: ThemeMode.dark, label: Text(t('Koyu', 'Dark'))),
                ButtonSegment(value: ThemeMode.system, label: Text(t('Sistem', 'System'))),
              ],
              selected: {mode},
              onSelectionChanged: (s) => setThemeMode(s.first),
            ),
          ),
        ],
      ),
      primary: t('Devam Et', 'Continue'),
      onPrimary: _next,
    ),
    _Step(
      figure: 'crescent_star',
      dark: const Color(0xFF0A2F35),
      mid: const Color(0xFF1E7F86),
      title: t('Gizliliğiniz bizim için önemli', 'Your privacy matters to us'),
      body: t(
        "Gizlilik ve KVKK Bilgilendirmesi'ne Ayarlar'ın en üstünden her zaman ulaşabilirsiniz.",
        "You can always find the Privacy and KVKK Notice at the top of Settings.",
      ),
      primary: t('Başlayalım', 'Let\'s start'),
      onPrimary: _next,
      secondary: t('Bilgilendirmeyi Oku', 'Read the Notice'),
      onSecondary: () => showPrivacyDetails(context),
    ),
  ];
}

/// Üstteki kahraman alanı: yarı saydam Selçuklu yıldızı deseni, altın halkalı yuvarlak madalyon ve
/// içinde adıma uygun uygulama figürü.
class _Hero extends StatelessWidget {
  final String figure;
  final double height;

  const _Hero({super.key, required this.figure, required this.height});

  @override
  Widget build(BuildContext context) {
    final medallion = (height * 0.66).clamp(84.0, 160.0);
    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          OverflowBox(
            maxWidth: height * 2.2,
            maxHeight: height * 2.2,
            child: Opacity(
              opacity: 0.07,
              child: CustomPaint(size: Size(height * 2.2, height * 2.2), painter: const FigurePainter('star8')),
            ),
          ),
          Container(
            width: medallion * 1.28,
            height: medallion * 1.28,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
          ),
          Container(
            width: medallion,
            height: medallion,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: const Color(0xFFE9C46A), width: 2),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))],
            ),
            alignment: Alignment.center,
            child: CustomPaint(size: Size(medallion * 0.56, medallion * 0.56), painter: FigurePainter(figure)),
          ),
        ],
      ),
    );
  }
}

class _Step {
  final String figure;

  /// Adımın zemin renkleri: üstte koyu, altta açık ton; düğme ve başlık da `mid` rengini alır.
  final Color dark;
  final Color mid;
  final String title;
  final String body;
  final Widget? extra;
  final String primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  const _Step({
    required this.figure,
    required this.dark,
    required this.mid,
    required this.title,
    required this.body,
    this.extra,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
  });
}
