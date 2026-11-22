import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/remote.dart';
import 'dev_autoplay.dart';
import 'nav.dart';
import 'perf_probe.dart';
import 'screens/player_screen.dart';

import 'screens/connect_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/users_screen.dart';
import 'screensaver.dart';
import 'session.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  startPerfProbe();
  final session = await Session.load();
  remoteControl = RemoteControl(session);
  _listenToRemote(session, remoteControl!);
  runApp(JellyfinTvApp(session: session));
  _devAutoplay(session);
}

Future<void> _devAutoplay(Session session) async {
  final req = await readDevAutoplay();
  if (req == null || session.current?.signedIn != true) return;
  await Future<void>.delayed(const Duration(seconds: 3));
  final nav = navigatorKey.currentState;
  final client = session.client;
  if (nav == null || client == null) return;
  if (req.$3) await session.setBool('nativePlayer', true);
  try {
    final item = await client.item(req.$1);
    nav.push(tvRoute(PlayerScreen(session: session, item: item, startAt: Duration(milliseconds: req.$2))));
  } catch (_) {}
}

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// What another device asks of this TV: play something, show a message, go home, open an item.
void _listenToRemote(Session session, RemoteControl remote) {
  remote.playRequests.listen((req) {
    final nav = navigatorKey.currentState;
    if (nav == null || session.current?.signedIn != true) return;
    nav.push(tvRoute(PlayerScreen(session: session, item: req.items.first, startAt: req.start, queue: req.items.sublist(1))));
  });
  remote.messages.listen((m) {
    messengerKey.currentState?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      width: 900,
      duration: const Duration(seconds: 8),
      backgroundColor: Palette.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(m.$1, style: tv(26, weight: FontWeight.w700)),
        if (m.$2.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(m.$2, style: tv(22, color: Palette.text2))),
      ]),
    ));
  });
  remote.goHome.listen((_) => navigatorKey.currentState?.popUntil((r) => r.isFirst));
  remote.openItem.listen((id) async {
    final ctx = navigatorKey.currentContext;
    final client = session.client;
    if (ctx == null || client == null) return;
    try {
      final item = await client.item(id);
      final c = navigatorKey.currentContext;
      if (c != null && c.mounted) openItem(c, session, item);
    } catch (_) {}
  });
}


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
      scaffoldMessengerKey: messengerKey,
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
      builder: (context, child) => Screensaver(session: session, child: child!),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          // The session decides the first page: no server → Connect, not signed in → Sign in, else Home.
          // A key per state rebuilds the page when it changes.
          final s = session.current;
          if (s == null) return ConnectScreen(key: const ValueKey('connect'), session: session);
          if (session.addingUser || s.accounts.isEmpty) return LoginScreen(key: ValueKey('login-${s.id}-${session.addingUser}'), session: session);
          if (session.choosingUser || !s.signedIn) return UsersScreen(key: ValueKey('users-${s.id}'), session: session);
          return HomeScreen(key: ValueKey('home-${s.id}-${s.userId}'), session: session);
        },
      ),
    );
  }
}
