import 'package:flutter/material.dart';

/// Represents a single reward slot on the spin wheel.
class SpinReward {
  final String id;
  final String label;

  /// Reward category: 'coins' | 'gems' | 'spin' | 'premium'
  final String type;

  /// Numeric value of the reward (e.g. 10 coins, 5 gems, 1 extra spin).
  final int value;

  /// Relative probability weight.  All weights in [kSpinRewards] sum to 100.
  final int weight;

  final Color color;
  final IconData icon;

  const SpinReward({
    required this.id,
    required this.label,
    required this.type,
    required this.value,
    required this.weight,
    required this.color,
    required this.icon,
  });
}

/// The full reward table used by the spin wheel.
///
/// Weights sum to 100, giving each entry a direct percentage probability.
const List<SpinReward> kSpinRewards = [
  SpinReward(
    id: 'coins_10',
    label: '10 Coins',
    type: 'coins',
    value: 10,
    weight: 35,
    color: Color(0xFFFFD700),
    icon: Icons.monetization_on,
  ),
  SpinReward(
    id: 'coins_50',
    label: '50 Coins',
    type: 'coins',
    value: 50,
    weight: 20,
    color: Color(0xFFFFA500),
    icon: Icons.monetization_on,
  ),
  SpinReward(
    id: 'coins_100',
    label: '100 Coins',
    type: 'coins',
    value: 100,
    weight: 15,
    color: Color(0xFFFF8C00),
    icon: Icons.monetization_on,
  ),
  SpinReward(
    id: 'gems_5',
    label: '5 Gems',
    type: 'gems',
    value: 5,
    weight: 12,
    color: Color(0xFF00BCD4),
    icon: Icons.diamond,
  ),
  SpinReward(
    id: 'gems_20',
    label: '20 Gems',
    type: 'gems',
    value: 20,
    weight: 8,
    color: Color(0xFF2196F3),
    icon: Icons.diamond,
  ),
  SpinReward(
    id: 'extra_spin',
    label: 'Extra Spin',
    type: 'spin',
    value: 1,
    weight: 5,
    color: Color(0xFF4CAF50),
    icon: Icons.refresh,
  ),
  SpinReward(
    id: 'premium',
    label: 'Premium Pack',
    type: 'premium',
    value: 1,
    weight: 3,
    color: Color(0xFF9C27B0),
    icon: Icons.card_giftcard,
  ),
  SpinReward(
    id: 'jackpot',
    label: 'Jackpot!',
    type: 'coins',
    value: 500,
    weight: 2,
    color: Color(0xFFE91E63),
    icon: Icons.star,
  ),
];
