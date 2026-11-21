import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

final navigatorKey = GlobalKey<NavigatorState>();

/// Back on the PC preview (Escape); on the TV the remote's Back arrives as a route pop.
class BackIntent extends Intent {
  const BackIntent();
}

/// Channel up / down (and Page up / down): jump several rows at once in grids and lists.
class PageIntent extends Intent {
  final TraversalDirection direction;
  const PageIntent(this.direction);
}

class JellyfinTvApp extends StatelessWidget {
  final Session session;
  const JellyfinTvApp({super.key, required this.session});

  // The remote's arrows move focus everywhere (Flutter's web defaults would scroll instead).
  static final _shortcuts = <ShortcutActivator, Intent>{
    ...WidgetsApp.defaultShortcuts,
    const SingleActivator(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
    const SingleActivator(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
    const SingleActivator(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
    const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
    const SingleActivator(LogicalKeyboardKey.channelUp): const PageIntent(TraversalDirection.up),
    const SingleActivator(LogicalKeyboardKey.channelDown): const PageIntent(TraversalDirection.down),
    const SingleActivator(LogicalKeyboardKey.pageUp): const PageIntent(TraversalDirection.up),
    const SingleActivator(LogicalKeyboardKey.pageDown): const PageIntent(TraversalDirection.down),
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      shortcuts: _shortcuts,
      actions: {
        ...WidgetsApp.defaultActions,
        BackIntent: CallbackAction<BackIntent>(onInvoke: (_) => navigatorKey.currentState?.maybePop()),
        PageIntent: CallbackAction<PageIntent>(onInvoke: (i) {
          for (var n = 0; n < 4; n++) {
            final f = FocusManager.instance.primaryFocus;
            if (f == null || !f.focusInDirection(i.direction)) break;
          }
          return null;
        }),
      },
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
