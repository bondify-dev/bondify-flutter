// example/lib/main.dart
// Minimal example app for the Bondify Flutter SDK.
//
// 1) Replace 'proj_xxxxxxxx' with your real Project ID from the dashboard.
// 2) Enable "Mobile SDK" in your project settings (Configure → Mobile SDK).
// 3) Run: flutter run

import 'package:flutter/material.dart';
import 'package:bondify_flutter/bondify_flutter.dart';

const kProjectId = 'proj_xxxxxxxx'; // ← your Project ID

void main() {
  // Optional: configure once so widgets can omit projectId.
  BondifyClient.init(const BondifyConfig(projectId: kProjectId));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bondify Example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF229ED9)),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BondifyUser? _user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bondify Example')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _user == null ? _signedOut() : _signedIn(_user!),
        ),
      ),
    );
  }

  Widget _signedOut() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Welcome', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Sign in with Telegram to continue',
            style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 28),

        // Inline button
        BondifyButton(
          // projectId omitted → uses BondifyClient.instance
          onSuccess: (user) => setState(() => _user = user),
          onError: (e) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e'))),
        ),

        const SizedBox(height: 20),

        // Or use the bottom sheet
        TextButton(
          onPressed: () async {
            final user = await showBondifyAuthSheet(context, projectId: kProjectId);
            if (user != null) setState(() => _user = user);
          },
          child: const Text('Or open the login sheet'),
        ),
      ],
    );
  }

  Widget _signedIn(BondifyUser user) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 56),
        const SizedBox(height: 16),
        Text('Hello, ${user.name}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        if (user.username != null)
          Text('@${user.username}', style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 8),
        Text('Telegram ID: ${user.telegramId}',
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Now send user.proof to your backend and verify it there before '
            'creating a session.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => setState(() => _user = null),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
