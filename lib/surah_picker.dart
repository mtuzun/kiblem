import 'package:flutter/material.dart';

import 'l10n.dart';

// ---------------------------------------------------------------------------
// Sure listesinden seçim yapıp o surenin istenen ayetine atlama ekranı.
// ---------------------------------------------------------------------------

/// Her surenin Türkçe adı, ayet sayısı ve Kur'an'daki ilk ayetinin genel (1-6236) numarası.
class SurahInfo {
  final int number; // 1-114
  final String nameTr;
  final String nameEn;
  final int ayahCount;
  final int firstAyahNumber;
  const SurahInfo(this.number, this.nameTr, this.nameEn, this.ayahCount, this.firstAyahNumber);
}

const List<String> _namesTr = [
  "Fâtiha", "Bakara", "Âl-i İmrân", "Nisâ", "Mâide", "En'âm", "A'râf", "Enfâl", "Tevbe", "Yûnus",
  "Hûd", "Yûsuf", "Ra'd", "İbrâhîm", "Hicr", "Nahl", "İsrâ", "Kehf", "Meryem", "Tâhâ",
  "Enbiyâ", "Hac", "Mü'minûn", "Nûr", "Furkân", "Şuarâ", "Neml", "Kasas", "Ankebût", "Rûm",
  "Lokmân", "Secde", "Ahzâb", "Sebe'", "Fâtır", "Yâsîn", "Sâffât", "Sâd", "Zümer", "Mü'min (Gâfir)",
  "Fussilet", "Şûrâ", "Zuhruf", "Duhân", "Câsiye", "Ahkâf", "Muhammed", "Fetih", "Hucurât", "Kâf",
  "Zâriyât", "Tûr", "Necm", "Kamer", "Rahmân", "Vâkıa", "Hadîd", "Mücâdele", "Haşr", "Mümtehine",
  "Saff", "Cum'a", "Münâfikûn", "Tegâbün", "Talâk", "Tahrîm", "Mülk", "Kalem", "Hâkka", "Meâric",
  "Nûh", "Cin", "Müzzemmil", "Müddessir", "Kıyâmet", "İnsân", "Mürselât", "Nebe'", "Nâziât", "Abese",
  "Tekvîr", "İnfitâr", "Mutaffifîn", "İnşikâk", "Burûc", "Târık", "A'lâ", "Gâşiye", "Fecr", "Beled",
  "Şems", "Leyl", "Duhâ", "İnşirâh", "Tîn", "Alak", "Kadr", "Beyyine", "Zilzâl", "Âdiyât",
  "Kâria", "Tekâsür", "Asr", "Hümeze", "Fîl", "Kureyş", "Mâûn", "Kevser", "Kâfirûn", "Nasr",
  "Tebbet", "İhlâs", "Felak", "Nâs",
];

