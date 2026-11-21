// Mockup 10 · Search: our own keyboard on the left (the TV's keyboard would cover the
// results), results grouped by type on the right, recent searches remembered.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../nav.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/cards.dart';
import '../ui/tv.dart';

class SearchScreen extends StatefulWidget {
  final Session session;
  const SearchScreen({super.key, required this.session});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _Group {
  final String title;
  final List<Item> items;
  final bool landscape;
  _Group(this.title, this.items, {this.landscape = false});
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';
  List<_Group> _groups = [];
  bool _searching = false;
  Timer? _debounce;
  int _generation = 0;

  JellyfinClient get _client => widget.session.client!;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _set(String q) {
    setState(() => _query = q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _search);
  }

  Future<void> _search() async {
    final q = _query.trim();
    final gen = ++_generation;
    if (q.length < 2) {
      setState(() {
        _groups = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      Future<List<Item>> of(String types) async =>
          (await _client.items({'searchTerm': q, 'recursive': true, 'includeItemTypes': types, 'limit': 24, 'fields': 'PrimaryImageAspectRatio', 'enableImageTypes': 'Primary,Thumb,Backdrop', 'imageTypeLimit': 1})).items;
      final res = await Future.wait([of('Movie'), of('Series'), of('Episode'), of('BoxSet')]);
      final people = ItemsPage.fromJson(await _client.get('/Persons', {'searchTerm': q, 'limit': 20, 'userId': _client.userId})).items;
      if (gen != _generation || !mounted) return;
      setState(() {
        _groups = [
          if (res[0].isNotEmpty) _Group('Movies', res[0]),
          if (res[1].isNotEmpty) _Group('Shows', res[1]),
          if (res[2].isNotEmpty) _Group('Episodes', res[2], landscape: true),
          if (res[3].isNotEmpty) _Group('Collections', res[3]),
          if (people.isNotEmpty) _Group('People', people),
        ];
        _searching = false;
      });
    } on ApiException catch (_) {
      if (mounted && gen == _generation) setState(() => _searching = false);
    }
  }

  void _open(Item item) {
    widget.session.addRecentSearch(_query);
    openItem(context, widget.session, item);
  }

  // A real keyboard (PC preview, USB keyboard on the TV) types straight in.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      if (_query.isNotEmpty) _set(_query.substring(0, _query.length - 1));
      return KeyEventResult.handled;
    }
    final ch = e.character;
    if (ch != null && ch.length == 1 && RegExp(r"[\w\s'\-:.&]").hasMatch(ch) && ch != '\n') {
      _set(_query + ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Focus(
        onKeyEvent: _onKey,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 620,
            padding: const EdgeInsets.fromLTRB(56, 56, 56, 40),
            decoration: const BoxDecoration(color: Color(0xFF12151D), border: Border(right: BorderSide(color: Color(0x0FFFFFFF)))),
            child: FocusTraversalGroup(child: _keyboardPanel()),
          ),
          Expanded(child: FocusTraversalGroup(child: _results())),
        ]),
      ),
    );
  }

  Widget _keyboardPanel() {
    const keys = 'abcdefghijklmnopqrstuvwxyz1234567890';
    final recent = widget.session.recentSearches;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        PillButton(icon: Icons.arrow_back_ios_new, tooltip: 'Back', height: 60, onPressed: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 16),
        Text('Search', style: tv(40, weight: FontWeight.w700)),
      ]),
      const SizedBox(height: 26),
      Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(color: Palette.ground, borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.fieldBorder, width: 2)),
        child: Row(children: [
          const Icon(Icons.search, color: Palette.text3, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Text(_query.isEmpty ? 'Titles, people, genres' : _query, style: tv(32, weight: _query.isEmpty ? FontWeight.w400 : FontWeight.w600, color: _query.isEmpty ? Palette.text3 : Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (_searching) const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Palette.accent)),
        ]),
      ),
      const SizedBox(height: 26),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 6,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 80 / 70,
        children: [
          for (var n = 0; n < keys.length; n++) _key(keys[n], () => _set(_query + keys[n]), autofocus: n == 0),
        ],
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _key('Space', () => _set('$_query '))),
        const SizedBox(width: 10),
        Expanded(child: _key('Delete', () => _query.isEmpty ? null : _set(_query.substring(0, _query.length - 1)))),
        const SizedBox(width: 10),
        Expanded(child: _key('Clear', () => _set(''))),
      ]),
      const SizedBox(height: 24),
      if (recent.isNotEmpty) ...[
        Text('Recent', style: tv(20, color: Palette.text3)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final r in recent)
            TvFocusable(
              ensureVisible: false,
              onPressed: () => _set(r),
              builder: (context, focused) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(color: focused ? Colors.white : Palette.surfaceRaised, borderRadius: BorderRadius.circular(999)),
                child: Text(r, style: tv(20, weight: FontWeight.w600, color: focused ? Palette.ground : Colors.white)),
              ),
            ),
        ]),
      ],
    ]);
  }

  Widget _key(String label, VoidCallback onPressed, {bool autofocus = false}) => TvFocusable(
        autofocus: autofocus,
        ensureVisible: false,
        onPressed: onPressed,
        builder: (context, focused) => AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: label.length > 1 ? 64 : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: focused ? Colors.white : Palette.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            boxShadow: focused ? [const BoxShadow(color: Palette.focusGlow, spreadRadius: 5)] : null,
          ),
          child: Text(label, style: tv(label.length > 1 ? 22 : 27, weight: FontWeight.w600, color: focused ? Palette.ground : Colors.white)),
        ),
      );

  Widget _results() {
    if (_query.trim().length < 2) {
      return const StateMessage(title: 'Find a movie, show or person', detail: 'Type at least two letters. A keyboard plugged into the TV works too.');
    }
    if (_groups.isEmpty && !_searching) return StateMessage(title: 'Nothing found', detail: 'No titles or people match "${_query.trim()}".');
    return ListView(
      padding: const EdgeInsets.only(top: 60, bottom: 60),
      children: [
        for (final g in _groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: g.title == 'People' ? _peopleRow(g.items) : CardRow(title: g.title, items: g.items, client: _client, landscape: g.landscape, onOpen: _open),
          ),
      ],
    );
  }

  Widget _peopleRow(List<Item> people) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: Insets.page), child: Text('People', style: tv(34, weight: FontWeight.w600))),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: Insets.page, vertical: 12),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: 30),
            itemBuilder: (context, n) {
              final p = people[n];
              final img = _client.primary(p, fillWidth: 168, fillHeight: 168);
              return TvFocusable(
                onPressed: () => _open(p),
                builder: (context, focused) => Row(children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.surfaceRaised, boxShadow: focused ? focusShadow(ring: 3) : null),
                    child: img == null ? const Icon(Icons.person, color: Palette.text3, size: 44) : ClipOval(child: NetImage(img, cacheWidth: 168)),
                  ),
                  const SizedBox(width: 14),
                  Text(p.name, style: tv(22, weight: FontWeight.w600)),
                ]),
              );
            },
          ),
        ),
      ]);
}
