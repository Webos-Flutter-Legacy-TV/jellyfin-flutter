// Where each item, button and tab goes. Screens not built yet show a placeholder page.
import 'package:flutter/material.dart';

import 'api/models.dart';
import 'screens/details_screen.dart';
import 'screens/library_screen.dart';
import 'session.dart';
import 'ui/header.dart';
import 'ui/tv.dart';

Route<T> tvRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
    );

void openItem(BuildContext context, Session session, Item item) {
  final Widget page;
  switch (item.type) {
    case 'Movie' || 'Episode' || 'Series' || 'Video' || 'MusicVideo':
      page = DetailsScreen(session: session, item: item);
    case 'CollectionFolder' || 'UserView' || 'BoxSet' || 'Folder':
      page = LibraryScreen(session: session, library: item);
    case 'Season':
      page = DetailsScreen(session: session, item: Item({'Id': item.seriesId ?? item.id, 'Type': 'Series', 'Name': item.seriesName ?? item.name}), seasonId: item.id);
    default:
      page = _Placeholder(title: item.name, what: '${item.type.isEmpty ? 'Library' : item.type} page');
  }
  Navigator.of(context).push(tvRoute(page));
}

void openPlayer(BuildContext context, Session session, Item item, {bool fromStart = false}) {
  Navigator.of(context).push(tvRoute(_Placeholder(title: item.name, what: 'Player')));
}

void openMoreMenu(BuildContext context, Session session, Item item) {
  Navigator.of(context).push(tvRoute(_Placeholder(title: item.name, what: 'More menu')));
}

void openTracks(BuildContext context, Session session, Item item) {
  Navigator.of(context).push(tvRoute(_Placeholder(title: item.name, what: 'Audio and subtitles')));
}

void openSearch(BuildContext context, Session session) {
  Navigator.of(context).push(tvRoute(const _Placeholder(title: 'Search', what: 'Search')));
}

void openSettings(BuildContext context, Session session) {
  Navigator.of(context).push(tvRoute(_SettingsStub(session: session)));
}

class _Placeholder extends StatelessWidget {
  final String title, what;
  const _Placeholder({required this.title, required this.what});
  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: false,
        body: Column(children: [
          TopHeader(onBack: () => Navigator.of(context).maybePop(), title: title),
          Expanded(child: StateMessage(title: '$what: next step', detail: 'This screen is built in the next commit.', action: PillButton(label: 'Back', autofocus: true, onPressed: () => Navigator.of(context).maybePop()))),
        ]),
      );
}

/// Until Settings is built: just signing out and changing server.
class _SettingsStub extends StatelessWidget {
  final Session session;
  const _SettingsStub({required this.session});
  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: false,
        body: Column(children: [
          TopHeader(onBack: () => Navigator.of(context).maybePop(), title: 'Settings'),
          Expanded(
            child: StateMessage(
              title: session.current?.userName ?? '',
              detail: session.current?.name,
              action: Row(mainAxisSize: MainAxisSize.min, children: [
                PillButton(label: 'Sign out', autofocus: true, onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  session.signOut();
                }),
                const SizedBox(width: 18),
                PillButton(label: 'Change server', onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  session.leaveServer();
                }),
              ]),
            ),
          ),
        ]),
      );
}
