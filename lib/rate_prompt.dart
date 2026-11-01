import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

const _launchCountKey = 'launch_count';
const _ratingDoneKey = 'rating_done';
const _ratingNextKey = 'rating_next_launch';
const _ratingAskCountKey = 'rating_ask_count';
const _firstAskAtLaunch = 5;
const _launchesBetweenAsks = 10;
const _maxAsks = 3;
const _appStoreId = '6828909864';

/// Her açılışta sayar. [_firstAskAtLaunch]. açılıştan itibaren "yorum yazmak ve puanlamak
/// ister misiniz?" diye sorulur. "Evet" denirse bir daha sorulmaz; "Daha sonra" denirse
/// [_launchesBetweenAsks] açılış sonra tekrar sorulur, toplamda en fazla [_maxAsks] kez.
Future<bool> countLaunchAndCheckRatingDue() async {
  if (kIsWeb) return false;
  final prefs = await SharedPreferences.getInstance();
  final count = (prefs.getInt(_launchCountKey) ?? 0) + 1;
  await prefs.setInt(_launchCountKey, count);
  if (prefs.getBool(_ratingDoneKey) ?? false) return false;
  if ((prefs.getInt(_ratingAskCountKey) ?? 0) >= _maxAsks) return false;
  return count >= (prefs.getInt(_ratingNextKey) ?? _firstAskAtLaunch);
}

Future<void> askForRating(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final asked = (prefs.getInt(_ratingAskCountKey) ?? 0) + 1;
  await prefs.setInt(_ratingAskCountKey, asked);
  await prefs.setInt(_ratingNextKey, (prefs.getInt(_launchCountKey) ?? 0) + _launchesBetweenAsks);
  if (!context.mounted) return;
  final liked = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
      title: Text(
        t(
          'Uygulamamız hakkında yorum yazmak ve puanlamak ister misiniz?',
          'Would you like to rate and review our app?',
        ),
        textAlign: TextAlign.center,
      ),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var star = 1; star <= 5; star++)
            Semantics(
              button: true,
              label: t('$star yıldız', '$star stars'),
              child: InkResponse(
                radius: 24,
                onTap: () => Navigator.pop(context, true),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.star_rounded, size: 36, color: Color(0xFFF5B301)),
                ),
              ),
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(t('Daha sonra', 'Later')),
        ),
      ],
    ),
  );
  if (liked != true) return;
  await prefs.setBool(_ratingDoneKey, true);
  final review = InAppReview.instance;
  if (await review.isAvailable()) {
    await review.requestReview();
  } else {
    await review.openStoreListing(appStoreId: _appStoreId);
  }
}
