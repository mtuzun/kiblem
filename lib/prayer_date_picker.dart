import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';

/// Tarih çipine çift dokununca açılan tam ekran takvim. Varsayılan olarak bugün seçilidir;
/// üstte seçili günün namaz vakitleri, altta tam ekran bir takvim gösterilir. Başka bir güne
/// dokununca üstteki vakitler hemen güncellenir. Tamamen yerel hesaplama (adhan paketi);
/// internet ya da ek bir izin gerekmez.
class PrayerDatePickerScreen extends StatefulWidget {
  final Coordinates coordinates;
  final CalculationParameters params;
  final String Function(Prayer prayer) getPrayerName;
  final List<Prayer> prayers;
  final String? todayNextPrayerName;

  const PrayerDatePickerScreen({
    super.key,
    required this.coordinates,
    required this.params,
    required this.getPrayerName,
    required this.prayers,
    this.todayNextPrayerName,
  });

  @override
  State<PrayerDatePickerScreen> createState() => _PrayerDatePickerScreenState();
}

class _PrayerDatePickerScreenState extends State<PrayerDatePickerScreen> {
  late DateTime _selected;
  late PrayerTimes _times;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _recompute();
  }

  void _recompute() {
    _times = PrayerTimes(
      widget.coordinates,
      DateComponents(_selected.year, _selected.month, _selected.day),
      widget.params,
    );
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selected.year == now.year && _selected.month == now.month && _selected.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final format = DateFormat('HH:mm');
    final gregorian = "${_selected.day.toString().padLeft(2, '0')} ${longMonth(_selected.month)} ${_selected.year}";
    final hijri = hijriDateString(_selected);

    return Scaffold(
      appBar: AppBar(title: Text(t('Namaz Vakitleri Takvimi', 'Prayer Times Calendar'))),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            color: cs.surfaceContainerHighest,
            child: Column(
              children: [
                Text("$gregorian   •   $hijri", style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final prayer in widget.prayers)
                      _slot(
                        context,
                        widget.getPrayerName(prayer),
                        format.format(_times.timeForPrayer(prayer) ?? _selected),
                        _isToday && widget.getPrayerName(prayer) == widget.todayNextPrayerName,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: CalendarDatePicker(
                initialDate: _selected,
                firstDate: DateTime(_selected.year - 2),
                lastDate: DateTime(_selected.year + 3),
                onDateChanged: (d) => setState(() {
                  _selected = d;
                  _recompute();
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, String name, String time, bool active) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? cs.primary : cs.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: TextStyle(fontSize: 12, color: active ? Colors.white : null)),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: active ? Colors.white : null)),
        ],
      ),
    );
  }
}
