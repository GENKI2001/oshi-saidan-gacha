// Rewarded ads through AdMob, iOS only for now (Android comes later).
// Until the real ad units exist these are Google's test ids, which always fill
// with a "Test Ad" and never count as real impressions.
import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../voice.dart';

class Ads {
  static final instance = Ads._();
  Ads._();

  // TODO(release): swap for the app's own rewarded unit from AdMob
  static const _rewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  /// `--dart-define=ADS=true` turns them on elsewhere (e.g. to try Android).
  bool get enabled => defaultTargetPlatform == TargetPlatform.iOS || const bool.fromEnvironment('ADS');

  RewardedAd? _ad;
  bool _loading = false;
  bool get ready => _ad != null;

  /// Consent (Google's form only where the law requires it, e.g. the EEA / UK), then the iOS
  /// tracking prompt (its reason is NSUserTrackingUsageDescription, in Japanese), then the SDK.
  Future<void> start() async {
    if (!enabled) return;
    try {
      await _consent();
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
      await MobileAds.instance.initialize();
      _load();
    } catch (e) {
      debugPrint('[Ads] start failed: $e');
    }
  }

  /// Google's consent form only where a privacy-options entry is legally required (GDPR areas).
  /// Elsewhere it would just be a generic English pre-prompt for tracking (Google's sample one while
  /// the test ids are in); iOS's own prompt is enough.
  Future<void> _consent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        final gdpr = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;
        if (!gdpr) return done.complete();
        ConsentForm.loadAndShowConsentFormIfRequired((_) => done.complete());
      },
      (_) => done.complete(),
    );
    return done.future;
  }

  void _load() {
    if (_ad != null || _loading) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _rewardedIos,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (e) {
          debugPrint('[Ads] load failed: $e');
          _loading = false;
          Future.delayed(const Duration(seconds: 20), _load);
        },
      ),
    );
  }

  /// Shows the ad and calls [onEarned] once the reward is earned (after it closes).
  /// Returns false when no ad was ready.
  Future<bool> show(void Function() onEarned) async {
    final ad = _ad;
    if (ad == null) {
      _load();
      return false;
    }
    _ad = null;
    Voice.stop(); // nobody talks over the ad
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, e) {
        ad.dispose();
        closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future;
    _load(); // the next one
    if (earned) onEarned();
    return true;
  }
}
