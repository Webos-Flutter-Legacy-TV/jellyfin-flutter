// Mockup 4 · Library: tabs (All, Favorites, Collections, Genres), Play all / Shuffle, sort and
// filter chips, a 7-column poster grid that loads in pages, and an A–Z rail that jumps.
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../nav.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/cards.dart';
import '../ui/header.dart';
import '../ui/tv.dart';

enum _Tab { all, favorites, collections, genres }

class _Sort {
  final String label, by, order;
  const _Sort(this.label, this.by, this.order);
}

const _sorts = [
  _Sort('Name A–Z', 'SortName', 'Ascending'),
  _Sort('Date added', 'DateCreated,SortName', 'Descending'),
  _Sort('Release date', 'PremiereDate,SortName', 'Descending'),
  _Sort('Rating', 'CommunityRating,SortName', 'Descending'),
  _Sort('Random', 'Random', 'Ascending'),
];

const _filters = [('All', null), ('Unwatched', 'IsUnplayed'), ('Watched', 'IsPlayed'), ('In progress', 'IsResumable')];

class LibraryScreen extends StatefulWidget {
  final Session session;
  final Item library; // a CollectionFolder / UserView (or a BoxSet: its contents)
  const LibraryScreen({super.key, required this.session, required this.library});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const _cols = 7, _page = 70;
  static const _cellW = 210.0, _cellH = 210 * 1.5 + 100;

  _Tab _tab = _Tab.all;
  int _sort = 0, _filter = 0;
  Item? _genre;
  List<Item?> _items = [];
  int _total = 0;
  bool _loading = true;
  String? _error;
  final _pages = <int>{};
  final _scroll = ScrollController();
  int _generation = 0;
  String? _letter;

