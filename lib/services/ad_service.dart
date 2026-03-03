import 'dart:async';
import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Result returned after attempting to show a rewarded ad.
enum AdResult {
  /// User watched the ad and earned a reward.
  rewarded,

  /// Ad was dismissed before completion (no reward).
  dismissed,

  /// Ad failed to load or show.
  failed,
}

/// Abstract interface for rewarded-ad operations.
///
/// Inject a concrete implementation (e.g. [GoogleAdService]) at runtime and a
/// [MockAdService] in tests.
abstract class AdService {
  /// Loads a new rewarded ad in the background.  Call this as early as
  /// possible so the ad is ready when the user requests it.
  Future<void> loadAd();

  /// Shows the loaded rewarded ad and returns an [AdResult].
  ///
  /// Returns [AdResult.failed] if no ad is loaded.
  Future<AdResult> showAd();

  /// Whether an ad is currently loaded and ready to show.
  bool get isAdLoaded;
}

/// Production implementation backed by Google Mobile Ads.
///
/// **Setup**
///
/// 1. Replace [_androidAdUnitId] / [_iosAdUnitId] with your real ad unit IDs
///    from AdMob (or pass them in via `--dart-define`).
/// 2. Call `MobileAds.instance.initialize()` once in `main()` before creating
///    this service.
///
/// The defaults use Google's official test ad-unit IDs so the SDK works
/// without real credentials during development.
class GoogleAdService implements AdService {
  static const String _androidTestAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosTestAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  /// Override via `--dart-define=REWARDED_AD_UNIT_ANDROID=ca-app-pub-...`
  static const String _androidAdUnitId = String.fromEnvironment(
    'REWARDED_AD_UNIT_ANDROID',
    defaultValue: _androidTestAdUnitId,
  );

  /// Override via `--dart-define=REWARDED_AD_UNIT_IOS=ca-app-pub-...`
  static const String _iosAdUnitId = String.fromEnvironment(
    'REWARDED_AD_UNIT_IOS',
    defaultValue: _iosTestAdUnitId,
  );

  RewardedAd? _rewardedAd;
  bool _isLoaded = false;

  @override
  bool get isAdLoaded => _isLoaded;

  String get _adUnitId => Platform.isAndroid ? _androidAdUnitId : _iosAdUnitId;

  @override
  Future<void> loadAd() async {
    if (_isLoaded) return; // already loaded

    final completer = Completer<void>();

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoaded = true;
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _isLoaded = false;
          completer.completeError(error);
        },
      ),
    );

    return completer.future;
  }

  @override
  Future<AdResult> showAd() async {
    if (!_isLoaded || _rewardedAd == null) return AdResult.failed;

    final completer = Completer<AdResult>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isLoaded = false;
        if (!completer.isCompleted) completer.complete(AdResult.dismissed);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _isLoaded = false;
        completer.complete(AdResult.failed);
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (_, __) {
        if (!completer.isCompleted) completer.complete(AdResult.rewarded);
      },
    );

    return completer.future;
  }
}
