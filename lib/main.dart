import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseKey);
  runApp(const LendlyApp());
}

class LendlyApp extends StatelessWidget {
  const LendlyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lendly',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, _) {
        final session = supabase.auth.currentSession;
        if (session == null) return const AuthScreen();
        return HomeShell(key: ValueKey(session.user.id));
      },
    );
  }
}
