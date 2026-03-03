import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:games/models/spin_reward.dart';
import 'package:games/services/ad_service.dart';
import 'package:games/services/spin_service.dart';
import 'package:games/viewmodels/spin_viewmodel.dart';

import 'spin_viewmodel_test.mocks.dart';

@GenerateMocks([SpinService, AdService])
void main() {
  late MockSpinService mockSpinService;
  late MockAdService mockAdService;
  late SpinViewModel viewModel;

  // A session with 3 free spins already used (2 remaining) and no ad spins.
  final _baseSession = SpinSession(
    date: '2024-01-15',
    freeSpinsUsed: 3,
    adSpinsEarned: 0,
    adSpinsUsed: 0,
  );

  // A session with all free spins used and 1 ad spin available.
  final _adSpinSession = SpinSession(
    date: '2024-01-15',
    freeSpinsUsed: kDailyFreeSpins,
    adSpinsEarned: 1,
    adSpinsUsed: 0,
  );

  // A completely exhausted session.
  final _exhaustedSession = SpinSession(
    date: '2024-01-15',
    freeSpinsUsed: kDailyFreeSpins,
    adSpinsEarned: kDailyAdSpins,
    adSpinsUsed: kDailyAdSpins,
  );

  setUp(() {
    mockSpinService = MockSpinService();
    mockAdService = MockAdService();
    viewModel = SpinViewModel(
      spinService: mockSpinService,
      adService: mockAdService,
    );
  });

  // ---------------------------------------------------------------------------
  // SpinSession helpers
  // ---------------------------------------------------------------------------

  group('SpinViewModel – freeSpinsLeft / adSpinsLeft', () {
    test('counts free spins correctly', () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _baseSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);

      await viewModel.initialise();

      expect(viewModel.freeSpinsLeft, kDailyFreeSpins - 3);
      expect(viewModel.adSpinsLeft, 0);
      expect(viewModel.hasSpinsLeft, isTrue);
    });

    test('hasSpinsLeft is false when session is exhausted', () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _exhaustedSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);

      await viewModel.initialise();

      expect(viewModel.hasSpinsLeft, isFalse);
      expect(viewModel.state, SpinState.noSpins);
    });
  });

  // ---------------------------------------------------------------------------
  // spin()
  // ---------------------------------------------------------------------------

  group('SpinViewModel – spin()', () {
    test('returns null and sets noSpins state when no spins available',
        () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _exhaustedSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);

      await viewModel.initialise();
      final reward = await viewModel.spin();

      expect(reward, isNull);
      expect(viewModel.state, SpinState.noSpins);
    });

    test('transitions through spinning → result on a successful spin',
        () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _baseSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);

      // Return an updated session after recording the spin.
      when(mockSpinService.recordSpin(
        reward: anyNamed('reward'),
        currentSession: anyNamed('currentSession'),
        isAdSpin: anyNamed('isAdSpin'),
      )).thenAnswer(
        (_) async => _baseSession.copyWith(freeSpinsUsed: 4),
      );

      await viewModel.initialise();

      final states = <SpinState>[];
      viewModel.addListener(() => states.add(viewModel.state));

      await viewModel.spin();

      // spinning must appear before result.
      expect(states, containsAllInOrder([SpinState.spinning, SpinState.result]));
      expect(viewModel.lastReward, isNotNull);
    });

    test('uses ad spin when no free spins remain', () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _adSpinSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);

      bool? capturedIsAdSpin;
      when(mockSpinService.recordSpin(
        reward: anyNamed('reward'),
        currentSession: anyNamed('currentSession'),
        isAdSpin: anyNamed('isAdSpin'),
      )).thenAnswer((inv) async {
        capturedIsAdSpin =
            inv.namedArguments[const Symbol('isAdSpin')] as bool;
        return _adSpinSession.copyWith(adSpinsUsed: 1);
      });

      await viewModel.initialise();
      await viewModel.spin();

      expect(capturedIsAdSpin, isTrue);
    });

    test('still sets result state when recordSpin throws', () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _baseSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);

      when(mockSpinService.recordSpin(
        reward: anyNamed('reward'),
        currentSession: anyNamed('currentSession'),
        isAdSpin: anyNamed('isAdSpin'),
      )).thenThrow(Exception('network error'));

      await viewModel.initialise();
      final reward = await viewModel.spin();

      expect(reward, isNotNull);
      expect(viewModel.state, SpinState.result);
    });
  });

  // ---------------------------------------------------------------------------
  // watchAdForSpin()
  // ---------------------------------------------------------------------------

  group('SpinViewModel – watchAdForSpin()', () {
    test('returns false when daily ad cap is reached', () async {
      final cappedSession = SpinSession(
        date: '2024-01-15',
        freeSpinsUsed: kDailyFreeSpins,
        adSpinsEarned: kDailyAdSpins, // cap reached
        adSpinsUsed: kDailyAdSpins,
      );
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => cappedSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);

      await viewModel.initialise();
      final result = await viewModel.watchAdForSpin();

      expect(result, isFalse);
    });

    test('returns false when ad cooldown has not elapsed', () async {
      final recentAdSession = SpinSession(
        date: '2024-01-15',
        freeSpinsUsed: kDailyFreeSpins,
        adSpinsEarned: 1,
        adSpinsUsed: 1,
        lastAdWatchedAt: DateTime.now().toUtc(), // just watched
      );
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => recentAdSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);

      await viewModel.initialise();
      final result = await viewModel.watchAdForSpin();

      expect(result, isFalse);
    });

    test('credits spin and returns true after successful rewarded ad',
        () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _baseSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(true);
      when(mockAdService.showAd()).thenAnswer((_) async => AdResult.rewarded);
      when(mockSpinService.recordAdWatched(any))
          .thenAnswer((_) async => _baseSession.copyWith(adSpinsEarned: 1));

      await viewModel.initialise();
      final result = await viewModel.watchAdForSpin();

      expect(result, isTrue);
      expect(viewModel.session?.adSpinsEarned, 1);
    });

    test('returns false when ad is dismissed without completion', () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _baseSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(true);
      when(mockAdService.showAd())
          .thenAnswer((_) async => AdResult.dismissed);

      await viewModel.initialise();
      final result = await viewModel.watchAdForSpin();

      expect(result, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Weighted reward selection
  // ---------------------------------------------------------------------------

  group('SpinViewModel – weighted reward selection', () {
    test('spin() always returns a reward from kSpinRewards', () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _baseSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);
      when(mockSpinService.recordSpin(
        reward: anyNamed('reward'),
        currentSession: anyNamed('currentSession'),
        isAdSpin: anyNamed('isAdSpin'),
      )).thenAnswer((inv) async {
        final reward =
            inv.namedArguments[const Symbol('reward')] as SpinReward;
        expect(kSpinRewards.contains(reward), isTrue);
        return _baseSession.copyWith(freeSpinsUsed: 4);
      });

      await viewModel.initialise();
      final reward = await viewModel.spin();

      expect(reward, isNotNull);
      expect(kSpinRewards.contains(reward), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // acknowledgeResult()
  // ---------------------------------------------------------------------------

  group('SpinViewModel – acknowledgeResult()', () {
    test('clears lastReward and resets to idle when spins remain', () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _baseSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);
      when(mockSpinService.recordSpin(
        reward: anyNamed('reward'),
        currentSession: anyNamed('currentSession'),
        isAdSpin: anyNamed('isAdSpin'),
      )).thenAnswer(
        (_) async => _baseSession.copyWith(freeSpinsUsed: 4),
      );

      await viewModel.initialise();
      await viewModel.spin();

      expect(viewModel.state, SpinState.result);

      viewModel.acknowledgeResult();

      expect(viewModel.lastReward, isNull);
      expect(viewModel.state, SpinState.idle);
    });
  });

  // ---------------------------------------------------------------------------
  // canEarnMoreAdSpins / isAdCooldownOver
  // ---------------------------------------------------------------------------

  group('SpinViewModel – ad limit helpers', () {
    test('canEarnMoreAdSpins is false at cap', () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _exhaustedSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);

      await viewModel.initialise();
      expect(viewModel.canEarnMoreAdSpins, isFalse);
    });

    test('isAdCooldownOver is true when no ad watched today', () async {
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => _baseSession);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);

      await viewModel.initialise();
      expect(viewModel.isAdCooldownOver, isTrue);
    });

    test('isAdCooldownOver is false within cooldown window', () async {
      final sessionWithRecentAd = SpinSession(
        date: '2024-01-15',
        freeSpinsUsed: 0,
        adSpinsEarned: 1,
        adSpinsUsed: 1,
        lastAdWatchedAt: DateTime.now().toUtc(),
      );
      when(mockSpinService.fetchOrCreateSession())
          .thenAnswer((_) async => sessionWithRecentAd);
      when(mockAdService.loadAd()).thenAnswer((_) async {});
      when(mockAdService.isAdLoaded).thenReturn(false);

      await viewModel.initialise();
      expect(viewModel.isAdCooldownOver, isFalse);
    });
  });
}
