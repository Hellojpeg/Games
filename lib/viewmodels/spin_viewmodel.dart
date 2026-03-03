import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/spin_reward.dart';
import '../services/ad_service.dart';
import '../services/spin_service.dart';

/// Maximum number of free spins allowed per day.
const int kDailyFreeSpins = 5;

/// Maximum number of extra spins earned via rewarded ads per day.
const int kDailyAdSpins = 3;

/// Minimum duration (seconds) between watching rewarded ads.
const int kAdCooldownSeconds = 300; // 5 minutes

/// Possible high-level states for the spin screen.
enum SpinState {
  /// Idle – waiting for user to spin.
  idle,

  /// The wheel is currently animating.
  spinning,

  /// Spin has completed and a reward is ready to be displayed.
  result,

  /// User has no spins remaining (free + ad spins both exhausted).
  noSpins,

  /// An error occurred (network, Supabase, etc.).
  error,
}

/// ViewModel for the spin game screen.
///
/// Handles:
/// - Loading / daily-resetting the [SpinSession].
/// - Weighted-random reward selection.
/// - Coordinating rewarded-ad loading and showing via [AdService].
/// - Persisting results via [SpinService].
/// - Notifying the UI of state changes.
class SpinViewModel extends ChangeNotifier {
  final SpinService _spinService;
  final AdService _adService;

  SpinState _state = SpinState.idle;
  SpinSession? _session;
  SpinReward? _lastReward;
  String? _errorMessage;
  bool _isUsingAdSpin = false;

  SpinViewModel({
    SpinService? spinService,
    AdService? adService,
  })  : _spinService = spinService ?? SpinService(),
        _adService = adService ?? GoogleAdService();

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  SpinState get state => _state;
  SpinSession? get session => _session;
  SpinReward? get lastReward => _lastReward;
  String? get errorMessage => _errorMessage;

  /// Remaining free spins for today.
  int get freeSpinsLeft =>
      max(0, kDailyFreeSpins - (_session?.freeSpinsUsed ?? 0));

  /// Ad-earned spins available (earned but not yet used).
  int get adSpinsLeft => max(
        0,
        (_session?.adSpinsEarned ?? 0) - (_session?.adSpinsUsed ?? 0),
      );

  /// True when the user has at least one spin (free or ad-earned).
  bool get hasSpinsLeft => freeSpinsLeft > 0 || adSpinsLeft > 0;

  /// True when the daily ad-spin cap has not yet been reached.
  bool get canEarnMoreAdSpins =>
      (_session?.adSpinsEarned ?? 0) < kDailyAdSpins;

  /// True when the ad cooldown has elapsed (or no ad has been watched today).
  bool get isAdCooldownOver {
    final last = _session?.lastAdWatchedAt;
    if (last == null) return true;
    return DateTime.now().toUtc().difference(last).inSeconds >= kAdCooldownSeconds;
  }

  /// Whether the ad is loaded and ready.
  bool get isAdReady => _adService.isAdLoaded;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Loads today's session from Supabase and pre-loads a rewarded ad.
  Future<void> initialise() async {
    try {
      _session = await _spinService.fetchOrCreateSession();
      _updateSpinState();
      // Pre-load a rewarded ad in the background.
      unawaited(_adService.loadAd().catchError((_) {}));
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Spin
  // ---------------------------------------------------------------------------

  /// Executes a spin, consuming a free spin first, then an ad-earned spin.
  ///
  /// Returns the [SpinReward] that was won.  The caller is responsible for
  /// running the wheel animation for the required duration (2.5–4 s) before
  /// revealing the result.
  Future<SpinReward?> spin() async {
    if (!hasSpinsLeft) {
      _setState(SpinState.noSpins);
      return null;
    }

    _isUsingAdSpin = freeSpinsLeft == 0;
    _setState(SpinState.spinning);

    final reward = _pickWeightedReward();

    try {
      _session = await _spinService.recordSpin(
        reward: reward,
        currentSession: _session!,
        isAdSpin: _isUsingAdSpin,
      );
      // If the reward is an extra spin, grant it immediately.
      if (reward.type == 'spin') {
        _session = _session!.copyWith(
          adSpinsEarned: _session!.adSpinsEarned + reward.value,
        );
      }
    } catch (e) {
      // Recording failed – still show the reward locally (optimistic UX).
      // Apply local counter update so the session stays consistent.
      _session = _isUsingAdSpin
          ? _session!.copyWith(adSpinsUsed: _session!.adSpinsUsed + 1)
          : _session!.copyWith(freeSpinsUsed: _session!.freeSpinsUsed + 1);
      if (reward.type == 'spin') {
        _session = _session!.copyWith(
          adSpinsEarned: _session!.adSpinsEarned + reward.value,
        );
      }
    }

    _lastReward = reward;
    _setState(SpinState.result);

    // Pre-load the next ad so it is ready for the next out-of-spins prompt.
    unawaited(_adService.loadAd().catchError((_) {}));

    return reward;
  }

  // ---------------------------------------------------------------------------
  // Rewarded ads
  // ---------------------------------------------------------------------------

  /// Shows a rewarded ad; on completion credits one extra spin to the session.
  ///
  /// Returns true when the ad was watched in full and the spin was credited.
  Future<bool> watchAdForSpin() async {
    if (!canEarnMoreAdSpins) return false;
    if (!isAdCooldownOver) return false;

    if (!_adService.isAdLoaded) {
      try {
        await _adService.loadAd();
      } catch (_) {
        return false;
      }
    }

    final result = await _adService.showAd();
    if (result != AdResult.rewarded) return false;

    try {
      _session = await _spinService.recordAdWatched(_session!);
    } catch (_) {
      // Optimistic local update on network failure.
      _session = _session!.copyWith(
        adSpinsEarned: _session!.adSpinsEarned + 1,
        lastAdWatchedAt: DateTime.now().toUtc(),
      );
    }

    _updateSpinState();
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Selects a reward using weighted-random sampling.
  SpinReward _pickWeightedReward([Random? rng]) {
    final random = rng ?? Random();
    final totalWeight =
        kSpinRewards.fold<int>(0, (sum, r) => sum + r.weight);
    int roll = random.nextInt(totalWeight);
    for (final reward in kSpinRewards) {
      roll -= reward.weight;
      if (roll < 0) return reward;
    }
    return kSpinRewards.last;
  }

  void _updateSpinState() {
    if (!hasSpinsLeft) {
      _setState(SpinState.noSpins);
    } else {
      _setState(SpinState.idle);
    }
  }

  void _setState(SpinState newState) {
    _state = newState;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _state = SpinState.error;
    _errorMessage = message;
    notifyListeners();
  }

  /// Resets the UI to [SpinState.idle] after a result has been acknowledged.
  void acknowledgeResult() {
    _lastReward = null;
    _updateSpinState();
  }
}

/// Runs [future] in the background, logging any errors via [debugPrint].
///
/// This is a lightweight substitute for `dart:async`'s `unawaited` that also
/// surfaces background failures during development.
void unawaited(Future<void> future) {
  future.catchError((Object error, StackTrace stack) {
    debugPrint('Background operation failed: $error\n$stack');
  });
}
