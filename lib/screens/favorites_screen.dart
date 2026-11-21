// Favorites (the official Home's second tab): rows of favourite movies, shows, episodes,
// collections and people.
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../nav.dart';
import '../session.dart';
import '../ui/cards.dart';
import '../ui/header.dart';
import '../ui/tv.dart';

class FavoritesScreen extends StatefulWidget {
  final Session session;
  const FavoritesScreen({super.key, required this.session});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<(String, List<Item>, bool)>? _rows;
  String? _error;

  JellyfinClient get _client => widget.session.client!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      Future<List<Item>> of(String type) async => (await _client.items({
            'recursive': true,
            'filters': 'IsFavorite',
            'includeItemTypes': type,
            'sortBy': 'SortName',
            'fields': 'PrimaryImageAspectRatio',
            'enableImageTypes': 'Primary,Thumb,Backdrop',
            'imageTypeLimit': 1,
            'limit': 60,
          })).items;
      final r = await Future.wait([of('Movie'), of('Series'), of('Episode'), of('BoxSet')]);
      final people = ItemsPage.fromJson(await _client.get('/Persons', {'userId': _client.userId, 'isFavorite': true, 'limit': 60})).items;
      if (!mounted) return;
      setState(() => _rows = [
            ('Movies', r[0], false),
            ('Shows', r[1], false),
            ('Episodes', r[2], true),
            ('Collections', r[3], false),
            ('People', people, false),
          ].where((x) => x.$2.isNotEmpty).toList());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(children: [
        TopHeader(onBack: () => Navigator.of(context).maybePop(), title: 'Favorites', onSearch: () => openSearch(context, widget.session)),
        Expanded(
          child: rows == null
              ? (_error == null ? const StateMessage(title: 'Loading…', loading: true) : StateMessage(title: 'Could not load favourites', detail: _error))
              : rows.isEmpty
                  ? StateMessage(title: 'No favourites yet', detail: 'Press the heart on a movie, show or person to keep it here.', action: PillButton(label: 'Back', autofocus: true, onPressed: () => Navigator.of(context).maybePop()))
                  : FocusTraversalGroup(
                      child: ListView(padding: const EdgeInsets.only(top: 20, bottom: 80), children: [
                        for (final (title, items, landscape) in rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: CardRow(title: title, items: items, client: _client, landscape: landscape, onOpen: (x) => openItem(context, widget.session, x)),
                          ),
                      ]),
                    ),
        ),
      ]),
    );
  }
}
