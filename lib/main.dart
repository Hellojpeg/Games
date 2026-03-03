import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'viewmodels/auth_viewmodel.dart';

/// Entry point of the application.
/// Initialises Supabase before running the Flutter widget tree.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Google Mobile Ads SDK.
  await MobileAds.instance.initialize();

  // Initialise Supabase with your project URL and anon key.
  // Replace the placeholder values with your actual Supabase credentials.
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://your-project.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'your-anon-key',
    ),
  );

  runApp(
    // Provide AuthViewModel to the whole widget tree via Provider.
    ChangeNotifierProvider(
      create: (_) => AuthViewModel(),
      child: const GamesApp(),
    ),
  );
}

/// Root widget that determines which screen to show based on auth state.
class GamesApp extends StatelessWidget {
  const GamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Games',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Use an AuthGate to route the user to Login or Dashboard.
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Listens to Supabase auth state changes and routes accordingly.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    // Show Dashboard when the user is already signed in, else show Login.
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? const DashboardScreen() : const LoginScreen();
  }
}
