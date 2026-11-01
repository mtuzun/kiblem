import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n.dart';

const _policyUrl = 'https://mtuzun.github.io/kiblem/';

/// Ayarlar'daki ve kurulumdaki "Gizlilik ve KVKK Bilgilendirmesi" penceresi. docs/index.html'deki
/// politikayla aynı bilgileri verir; birini değiştirirken diğerini de güncelleyin.
void showPrivacyDetails(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const _PrivacyDialog(),
  );
}

class _PrivacyDialog extends StatelessWidget {
  const _PrivacyDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final summary = [
      t('Hesap gerekmez; verileriniz bizim sunucularımızda toplanmaz.',
          'No account is needed; your data is not collected on our servers.'),
      t('Konum izni vermek zorunda değilsiniz, şehri elle seçebilirsiniz.',
          'You do not have to allow location; you can choose your city manually.'),
      t('Hava durumunu Ayarlar\'dan istediğiniz zaman kapatabilirsiniz.',
          'You can turn the weather off in Settings at any time.'),
      t('Hava durumu ve reklam hizmetleri yurt dışındadır.',
          'The weather and advertising services are located abroad.'),
    ];

    final sections = <(String, String)>[
      (
        t('Veri sorumlusu', 'Data controller'),
        'Metin Tüzün (metintzn2026@gmail.com)',
      ),
      (
        t('İşlenen veriler', 'Data processed'),
        t(
          'Konumunuz (yalnızca izin verirseniz), seçtiğiniz şehir ve ülke bilgisi, uygulama ayarlarınız. '
              'Bunlar yalnızca cihazınızda saklanır ve uygulamayı sildiğinizde silinir.\n'
              'Uygulama içinde üçüncü taraf hizmetleri (hava durumu, harita, Kur\'an sesi, reklam) kullandığınızda '
              'hizmeti verenler IP adresinizi de görebilir. Reklam hizmeti ayrıca cihaz bilgisini, '
              'yaklaşık konumunuzu ve reklam etkileşimlerinizi toplayabilir.',
          'Your location (only if you allow it), your chosen city and country, and your app settings. '
              'They are stored only on your device and deleted when you delete the app.\n'
              'When you use third-party services in the app (weather, maps, Quran audio, ads), the providers '
              'can also see your IP address. The ad service may also collect device information, '
              'approximate location and ad interactions.',
        ),
      ),
      (
        t('Amaç', 'Purposes'),
        t(
          'Namaz vakitleri ve kıble hesabı, şehri bulma, hava durumu, harita, Kur\'an metni ve sesi, reklam.',
          'Prayer time and qibla calculation, finding your city, weather, maps, Quran text and audio, and ads.',
        ),
      ),
      (
        t('Konumun hukuki sebebi', 'Legal basis for location'),
        t(
          'İşletim sisteminin izin penceresinde verdiğiniz açık rıza. Cihaz ayarlarından istediğiniz zaman geri alabilirsiniz.',
          'The explicit consent you give in the operating system\'s permission prompt. You can withdraw it at any time in your device settings.',
        ),
      ),
      (
        t('Yurt dışı hizmetler', 'Services abroad'),
        t(
          'Hava durumu (MET Norway, Norveç): koordinatlar yaklaşık 1 km hassasiyetle gönderilir; '
              'hava durumunu kapatırsanız hiç gönderilmez.\n'
              'Reklam (Google AdMob).\n'
              'Şehir adı: koordinattan şehri bulmak için işletim sisteminin servisi kullanılır. '
              'Android\'de bu servis genellikle Google tarafından sağlanır ve koordinatlar ona gönderilebilir.\n'
              'Bu hizmetler ilgili sağlayıcıların gizlilik politikalarına tabidir.',
          'Weather (MET Norway, Norway): coordinates are sent at about 1 km precision; '
              'nothing is sent if you turn the weather off.\n'
              'Ads (Google AdMob).\n'
              'City name: the operating system\'s service is used to find your city from coordinates. '
              'On Android this service is usually provided by Google and the coordinates may be sent to it.\n'
              'These services are subject to their providers\' privacy policies.',
        ),
      ),
      (
        t('Haklarınız ve başvuru', 'Your rights and how to apply'),
        t(
          'KVKK m.11 kapsamındaki haklarınız (bilgi alma, düzeltme, silme, itiraz vb.) için yukarıdaki '
              'e-posta adresine başvurabilirsiniz. Başvurunuz en geç 30 gün içinde yanıtlanır.',
          'For your rights under KVKK Art. 11 (access, correction, deletion, objection, etc.) write to the '
              'email address above. Requests are answered within 30 days.',
        ),
      ),
    ];

    return AlertDialog(
      scrollable: true,
      title: Text(t('Gizlilik ve KVKK Bilgilendirmesi', 'Privacy and KVKK Notice')),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in summary)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline, size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(line, style: textTheme.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          for (final (heading, body) in sections) ...[
            const SizedBox(height: 14),
            Text(heading, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            SelectableText(body, style: textTheme.bodyMedium),
          ],
          const SizedBox(height: 14),
          Text(
            t(
              'Bu metin bilgilendirme amaçlıdır (6698 sayılı KVKK m.10).',
              'This notice is for information (KVKK Art. 10).',
            ),
            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => launchUrl(Uri.parse(_policyUrl), mode: LaunchMode.externalApplication),
          child: Text(t('Tam politikayı aç', 'Open full policy')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('Kapat', 'Close')),
        ),
      ],
    );
  }
}
