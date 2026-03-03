import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/spin_reward.dart';
import '../viewmodels/spin_viewmodel.dart';
import '../widgets/out_of_spins_modal.dart';
import '../widgets/spin_wheel_widget.dart';

/// Full-screen spin-wheel game screen.
///
/// Provides:
/// - Animated spin wheel (2.5 – 4 seconds per spin).
/// - In-place reward celebration overlay.
/// - Automatic "Out of Spins" modal when [SpinState.noSpins] is reached.
class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _spinAnimation;
  SpinViewModel? _vm;

  int _targetIndex = 0;

  // Duration band: 2.5 – 4 seconds, randomised per spin.
  Duration _spinDuration(math.Random rng) => Duration(
        milliseconds: 2500 + rng.nextInt(1501), // 2500..4000 ms
      );

  // Prevents the "Out of Spins" modal from being shown more than once per
  // noSpins state transition.
  bool _noSpinsModalShown = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _spinAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.decelerate,
    );

    // Load today's session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm = context.read<SpinViewModel>();
      _vm!.addListener(_onViewModelChanged);
      _vm!.initialise();
    });
  }

  void _onViewModelChanged() {
    final vm = _vm;
    if (vm == null) return;
    if (vm.state == SpinState.noSpins && !_noSpinsModalShown && mounted) {
      _noSpinsModalShown = true;
      OutOfSpinsModal.show(context, vm).then((_) {
        if (mounted) _noSpinsModalShown = false;
      });
    } else if (vm.state != SpinState.noSpins) {
      _noSpinsModalShown = false;
    }
  }

  @override
  void dispose() {
    _vm?.removeListener(_onViewModelChanged);
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Spin trigger
  // ---------------------------------------------------------------------------

  Future<void> _onSpinPressed(SpinViewModel vm) async {
    if (!vm.hasSpinsLeft) {
      await OutOfSpinsModal.show(context, vm);
      return;
    }

    final rng = math.Random();

    // Pick the target index deterministically before animating so the wheel
    // always lands on the correct segment.
    _targetIndex = _computeTargetIndex(vm);

    final totalAngle = computeTargetAngle(
      targetIndex: _targetIndex,
      rewardCount: kSpinRewards.length,
    );

    _controller.duration = _spinDuration(rng);
    _spinAnimation = Tween<double>(
      begin: 0,
      end: totalAngle / (2 * math.pi),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));

    _controller.reset();

    // Start the backend call and animation in parallel.
    final spinFuture = vm.spin();

    // Await the animation to finish (2.5 – 4 seconds).
    await _controller.forward();
    await spinFuture;

    if (!mounted) return;

    // If an "Extra Spin" reward was won, briefly inform the user via snack.
    final reward = vm.lastReward;
    if (reward != null && reward.type == 'spin') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 You won ${reward.value} extra spin(s)!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Randomly picks the target reward index.  The actual weighted pick happens
  /// inside [SpinViewModel.spin]; this index is used only for the animation.
  /// After the server resolves, [SpinViewModel.lastReward] is authoritative.
  ///
  /// For a fully server-authoritative wheel the app would need to know the
  /// result *before* starting the animation; this optimistic approach starts
  /// the animation with a local prediction and replaces it on completion.
  int _computeTargetIndex(SpinViewModel vm) {
    // Use a uniform pick here; the ViewModel's weighted pick is authoritative.
    return math.Random().nextInt(kSpinRewards.length);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Spin & Win',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0533), Color(0xFF3D0B6B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Consumer<SpinViewModel>(
          builder: (context, vm, _) {
            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildSpinCounter(vm),
                  const SizedBox(height: 24),
                  _buildWheel(vm),
                  const SizedBox(height: 32),
                  if (vm.state == SpinState.result && vm.lastReward != null)
                    _buildRewardBanner(vm.lastReward!)
                  else
                    const SizedBox(height: 72),
                  const Spacer(),
                  _buildSpinButton(vm),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildSpinCounter(SpinViewModel vm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SpinBadge(
          icon: Icons.refresh,
          label: '${vm.freeSpinsLeft}',
          sublabel: 'Free',
          color: Colors.greenAccent,
        ),
        const SizedBox(width: 16),
        _SpinBadge(
          icon: Icons.play_circle_outline,
          label: '${vm.adSpinsLeft}',
          sublabel: 'Ad',
          color: Colors.amberAccent,
        ),
      ],
    );
  }

  Widget _buildWheel(SpinViewModel vm) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: SpinWheelWidget(
            rewards: kSpinRewards,
            targetIndex: _targetIndex,
            animation: _spinAnimation,
            size: 300,
          ),
        ),
        const SpinWheelPointer(),
      ],
    );
  }

  Widget _buildRewardBanner(SpinReward reward) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(reward.id),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: reward.color.withAlpha(230),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: reward.color.withAlpha(100),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(reward.icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Text(
              'You won ${reward.label}!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpinButton(SpinViewModel vm) {
    final isBusy = vm.state == SpinState.spinning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: FilledButton(
        onPressed: isBusy ? null : () => _onSpinPressed(vm),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.amber.withAlpha(100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: isBusy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.amber),
              )
            : const Text('SPIN!'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper badge widget
// ---------------------------------------------------------------------------

class _SpinBadge extends StatelessWidget {
  const _SpinBadge({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(180), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                sublabel,
                style:
                    TextStyle(color: color.withAlpha(200), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
