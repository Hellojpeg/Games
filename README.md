# Games – Flutter + Supabase Authentication & Spin Game

A Flutter application with Supabase authentication and a spin-wheel mini-game featuring rewarded ads and daily spin limits.

## Features

- **Sign-Up** – Create a new account with email and password.
- **Login** – Sign in to an existing account.
- **Dashboard** – Post-login screen showing the authenticated user's email and a link to the spin game.
- **Logout** – Sign out and return to the login screen.
- **Error Handling** – User-friendly error messages for common auth scenarios.
- **MVVM Architecture** – Separation of concerns between UI, ViewModel, and Service layers.
- **Spin Game** – Animated spin wheel with weighted rewards, daily free spins, rewarded ads for bonus spins, and Supabase-backed result logging.

---

## Prerequisites

| Tool | Version |
|---|---|
| Flutter | ≥ 3.10 |
| Dart | ≥ 3.0 |
| Xcode (iOS) | ≥ 14 |
| Android Studio / SDK | API 21+ |

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/Hellojpeg/Games.git
cd Games
```

### 2. Configure Supabase

1. Create a free project at <https://app.supabase.com>.
2. Go to **Project Settings → API** and copy:
   - **Project URL** (e.g. `https://xyzcompany.supabase.co`)
   - **anon / public** key

The app reads these values from Dart compile-time environment variables (`SUPABASE_URL` and `SUPABASE_ANON_KEY`). Pass them when running or building:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

> **Never hard-code secrets in source code.** Use `--dart-define` or a secrets manager.

#### Spin Game – Supabase Tables

Run the following SQL in the **Supabase SQL editor** to create the tables required by the spin game:

```sql
-- Tracks daily spin usage per user.
create table spin_sessions (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid references auth.users(id) not null,
  spin_date           date not null default current_date,
  free_spins_used     int  not null default 0,
  ad_spins_earned     int  not null default 0,
  ad_spins_used       int  not null default 0,
  last_ad_watched_at  timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique(user_id, spin_date)
);

-- Records each spin result for server-authoritative audit logging.
create table spin_results (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users(id) not null,
  reward_id    text not null,
  reward_label text not null,
  reward_type  text not null,
  reward_value int  not null,
  spun_at      timestamptz not null default now()
);
```

Enable Row-Level Security (RLS) and add policies so users can only read/write their own rows:

```sql
alter table spin_sessions enable row level security;
alter table spin_results  enable row level security;

create policy "Users manage own sessions"
  on spin_sessions for all using (auth.uid() = user_id);

create policy "Users manage own results"
  on spin_results for all using (auth.uid() = user_id);
```

### 3. Configure Google Mobile Ads (AdMob)

The app uses `google_mobile_ads` for rewarded ads.

1. Create an AdMob account at <https://admob.google.com>.
2. Create an app and a **Rewarded** ad unit for Android and iOS.
3. Pass the IDs via `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=REWARDED_AD_UNIT_ANDROID=ca-app-pub-XXXXX/YYYYY \
  --dart-define=REWARDED_AD_UNIT_IOS=ca-app-pub-XXXXX/ZZZZZ
```

4. Replace the placeholder **App IDs** in the native config files with your real AdMob App IDs:
   - **Android**: `android/app/src/main/AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID`
   - **iOS**: `ios/Runner/Info.plist` → `GADApplicationIdentifier`

> The default values in those files are Google's official **test** App IDs, which are safe for development but must be replaced before publishing.

### 4. Install dependencies

```bash
flutter pub get

# iOS only – install CocoaPods dependencies
cd ios && pod install && cd ..
```

### 5. Run the app

```bash
# Android
flutter run -d android \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# iOS (macOS only)
flutter run -d ios \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

---

## Project Structure

```
lib/
├── main.dart                      # App entry point, Supabase + Ads initialisation
├── models/
│   └── spin_reward.dart           # Reward data model & weighted reward table
├── services/
│   ├── auth_service.dart          # Wraps Supabase auth API calls
│   ├── spin_service.dart          # Supabase spin session & result storage
│   └── ad_service.dart            # Rewarded-ads abstraction (Google Mobile Ads)
├── viewmodels/
│   ├── auth_viewmodel.dart        # Auth MVVM ViewModel
│   └── spin_viewmodel.dart        # Spin game ViewModel (game logic, daily reset)
├── screens/
│   ├── login_screen.dart          # Login UI
│   ├── signup_screen.dart         # Sign-Up UI
│   ├── dashboard_screen.dart      # Post-login Dashboard UI
│   └── spin_screen.dart           # Animated spin wheel screen
└── widgets/
    ├── spin_wheel_widget.dart      # Custom-painted spin wheel + pointer
    └── out_of_spins_modal.dart    # "Out of Spins" bottom-sheet modal

test/
├── auth_viewmodel_test.dart        # Unit tests for AuthViewModel
├── auth_viewmodel_test.mocks.dart  # Generated mocks
├── spin_viewmodel_test.dart        # Unit tests for SpinViewModel
└── spin_viewmodel_test.mocks.dart  # Generated mocks
```

### Architecture

```
UI (Screens / Widgets)
    │  reads/calls
    ▼
ViewModel (AuthViewModel / SpinViewModel)   ← ChangeNotifier via Provider
    │  calls
    ▼
Services (AuthService / SpinService / AdService)
    │  calls
    ▼
Supabase SDK  /  Google Mobile Ads SDK
```

---

## Spin Game

### Reward Table

| Reward | Type | Weight (%) |
|---|---|---|
| 10 Coins | coins | 35 |
| 50 Coins | coins | 20 |
| 100 Coins | coins | 15 |
| 5 Gems | gems | 12 |
| 20 Gems | gems | 8 |
| Extra Spin | spin | 5 |
| Premium Pack | premium | 3 |
| Jackpot (500 Coins) | coins | 2 |

### Daily Rules

| Rule | Value |
|---|---|
| Free spins per day | 5 |
| Bonus spins per day (via ads) | 3 |
| Ad cooldown | 5 minutes |
| Spin animation duration | 2.5 – 4 seconds |

---

## Running Tests

```bash
# Generate Mockito mocks first
flutter pub run build_runner build --delete-conflicting-outputs

# Run tests
flutter test
```

---

## Deep-link / Redirect URL (Email Confirmation)

If your Supabase project requires email confirmation, add the following redirect URL in **Authentication → URL Configuration** in the Supabase dashboard:

```
io.supabase.games://login-callback
```

This matches the custom URL scheme already registered in:
- **Android**: `android/app/src/main/AndroidManifest.xml`
- **iOS**: `ios/Runner/Info.plist`
