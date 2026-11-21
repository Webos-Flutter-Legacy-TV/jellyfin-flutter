// Mockup 3 · Home: a hero for the title to continue (backdrop, logo, progress, Resume), then
// the official app's sections: Continue watching, Next up, Recently added per library, My media.
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../nav.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/cards.dart';
import '../ui/header.dart';
import '../ui/tv.dart';

class HomeScreen extends StatefulWidget {
  final Session session;
  const HomeScreen({super.key, required this.session});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Section {
  final String title;
  final List<Item> items;
  final bool landscape;
  _Section(this.title, this.items, {this.landscape = false});
}

class _HomeScreenState extends State<HomeScreen> {
  List<Item> _views = [];
  List<_Section> _sections = [];
  Item? _hero;
  String? _error;
  bool _loading = true;

  JellyfinClient get _client => widget.session.client!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final views = await _client.userViews();
      final results = await Future.wait([_client.resume(), _client.nextUp()]);
      final resume = results[0], nextUp = results[1];
      final media = views.where((v) => v.collectionType == 'movies' || v.collectionType == 'tvshows').toList();
      final latest = await Future.wait(media.map((v) => _client.latest(v.id).catchError((_) => <Item>[])));
      final sections = <_Section>[
        if (resume.isNotEmpty) _Section('Continue watching', resume, landscape: true),
        if (nextUp.isNotEmpty) _Section('Next up', nextUp, landscape: true),
        for (var i = 0; i < media.length; i++)
          if (latest[i].isNotEmpty) _Section('Recently added in ${media[i].name}', latest[i]),
        if (views.isNotEmpty) _Section('My media', views, landscape: true),
      ];
      Item? hero = resume.isNotEmpty ? resume.first : (latest.isNotEmpty && latest.first.isNotEmpty ? latest.first.first : null);
      if (hero != null) {
        try {
          hero = await _client.item(hero.id); // for badges and the tagline
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _views = views;
        _sections = sections;
        _hero = hero;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await widget.session.signOut();
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _open(Item item) => openItem(context, widget.session, item);

  @override
  Widget build(BuildContext context) {
    final header = TopHeader(
      tabs: [
        HeaderTab('Home', () {}, selected: true),
        for (final v in _views.where((v) => v.collectionType != 'livetv'))
          HeaderTab(v.name, () => _open(v)),
      ],
      onSearch: () => openSearch(context, widget.session),
      onUser: () => openSettings(context, widget.session),
      userInitial: (widget.session.current?.userName ?? '?').characters.first.toUpperCase(),
    );
    if (_loading || _error != null) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: Column(children: [
          header,
          Expanded(
            child: _loading
                ? const StateMessage(title: 'Loading your library…', loading: true)
                : StateMessage(title: 'Could not load Home', detail: _error, action: PillButton(label: 'Try again', autofocus: true, onPressed: _load)),
          ),
        ]),
      );
    }
    return Scaffold(
        resizeToAvoidBottomInset: false,
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            _HeroSection(item: _hero, client: _client, header: header, onPlay: _hero == null ? null : () => openPlayer(context, widget.session, _hero!), onInfo: _hero == null ? null : () => _open(_hero!)),
            for (final s in _sections)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: CardRow(title: s.title, items: s.items, client: _client, landscape: s.landscape, onOpen: _open),
              ),
            if (_sections.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 80), child: StateMessage(title: 'Nothing here yet', detail: 'Your libraries are empty, or this user cannot see any.')),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final Item? item;
  final JellyfinClient client;
  final Widget header;
  final VoidCallback? onPlay, onInfo;
  const _HeroSection({required this.item, required this.client, required this.header, this.onPlay, this.onInfo});

  @override
  Widget build(BuildContext context) {
    final i = item;
    if (i == null) return header;
    final backdrop = client.backdrop(i);
    final logo = client.logo(i);
    final resumable = i.userData.playbackPositionTicks > 0;
    final rt = i.runtime;
    final pct = i.userData.playedPercentage;
    final badges = mediaBadges(i);
    final title = i.isEpisode ? (i.seriesName ?? i.name) : i.name;
    return SizedBox(
      height: 740,
      child: Stack(children: [
        if (backdrop != null) Positioned(left: 560, top: 0, right: 0, height: 740, child: NetImage(backdrop, cacheWidth: 1360)),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Palette.ground, Color(0xBF0B0D12), Color(0x000B0D12)], stops: [0.3, 0.48, 0.75])),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 300,
          child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Palette.ground, Color(0x000B0D12)], stops: [0.1, 1]))),
        ),
        Positioned(left: 0, right: 0, top: 0, child: header),
        Positioned(
          left: Insets.page,
          top: 200,
          width: 900,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(resumable ? 'CONTINUE WATCHING' : (i.isEpisode ? 'NEXT UP' : 'RECENTLY ADDED'), style: tv(21, weight: FontWeight.w700, color: Palette.accentText, spacing: 2.5)),
            const SizedBox(height: 22),
            if (logo != null)
              SizedBox(height: 150, width: 640, child: Align(alignment: Alignment.bottomLeft, child: NetImage(logo, fit: BoxFit.contain, fallbackText: title)))
            else
              Text(title, style: tv(76, weight: FontWeight.w800, spacing: -1.5, height: 1), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 22),
            Wrap(spacing: 18, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (i.isEpisode) Text([if (i.episodeLabel != null) i.episodeLabel!, i.name].join(' · '), style: tv(24, color: const Color(0xC7FFFFFF))),
              if (!i.isEpisode && i.productionYear != null) Text('${i.productionYear}', style: tv(24, color: const Color(0xC7FFFFFF))),
              if (rt != null) Text(formatRuntime(rt), style: tv(24, color: const Color(0xC7FFFFFF))),
              if (i.officialRating != null) Badge2(i.officialRating!, outlined: true),
              if (i.communityRating != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, color: Palette.star, size: 26),
                  const SizedBox(width: 4),
                  Text(i.communityRating!.toStringAsFixed(1), style: tv(24, color: const Color(0xC7FFFFFF))),
                ]),
              for (final b in badges) Badge2(b),
            ]),
            if (i.overview != null) ...[
              const SizedBox(height: 22),
              SizedBox(width: 800, child: Text(i.overview!, style: tv(26, color: Palette.text2, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis)),
            ],
            if (resumable && rt != null && pct != null) ...[
              const SizedBox(height: 22),
              Row(children: [
                Container(
                  width: 360,
                  height: 6,
                  decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(3)),
                  child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: pct / 100, child: Container(decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(3)))),
                ),
                const SizedBox(width: 18),
                Text('${formatRuntime(rt - i.position)} left', style: tv(21, color: Palette.text2)),
              ]),
            ],
            const SizedBox(height: 32),
            Row(children: [
              PillButton(label: resumable ? 'Resume' : 'Play', icon: Icons.play_arrow_rounded, primary: true, autofocus: true, onPressed: onPlay),
              const SizedBox(width: 18),
              PillButton(label: 'More info', onPressed: onInfo),
            ]),
          ]),
        ),
      ]),
    );
  }
}
