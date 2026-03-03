import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spin_reward.dart';

/// Data class representing a user's spin session for a single calendar day.
class SpinSession {
  /// ISO-8601 date string (YYYY-MM-DD) for this session.
  final String date;
  final int freeSpinsUsed;
  final int adSpinsEarned;
  final int adSpinsUsed;

  /// UTC timestamp of the last rewarded-ad view, or null if none today.
  final DateTime? lastAdWatchedAt;

  const SpinSession({
    required this.date,
    required this.freeSpinsUsed,
    required this.adSpinsEarned,
    required this.adSpinsUsed,
    this.lastAdWatchedAt,
  });

  factory SpinSession.fresh(String date) => SpinSession(
        date: date,
        freeSpinsUsed: 0,
        adSpinsEarned: 0,
        adSpinsUsed: 0,
      );

  factory SpinSession.fromMap(Map<String, dynamic> map) => SpinSession(
        date: map['spin_date'] as String,
        freeSpinsUsed: (map['free_spins_used'] as int?) ?? 0,
        adSpinsEarned: (map['ad_spins_earned'] as int?) ?? 0,
        adSpinsUsed: (map['ad_spins_used'] as int?) ?? 0,
        lastAdWatchedAt: map['last_ad_watched_at'] != null
            ? DateTime.parse(map['last_ad_watched_at'] as String)
            : null,
      );

  SpinSession copyWith({
    int? freeSpinsUsed,
    int? adSpinsEarned,
    int? adSpinsUsed,
    DateTime? lastAdWatchedAt,
  }) =>
      SpinSession(
        date: date,
        freeSpinsUsed: freeSpinsUsed ?? this.freeSpinsUsed,
        adSpinsEarned: adSpinsEarned ?? this.adSpinsEarned,
        adSpinsUsed: adSpinsUsed ?? this.adSpinsUsed,
        lastAdWatchedAt: lastAdWatchedAt ?? this.lastAdWatchedAt,
      );
}

/// Handles all Supabase interactions for the spin game.
///
/// **Required Supabase tables** – run these SQL statements in the Supabase
/// SQL editor before using this service:
///
/// ```sql
/// -- Tracks daily spin usage per user.
/// create table spin_sessions (
///   id                  uuid primary key default gen_random_uuid(),
///   user_id             uuid references auth.users(id) not null,
///   spin_date           date not null default current_date,
///   free_spins_used     int  not null default 0,
///   ad_spins_earned     int  not null default 0,
///   ad_spins_used       int  not null default 0,
///   last_ad_watched_at  timestamptz,
///   created_at          timestamptz not null default now(),
///   updated_at          timestamptz not null default now(),
///   unique(user_id, spin_date)
/// );
///
/// -- Records each spin result for server-authoritative audit logging.
/// create table spin_results (
///   id           uuid primary key default gen_random_uuid(),
///   user_id      uuid references auth.users(id) not null,
///   reward_id    text not null,
///   reward_label text not null,
///   reward_type  text not null,
///   reward_value int  not null,
///   spun_at      timestamptz not null default now()
/// );
/// ```
class SpinService {
  final SupabaseClient _client;

  SpinService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns (or creates) the [SpinSession] for today's date.
  Future<SpinSession> fetchOrCreateSession() async {
    final today = _todayDate();
    final rows = await _client
        .from('spin_sessions')
        .select()
        .eq('user_id', _userId)
        .eq('spin_date', today)
        .limit(1);

    if ((rows as List).isNotEmpty) {
      return SpinSession.fromMap(rows.first as Map<String, dynamic>);
    }

    // Create a fresh session for today.
    final inserted = await _client
        .from('spin_sessions')
        .insert({
          'user_id': _userId,
          'spin_date': today,
          'free_spins_used': 0,
          'ad_spins_earned': 0,
          'ad_spins_used': 0,
        })
        .select()
        .single();

    return SpinSession.fromMap(inserted);
  }

  /// Persists a spin result and updates the session counters.
  ///
  /// [currentSession] is the latest local session so counters can be
  /// incremented without an extra round-trip.  Pass [isAdSpin] = true when
  /// the spin was earned via a rewarded ad.
  Future<SpinSession> recordSpin({
    required SpinReward reward,
    required SpinSession currentSession,
    required bool isAdSpin,
  }) async {
    final today = _todayDate();

    // Persist the spin result for server-side audit.
    await _client.from('spin_results').insert({
      'user_id': _userId,
      'reward_id': reward.id,
      'reward_label': reward.label,
      'reward_type': reward.type,
      'reward_value': reward.value,
    });

    // Increment the correct counter using the local values to avoid needing
    // a separate read (low contention scenario – single-device gameplay).
    final Map<String, dynamic> update = isAdSpin
        ? {'ad_spins_used': currentSession.adSpinsUsed + 1}
        : {'free_spins_used': currentSession.freeSpinsUsed + 1};

    final updated = await _client
        .from('spin_sessions')
        .update(update)
        .eq('user_id', _userId)
        .eq('spin_date', today)
        .select()
        .single();

    return SpinSession.fromMap(updated);
  }

  /// Marks that the user just watched a rewarded ad and earned an extra spin.
  /// Increments [ad_spins_earned] and records [last_ad_watched_at].
  Future<SpinSession> recordAdWatched(SpinSession currentSession) async {
    final today = _todayDate();
    final now = DateTime.now().toUtc().toIso8601String();

    final updated = await _client
        .from('spin_sessions')
        .update({
          'ad_spins_earned': currentSession.adSpinsEarned + 1,
          'last_ad_watched_at': now,
        })
        .eq('user_id', _userId)
        .eq('spin_date', today)
        .select()
        .single();

    return SpinSession.fromMap(updated);
  }
}
