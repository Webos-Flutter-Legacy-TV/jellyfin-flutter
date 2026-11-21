// A person (official app: photo, name, favourite, biography, born, birth place, then their
// titles by type), in the app's look: portrait on the left, rows of their movies and shows.
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../nav.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/cards.dart';
import '../ui/tv.dart';

class PersonScreen extends StatefulWidget {
  final Session session;
  final Item person;
  const PersonScreen({super.key, required this.session, required this.person});
  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  Item? _person;
  List<Item> _movies = [], _shows = [];
  String? _error;

  JellyfinClient get _client => widget.session.client!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = Item(await _client.get('/Items/${widget.person.id}', {'userId': _client.userId, 'fields': 'Overview,ProductionLocations'}));
      Future<List<Item>> of(String type) async => (await _client.items({
            'personIds': p.id,
            'recursive': true,
            'includeItemTypes': type,
            'sortBy': 'PremiereDate,ProductionYear,SortName',
            'sortOrder': 'Descending',
            'fields': 'PrimaryImageAspectRatio',
            'limit': 60,
          })).items;
      final r = await Future.wait([of('Movie'), of('Series')]);
      if (!mounted) return;
      setState(() {
        _person = p;
        _movies = r[0];
        _shows = r[1];
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleFavorite() async {
    final p = _person!;
    try {
      await _client.setFavorite(p.id, !p.userData.isFavorite);
      final fresh = Item(await _client.get('/Items/${p.id}', {'userId': _client.userId, 'fields': 'Overview,ProductionLocations'}));
      if (mounted) setState(() => _person = fresh);
    } on ApiException catch (_) {}
  }

  static String _date(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return '';
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _person;
    if (p == null) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: _error == null
            ? const StateMessage(title: 'Loading…', loading: true)
            : StateMessage(title: 'Could not open this person', detail: _error, action: PillButton(label: 'Back', autofocus: true, onPressed: () => Navigator.of(context).maybePop())),
      );
    }
    final born = _date(p.raw['PremiereDate'] as String?);
    final died = _date(p.raw['EndDate'] as String?);
    final place = ((p.raw['ProductionLocations'] as List?) ?? const []).cast<String>().firstOrNull;
    int? age;
    final b = DateTime.tryParse('${p.raw['PremiereDate']}');
    if (b != null && died.isEmpty) {
      final now = DateTime.now();
      age = now.year - b.year - ((now.month < b.month || (now.month == b.month && now.day < b.day)) ? 1 : 0);
    }
    final photo = _client.primary(p, fillWidth: 600, fillHeight: 900);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: FocusTraversalGroup(
        child: ListView(padding: const EdgeInsets.only(bottom: 80), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.page, 28, Insets.page, 0),
            child: Row(children: [
              PillButton(icon: Icons.arrow_back_ios_new, tooltip: 'Back', height: 64, onPressed: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 20),
              PillButton(icon: Icons.home_outlined, tooltip: 'Home', height: 64, onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.page, 30, Insets.page, 20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 360,
                height: 540,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 14))]),
                clipBehavior: Clip.antiAlias,
                child: photo == null ? Container(color: Palette.surfaceRaised, child: const Icon(Icons.person, size: 160, color: Palette.text3)) : NetImage(photo, cacheWidth: 600),
              ),
              const SizedBox(width: 64),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 10),
                  Text(p.name, style: tv(72, weight: FontWeight.w800, spacing: -1.2, height: 1.05)),
                  const SizedBox(height: 18),
                  Wrap(spacing: 22, runSpacing: 8, children: [
                    if (born.isNotEmpty) Text('Born $born${age != null ? ' ($age)' : ''}', style: tv(24, color: const Color(0xD1FFFFFF))),
                    if (died.isNotEmpty) Text('Died $died', style: tv(24, color: const Color(0xD1FFFFFF))),
                    if (place != null) Text(place, style: tv(24, color: Palette.text2)),
                  ]),
                  const SizedBox(height: 26),
                  PillButton(
                    label: p.userData.isFavorite ? 'In favourites' : 'Add to favourites',
                    icon: p.userData.isFavorite ? Icons.favorite : Icons.favorite_border,
                    autofocus: true,
                    height: 70,
                    onPressed: _toggleFavorite,
                  ),
                  if (p.overview != null) ...[
                    const SizedBox(height: 30),
                    SizedBox(width: 1100, child: Text(p.overview!, style: tv(24, color: Palette.text2, height: 1.6), maxLines: 9, overflow: TextOverflow.ellipsis)),
                  ],
                ]),
              ),
            ]),
          ),
          if (_movies.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 20), child: CardRow(title: 'Movies', items: _movies, client: _client, onOpen: (x) => openItem(context, widget.session, x))),
          if (_shows.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 20), child: CardRow(title: 'Shows', items: _shows, client: _client, onOpen: (x) => openItem(context, widget.session, x))),
          if (_movies.isEmpty && _shows.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 30), child: StateMessage(title: 'Nothing with them in your library')),
        ]),
      ),
    );
  }
}
