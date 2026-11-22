// Where each item, button and tab goes. Screens not built yet show a placeholder page.
import 'package:flutter/material.dart';

import 'api/models.dart';
import 'screens/details_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/library_screen.dart';
import 'screens/person_screen.dart';
import 'screens/player_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
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
    case 'CollectionFolder' || 'UserView' || 'BoxSet' || 'Folder' || 'Playlist' || 'ManualPlaylistsFolder' || 'PlaylistsFolder':
      page = LibraryScreen(session: session, library: item);
    case 'Person':
      page = PersonScreen(session: session, person: item);
    case 'Season':
      page = DetailsScreen(session: session, item: Item({'Id': item.seriesId ?? item.id, 'Type': 'Series', 'Name': item.seriesName ?? item.name}), seasonId: item.id);
    default:
      page = _Placeholder(title: item.name, what: '${item.type.isEmpty ? 'Library' : item.type} page');
  }
  Navigator.of(context).push(tvRoute(page));
}

const _playableTypes = {'Movie', 'Episode', 'Video', 'MusicVideo', 'Trailer', 'Recording', 'TvProgram'};

/// Plays an item; a series, season, collection, playlist or library plays its videos in order
/// (from the episode to watch next for a series) or shuffled.
Future<void> openPlayer(BuildContext context, Session session, Item item, {bool fromStart = false, bool shuffle = false}) async {
  final nav = Navigator.of(context);
  if (_playableTypes.contains(item.type) && !shuffle) {
    nav.push(tvRoute(PlayerScreen(session: session, item: item, fromStart: fromStart)));
    return;
  }
  final client = session.client!;
  List<Item> items;
  try {
    if (item.type == 'Series' || item.type == 'Season') {
      final seriesId = item.type == 'Series' ? item.id : (item.seriesId ?? item.id);
      items = await client.episodes(seriesId, seasonId: item.type == 'Season' ? item.id : null);
      if (!shuffle) {
        // Start at the episode to watch next, as the official Play does.
        final next = (await client.nextUp(seriesId: seriesId, limit: 1, resumable: true)).firstOrNull;
        final at = next == null ? -1 : items.indexWhere((e) => e.id == next.id);
        if (at > 0) items = items.sublist(at);
      }
    } else if (item.type == 'Playlist') {
      items = ItemsPage.fromJson(await client.get('/Playlists/${item.id}/Items', {'userId': client.userId, 'limit': 500})).items;
    } else {
      final page = await client.items({
        'parentId': item.id,
        'recursive': true,
        'mediaTypes': 'Video',
        'includeItemTypes': item.collectionType == 'tvshows' ? 'Episode' : (item.collectionType == 'movies' ? 'Movie' : null),
        'sortBy': shuffle ? 'Random' : (item.type == 'Playlist' ? null : 'SortName'),
        'limit': 300,
      });
      items = page.items;
    }
  } catch (_) {
    items = const [];
  }
  if (shuffle) items = [...items]..shuffle();
  if (items.isEmpty) return;
  nav.push(tvRoute(PlayerScreen(session: session, item: items.first, fromStart: shuffle || fromStart, queue: items.sublist(1))));
}


void openSearch(BuildContext context, Session session) {
  Navigator.of(context).push(tvRoute(SearchScreen(session: session)));
}

void openSettings(BuildContext context, Session session) {
  Navigator.of(context).push(tvRoute(SettingsScreen(session: session)));
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

void openFavorites(BuildContext context, Session session) {
  Navigator.of(context).push(tvRoute(FavoritesScreen(session: session)));
}
