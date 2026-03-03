import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../viewmodels/auth_viewmodel.dart';
import 'login_screen.dart';

/// Dashboard screen – shown to authenticated users after a successful login.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Retrieve the current user's email from Supabase.
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // Logout button in the top-right corner.
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 72,
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Signed in as:\n$email',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                onPressed: () => _logout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final viewModel = context.read<AuthViewModel>();
    await viewModel.signOut();

    if (!context.mounted) return;

    // Navigate back to Login and clear the back-stack.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}
