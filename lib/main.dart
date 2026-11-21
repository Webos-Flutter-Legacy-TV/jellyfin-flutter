import 'package:flutter/material.dart';

import 'screens/connect_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'session.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await Session.load();
  runApp(JellyfinTvApp(session: session));
}

class JellyfinTvApp extends StatelessWidget {
  final Session session;
  const JellyfinTvApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jellyfin TV',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          // The session decides the first page: no server → Connect, not signed in → Sign in, else Home.
          // A key per state rebuilds the page when it changes.
          final s = session.current;
          if (s == null) return ConnectScreen(key: const ValueKey('connect'), session: session);
          if (!s.signedIn) return LoginScreen(key: ValueKey('login-${s.id}'), session: session);
          return HomeScreen(key: ValueKey('home-${s.id}-${s.userId}'), session: session);
        },
      ),
    );
  }
}