const List<String> _namesEn = [
  "Al-Faatiha", "Al-Baqara", "Aal-i-Imraan", "An-Nisaa", "Al-Maaida", "Al-An'aam", "Al-A'raaf", "Al-Anfaal", "At-Tawba", "Yunus",
  "Hud", "Yusuf", "Ar-Ra'd", "Ibrahim", "Al-Hijr", "An-Nahl", "Al-Israa", "Al-Kahf", "Maryam", "Taa-Haa",
  "Al-Anbiyaa", "Al-Hajj", "Al-Mu'minoon", "An-Noor", "Al-Furqaan", "Ash-Shu'araa", "An-Naml", "Al-Qasas", "Al-Ankaboot", "Ar-Room",
  "Luqman", "As-Sajda", "Al-Ahzaab", "Saba", "Faatir", "Yaseen", "As-Saaffaat", "Saad", "Az-Zumar", "Ghafir",
  "Fussilat", "Ash-Shura", "Az-Zukhruf", "Ad-Dukhaan", "Al-Jaathiya", "Al-Ahqaf", "Muhammad", "Al-Fath", "Al-Hujuraat", "Qaaf",
  "Adh-Dhaariyat", "At-Tur", "An-Najm", "Al-Qamar", "Ar-Rahmaan", "Al-Waaqia", "Al-Hadid", "Al-Mujaadila", "Al-Hashr", "Al-Mumtahana",
  "As-Saff", "Al-Jumu'a", "Al-Munaafiqoon", "At-Taghaabun", "At-Talaaq", "At-Tahrim", "Al-Mulk", "Al-Qalam", "Al-Haaqqa", "Al-Ma'aarij",
  "Nooh", "Al-Jinn", "Al-Muzzammil", "Al-Muddaththir", "Al-Qiyaama", "Al-Insaan", "Al-Mursalaat", "An-Naba", "An-Naazi'aat", "Abasa",
  "At-Takwir", "Al-Infitaar", "Al-Mutaffifin", "Al-Inshiqaaq", "Al-Burooj", "At-Taariq", "Al-A'laa", "Al-Ghaashiya", "Al-Fajr", "Al-Balad",
  "Ash-Shams", "Al-Lail", "Ad-Dhuhaa", "Ash-Sharh", "At-Tin", "Al-Alaq", "Al-Qadr", "Al-Bayyina", "Az-Zalzala", "Al-Aadiyaat",
  "Al-Qaari'a", "At-Takaathur", "Al-Asr", "Al-Humaza", "Al-Fil", "Quraish", "Al-Maa'un", "Al-Kawthar", "Al-Kaafiroon", "An-Nasr",
  "Al-Masad", "Al-Ikhlaas", "Al-Falaq", "An-Naas",
];

/// main.dart'taki _ayahCountPerSurah ile aynı (114 surenin ayet sayıları).
const List<int> surahAyahCounts = [
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
  5, 4, 5, 6,
];

final List<SurahInfo> surahList = (() {
  final list = <SurahInfo>[];
  var start = 1;
  for (var i = 0; i < 114; i++) {
    list.add(SurahInfo(i + 1, _namesTr[i], _namesEn[i], surahAyahCounts[i], start));
    start += surahAyahCounts[i];
  }
  return list;
})();

/// Sure listesinden birini seçtirip, o surenin istenen ayetine karşılık gelen genel
/// (1-6236) ayet numarasını döndürür. Vazgeçilirse null döner.
class SurahPickerScreen extends StatefulWidget {
  const SurahPickerScreen({super.key});

  @override
  State<SurahPickerScreen> createState() => _SurahPickerScreenState();
}

class _SurahPickerScreenState extends State<SurahPickerScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SurahInfo> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return surahList;
    return surahList.where((s) {
      if (s.number.toString() == q) return true;
      return s.nameTr.toLowerCase().contains(q) || s.nameEn.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _pickAyah(SurahInfo s) async {
    final controller = TextEditingController();
    final name = t(s.nameTr, s.nameEn);
    // Kutu boş bırakılırsa 1. ayete gidilir.
    int enteredOrFirst() => int.tryParse(controller.text.trim()) ?? 1;
    var cancelled = true;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('$name Suresi', name)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: t('Ayet no', 'Verse number'),
            hintText: '1',
            helperText: t('1 - ${s.ayahCount} arası; boş bırakırsan 1. ayet', 'Between 1 and ${s.ayahCount}; empty means verse 1'),
          ),
          onSubmitted: (_) {
            cancelled = false;
            Navigator.pop(context, enteredOrFirst());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Vazgeç', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              cancelled = false;
              Navigator.pop(context, enteredOrFirst());
            },
            child: Text(t('Git', 'Go')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (cancelled || result == null || !mounted) return;
    final clamped = result.clamp(1, s.ayahCount);
    Navigator.pop(context, s.firstAyahNumber + clamped - 1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t('Sure Seç', 'Select Surah'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: t('Sure adı veya numarası', 'Surah name or number'),
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = _filtered[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Text('${s.number}', style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer)),
                  ),
                  title: Text(t(s.nameTr, s.nameEn)),
                  subtitle: Text(t('${s.ayahCount} ayet', '${s.ayahCount} verses')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickAyah(s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
