# Games – Flutter + Supabase Authentication

A Flutter application demonstrating user authentication (sign-up, login, logout) integrated with [Supabase](https://supabase.com/).

## Features

- **Sign-Up** – Create a new account with email and password.
- **Login** – Sign in to an existing account.
- **Dashboard** – Post-login screen showing the authenticated user's email.
- **Logout** – Sign out and return to the login screen.
- **Error Handling** – User-friendly error messages for common auth scenarios.
- **MVVM Architecture** – Separation of concerns between UI, ViewModel, and Service layers.

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

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run the app

```bash
# Android
flutter run -d android \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# iOS (macOS only)
cd ios && pod install && cd ..
flutter run -d ios \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

---

## Project Structure

```
lib/
├── main.dart                  # App entry point & Supabase initialisation
├── services/
│   └── auth_service.dart      # Wraps Supabase auth API calls
├── viewmodels/
│   └── auth_viewmodel.dart    # MVVM ViewModel (ChangeNotifier)
└── screens/
    ├── login_screen.dart      # Login UI
    ├── signup_screen.dart     # Sign-Up UI
    └── dashboard_screen.dart  # Post-login Dashboard UI

test/
└── auth_viewmodel_test.dart   # Unit tests for AuthViewModel
```

### Architecture

```
UI (Screens)
    │  reads/calls
    ▼
ViewModel (AuthViewModel)    ← ChangeNotifier, provided via Provider
    │  calls
    ▼
Service (AuthService)        ← thin wrapper around SupabaseClient
    │  calls
    ▼
Supabase SDK
```

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