  JellyfinClient get _client => widget.session.client!;
  bool get _isShows => widget.library.collectionType == 'tvshows';
  bool get _isBoxSet => widget.library.type == 'BoxSet';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Map<String, Object?> get _query {
    final f = _filters[_filter].$2;
    final base = <String, Object?>{
      'parentId': widget.library.id,
      'fields': 'PrimaryImageAspectRatio',
      'enableImageTypes': 'Primary',
      'imageTypeLimit': 1,
    };
    switch (_tab) {
      case _Tab.genres:
        if (_genre == null) {
          return {...base, 'includeItemTypes': _isShows ? 'Series' : 'Movie'};
        }
        return {...base, 'recursive': true, 'includeItemTypes': _isShows ? 'Series' : 'Movie', 'genreIds': _genre!.id, 'sortBy': _sorts[_sort].by, 'sortOrder': _sorts[_sort].order, 'filters': f};
      case _Tab.collections:
        return {...base, 'parentId': null, 'recursive': true, 'includeItemTypes': 'BoxSet', 'sortBy': 'SortName', 'sortOrder': 'Ascending'};
      case _Tab.favorites:
        return {...base, 'recursive': true, 'includeItemTypes': _isShows ? 'Series' : 'Movie', 'filters': 'IsFavorite', 'sortBy': _sorts[_sort].by, 'sortOrder': _sorts[_sort].order};
      case _Tab.all:
        return {
          ...base,
          'recursive': !_isBoxSet,
          if (!_isBoxSet) 'includeItemTypes': _isShows ? 'Series' : (widget.library.collectionType == 'movies' ? 'Movie' : null),
          'sortBy': _sorts[_sort].by,
          'sortOrder': _sorts[_sort].order,
          'filters': f,
        };
    }
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _pages.clear();
      _letter = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    try {
      if (_tab == _Tab.genres && _genre == null) {
        final j = await _client.get('/Genres', {'userId': _client.userId, 'parentId': widget.library.id, 'sortBy': 'SortName', 'includeItemTypes': _isShows ? 'Series' : 'Movie'});
        final page = ItemsPage.fromJson(j);
        if (gen != _generation || !mounted) return;
        setState(() {
          _items = page.items;
          _total = page.items.length;
          _loading = false;
        });
        return;
      }
      final page = await _client.items({..._query, 'startIndex': 0, 'limit': _page, 'enableTotalRecordCount': true});
      if (gen != _generation || !mounted) return;
      setState(() {
        _total = page.total;
        _items = List<Item?>.filled(page.total, null);
        for (var n = 0; n < page.items.length; n++) {
          _items[n] = page.items[n];
        }
        _pages.add(0);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted && gen == _generation) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _ensurePage(int index) {
    final p = index ~/ _page;
    if (_pages.contains(p)) return;
    _pages.add(p);
    final gen = _generation;
    _client.items({..._query, 'startIndex': p * _page, 'limit': _page}).then((page) {
      if (gen != _generation || !mounted) return;
      setState(() {
        for (var n = 0; n < page.items.length && p * _page + n < _items.length; n++) {
          _items[p * _page + n] = page.items[n];
        }
      });
    }).catchError((_) {
      _pages.remove(p); // try again when the cell is built next
    });
  }

  Future<void> _jumpTo(String letter) async {
    setState(() => _letter = letter);
    // Items sorted before this letter = where it starts (the server counts them for us).
    try {
      final before = await _client.items({..._query, 'limit': 0, 'enableTotalRecordCount': true, if (letter != '#') 'nameLessThan': letter, if (letter == '#') 'nameLessThan': 'A'});
      final index = letter == '#' ? 0 : before.total.clamp(0, (_total - 1).clamp(0, _total));
      if (!_scroll.hasClients) return;
      final row = index ~/ _cols;
      _scroll.animateTo((row * (_cellH + 36)).toDouble().clamp(0, _scroll.position.maxScrollExtent), duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      _ensurePage(index);
    } on ApiException catch (_) {}
  }

  void _setTab(_Tab t) {
    if (_tab == t && _genre == null) return;
    _tab = t;
    _genre = null;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, _Tab)>[
      ('All', _Tab.all),
      if (!_isBoxSet) ('Favorites', _Tab.favorites),
      if (!_isBoxSet && !_isShows) ('Collections', _Tab.collections),
      if (!_isBoxSet) ('Genres', _Tab.genres),
    ];
    final showingGenres = _tab == _Tab.genres && _genre == null;
    final sortable = !showingGenres && _tab != _Tab.collections && !_isBoxSet;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(children: [
        TopHeader(
          onBack: () => Navigator.of(context).maybePop(),
          title: _genre?.name ?? widget.library.name,
          tabs: [for (final t in tabs) HeaderTab(t.$1, () => _setTab(t.$2), selected: _tab == t.$2)],
          onSearch: () => openSearch(context, widget.session),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.page, 14, Insets.page + 84, 20),
          child: FocusTraversalGroup(
            child: Row(children: [
              Text(_loading ? 'Loading…' : '$_total ${showingGenres ? 'genres' : 'titles'}', style: tv(23, color: Palette.text3)),
              const SizedBox(width: 24),
              if (!showingGenres && _total > 0) ...[
                PillButton(label: 'Play all', icon: Icons.play_arrow_rounded, height: 56, onPressed: () => _items.firstOrNull == null ? null : openPlayer(context, widget.session, _items.first!)),
                const SizedBox(width: 14),
                PillButton(label: 'Shuffle', icon: Icons.shuffle, height: 56, onPressed: () {}),
              ],
              const Spacer(),
              if (sortable) ...[
                PillButton(label: 'Sort: ${_sorts[_sort].label}', height: 56, onPressed: () {
                  _sort = (_sort + 1) % _sorts.length;
                  _reload();
                }),
                if (_tab != _Tab.favorites) ...[
                  const SizedBox(width: 14),
                  PillButton(label: 'Filter: ${_filters[_filter].$1}', height: 56, onPressed: () {
                    _filter = (_filter + 1) % _filters.length;
                    _reload();
                  }),
                ],
              ],
            ]),
          ),
        ),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _body(showingGenres)),
            if (sortable && _sorts[_sort].by == 'SortName' && _total > 30) _letterRail(),
          ]),
        ),
      ]),
    );
  }

  Widget _body(bool showingGenres) {
    if (_loading) return const StateMessage(title: 'Loading…', loading: true);
    if (_error != null) return StateMessage(title: 'Could not load this library', detail: _error, action: PillButton(label: 'Try again', autofocus: true, onPressed: _reload));
    if (_total == 0) {
      return StateMessage(
        title: _tab == _Tab.favorites ? 'No favourites yet' : 'Nothing here',
        detail: _tab == _Tab.favorites ? 'Press the heart on a title to add it.' : (_filter != 0 ? 'Nothing matches "${_filters[_filter].$1}".' : null),
      );
    }
    if (showingGenres) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(Insets.page, 10, Insets.page, 60),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 22, crossAxisSpacing: 22, mainAxisExtent: 110),
        itemCount: _items.length,
        itemBuilder: (context, n) {
          final g = _items[n]!;
          return TvFocusable(
            autofocus: n == 0,
            onPressed: () {
              _genre = g;
              _reload();
            },
            builder: (context, focused) => AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: focused ? Palette.surfaceRaised : Palette.surface, borderRadius: BorderRadius.circular(18), boxShadow: focused ? focusShadow(ring: 3) : null),
              child: Text(g.name, style: tv(26, weight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2),
            ),
          );
        },
      );
    }
    // Clipped so scrolled posters stay under the toolbar; the padding leaves room for the
    // focused card's ring and lift.
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(Insets.page, 24, Insets.page, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _cols, mainAxisSpacing: 36, crossAxisSpacing: 28, mainAxisExtent: _cellH),
      itemCount: _items.length,
      itemBuilder: (context, n) {
        final it = _items[n];
        if (it == null) {
          _ensurePage(n);
          return Container(margin: const EdgeInsets.only(bottom: 100), decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(14)));
        }
        return MediaCard(item: it, client: _client, width: _cellW, autofocus: n == 0, onPressed: () => openItem(context, widget.session, it));
      },
    );
  }

  Widget _letterRail() {
    const letters = '#ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return Container(
      width: 64,
      margin: const EdgeInsets.only(right: 40, top: 14),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(999)),
      child: FocusTraversalGroup(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final l in letters.split(''))
            TvFocusable(
              ensureVisible: false,
              onPressed: () => _jumpTo(l),
              builder: (context, focused) => Container(
                width: 44,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: focused ? Colors.white : (_letter == l ? Palette.accent : null),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(l, style: tv(19, weight: FontWeight.w600, color: focused ? Palette.ground : (_letter == l ? Palette.onAccent : Palette.text3))),
              ),
            ),
        ]),
      ),
    );
  }
}
