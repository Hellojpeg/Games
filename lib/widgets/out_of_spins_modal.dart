import 'package:flutter/material.dart';

import '../viewmodels/spin_viewmodel.dart';

/// Bottom-sheet modal presented when the user has no remaining spins.
///
/// Offers three actions:
/// - **Watch Ad** – earn one extra spin by watching a rewarded ad.
/// - **Buy Spins** – placeholder for in-app purchase flow.
/// - **Wait** – dismiss and wait for the daily reset.
class OutOfSpinsModal extends StatefulWidget {
  const OutOfSpinsModal({super.key, required this.viewModel});

  final SpinViewModel viewModel;

  /// Convenience method that shows the modal as a bottom sheet.
  static Future<void> show(
    BuildContext context,
    SpinViewModel viewModel,
  ) {
    return showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => OutOfSpinsModal(viewModel: viewModel),
    );
  }

  @override
  State<OutOfSpinsModal> createState() => _OutOfSpinsModalState();
}

class _OutOfSpinsModalState extends State<OutOfSpinsModal> {
  bool _loadingAd = false;
  String? _message;

  SpinViewModel get vm => widget.viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canWatchAd = vm.canEarnMoreAdSpins && vm.isAdCooldownOver;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar.
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon.
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.errorContainer,
            child: Icon(
              Icons.hourglass_empty_rounded,
              size: 36,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 16),

          // Title.
          Text(
            'Out of Spins!',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Subtitle.
          Text(
            vm.canEarnMoreAdSpins
                ? 'Watch a short ad to earn an extra spin, or come back tomorrow for your free spins.'
                : 'You\'ve used all your spins for today. Come back tomorrow!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),

          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Watch Ad button.
          FilledButton.icon(
            icon: _loadingAd
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text(
              canWatchAd ? 'Watch Ad (+1 Spin)' : 'Ad limit reached today',
            ),
            onPressed:
                (canWatchAd && !_loadingAd) ? _onWatchAd : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),

          // Buy Spins button.
          OutlinedButton.icon(
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('Buy Spins'),
            onPressed: _onBuySpins,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),

          // Wait / dismiss button.
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Wait for Daily Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _onWatchAd() async {
    setState(() {
      _loadingAd = true;
      _message = null;
    });

    final earned = await vm.watchAdForSpin();

    if (!mounted) return;

    if (earned) {
      Navigator.of(context).pop(); // Close modal – user can now spin.
    } else {
      setState(() {
        _loadingAd = false;
        _message = 'Ad not available right now. Please try again later.';
      });
    }
  }

  void _onBuySpins() {
    // TODO: Integrate with your in-app purchase provider.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('In-app purchases coming soon!')),
    );
  }
}
