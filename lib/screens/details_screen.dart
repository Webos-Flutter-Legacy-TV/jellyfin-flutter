// Mockups 5 and 6 · Details: the item on its backdrop (logo, meta, badges, tagline, overview,
// actions, tracks), then cast and "More like this". A series shows season tabs and a row of
// episode cards instead of tracks; the focused episode's summary sits under the row.
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../nav.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/cards.dart';
import 'panels.dart';
import '../ui/tv.dart';

class DetailsScreen extends StatefulWidget {
  final Session session;
  final Item item;
  final String? seasonId; // open a series on this season
  const DetailsScreen({super.key, required this.session, required this.item, this.seasonId});
  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  Item? _item;
  List<Item> _similar = [];
  // Series
  List<Item> _seasons = [];
  String? _seasonId;
  List<Item> _episodes = [];
  Item? _nextUp;
  Item? _focusedEpisode;
  String? _error;

  JellyfinClient get _client => widget.session.client!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final item = await _client.item(widget.item.id);
      final similar = await _client.similar(item.id).catchError((_) => <Item>[]);
      if (item.isSeries) {
        final seasons = await _client.seasons(item.id);
        final next = (await _client.nextUp(seriesId: item.id, limit: 1, resumable: true).catchError((_) => <Item>[])).firstOrNull;
        _seasons = seasons;
        _nextUp = next;
        _seasonId = widget.seasonId ?? next?.seasonId ?? seasons.where((s) => !s.userData.played).firstOrNull?.id ?? seasons.firstOrNull?.id;
        if (_seasonId != null) _episodes = await _client.episodes(item.id, seasonId: _seasonId);
      }
      if (!mounted) return;
      setState(() {
        _item = item;
        _similar = similar;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pickSeason(String id) async {
    if (id == _seasonId) return;
    setState(() {
      _seasonId = id;
      _episodes = [];
      _focusedEpisode = null;
    });
    final eps = await _client.episodes(_item!.id, seasonId: id).catchError((_) => <Item>[]);
    if (mounted && _seasonId == id) setState(() => _episodes = eps);
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _client.item(widget.item.id);
      if (mounted) setState(() => _item = fresh);
    } on ApiException catch (_) {}
  }

  Future<void> _tracks(Item i, int tab) async {
    await showTracksPanel(context, widget.session, i, startTab: tab);
    if (mounted) setState(() {});
  }

  Future<void> _toggle({required bool played}) async {
    final i = _item!;
    final ud = i.userData;
    try {
      if (played) {
        await _client.setPlayed(i.id, !ud.played);
      } else {
        await _client.setFavorite(i.id, !ud.isFavorite);
      }
      final fresh = await _client.item(i.id);
      if (mounted) setState(() => _item = fresh);
    } on ApiException catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final i = _item;
    if (i == null) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: _error == null
            ? const StateMessage(title: 'Loading…', loading: true)
            : StateMessage(title: 'Could not open this', detail: _error, action: PillButton(label: 'Back', autofocus: true, onPressed: () => Navigator.of(context).maybePop())),
      );
    }
    final backdrop = _client.backdrop(i);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
        if (backdrop != null) Positioned(left: 0, top: 0, right: 0, height: i.isSeries ? 760 : 1080, child: NetImage(backdrop, cacheWidth: 1920)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: const [Color(0xF70B0D12), Color(0xE00B0D12), Color(0x590B0D12), Color(0x260B0D12)], stops: i.isSeries ? const [0, 0.45, 0.8, 1] : const [0, 0.42, 0.75, 1]),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: i.isSeries ? 420 : 640,
          height: i.isSeries ? 340 : 440,
          child: const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Palette.ground, Color(0x000B0D12)], stops: [0.2, 1]))),
        ),
        if (i.isSeries) const Positioned(left: 0, right: 0, top: 760, bottom: 0, child: ColoredBox(color: Palette.ground)),
        FocusTraversalGroup(
          child: ListView(padding: EdgeInsets.zero, children: [
            if (i.isSeries) _seriesTop(i) else _movieTop(i),
            if (i.people.isNotEmpty) _castRow(i),
            if (_similar.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 30, bottom: 80),
                child: CardRow(title: 'More like this', items: _similar, client: _client, onOpen: (x) => openItem(context, widget.session, x)),
              ),
          ]),
        ),
      ]),
    );
  }

  // ---- shared pieces --------------------------------------------------------------------------

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(Insets.page, 28, Insets.page, 0),
        child: Row(children: [
          PillButton(icon: Icons.arrow_back_ios_new, tooltip: 'Back', height: 64, onPressed: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 20),
          PillButton(icon: Icons.home_outlined, tooltip: 'Home', height: 64, onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
        ]),
      );

  Widget _title(Item i, {double size = 96}) {
    final logo = _client.logo(i);
    final name = i.isEpisode ? (i.seriesName ?? i.name) : i.name;
    if (logo != null) {
      return SizedBox(height: size * 1.5, width: 700, child: Align(alignment: Alignment.bottomLeft, child: NetImage(logo, fit: BoxFit.contain, fallbackText: name)));
    }
    return Text(name, style: tv(size * 0.85, weight: FontWeight.w800, spacing: -1.5, height: 1.0), maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  Widget _meta(Item i) {
    final rt = i.runtime;
    final grey = tv(24, color: const Color(0xD1FFFFFF));
    final ends = rt != null && !i.isSeries ? DateTime.now().add(rt - i.position) : null;
    return Wrap(spacing: 18, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (i.yearLine != null) Text(i.yearLine!, style: grey),
      if (i.isSeries && _seasons.isNotEmpty) Text('${_seasons.length} season${_seasons.length == 1 ? '' : 's'}', style: grey),
      if (rt != null && !i.isSeries) Text(formatRuntime(rt), style: grey),
      if (i.officialRating != null) Badge2(i.officialRating!, outlined: true),
      if (i.communityRating != null)
        Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star_rounded, color: Palette.star, size: 26), const SizedBox(width: 4), Text(i.communityRating!.toStringAsFixed(1), style: grey)]),
      if (i.genres.isNotEmpty) Text(i.genres.take(3).join(', '), style: grey),
      if (ends != null) Text('Ends at ${_clock(ends)}', style: grey),
      for (final b in mediaBadges(i)) Badge2(b),
    ]);
  }

  static String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  List<Widget> _iconActions(Item i) => [
        PillButton(icon: i.userData.played ? Icons.check_circle : Icons.check, tooltip: i.userData.played ? 'Mark unwatched' : 'Mark watched', height: 76, onPressed: () => _toggle(played: true)),
        const SizedBox(width: 16),
        PillButton(icon: i.userData.isFavorite ? Icons.favorite : Icons.favorite_border, tooltip: 'Favourite', height: 76, onPressed: () => _toggle(played: false)),
        const SizedBox(width: 16),
        PillButton(
          icon: Icons.more_horiz,
          tooltip: 'More',
          height: 76,
          onPressed: () => showMoreMenu(context, widget.session, i,
              onChanged: _refresh,
              openRelated: (x) => openItem(context, widget.session, x),
              playFromStart: () => openPlayer(context, widget.session, i, fromStart: true)),
        ),
      ];

  // ---- movie / episode -----------------------------------------------------------------------

  Widget _movieTop(Item i) {
    final resumable = i.userData.playbackPositionTicks > 0;
    // What the user picked in the panel, else what the server picks for them.
    final choice = widget.session.trackChoices[i.id];
    final audio = choice?.audio != null ? i.streams('Audio').where((s) => s['Index'] == choice!.audio).firstOrNull : i.stream('Audio');
    final sub = choice?.subtitle != null ? i.streams('Subtitle').where((s) => s['Index'] == choice!.subtitle).firstOrNull : i.stream('Subtitle');
    final tagline = i.taglines.firstOrNull;
    return SizedBox(
      height: 900,
      child: Stack(children: [
        Positioned(left: 0, right: 0, top: 0, child: _header()),
        Positioned(
          left: Insets.page,
          top: 150,
          width: 1060,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title(i),
            if (i.isEpisode) ...[
              const SizedBox(height: 18),
              Text([?i.episodeLabel, i.name].join(' · '), style: tv(32, weight: FontWeight.w600)),
            ],
            const SizedBox(height: 22),
            _meta(i),
            if (tagline != null) ...[const SizedBox(height: 22), Text(tagline, style: tv(30, weight: FontWeight.w600, color: const Color(0xEBFFFFFF)))],
            if (i.overview != null) ...[
              const SizedBox(height: 14),
              SizedBox(width: 920, child: Text(i.overview!, style: tv(25, color: Palette.text2, height: 1.55), maxLines: 4, overflow: TextOverflow.ellipsis)),
            ],
            const SizedBox(height: 30),
            Row(children: [
              PillButton(label: resumable ? 'Resume' : 'Play', icon: Icons.play_arrow_rounded, primary: true, autofocus: true, onPressed: () => openPlayer(context, widget.session, i)),
              const SizedBox(width: 16),
              if (resumable) ...[PillButton(label: 'From start', icon: Icons.replay, onPressed: () => openPlayer(context, widget.session, i, fromStart: true)), const SizedBox(width: 16)],
              ..._iconActions(i),
            ]),
          ]),
        ),
        if (audio != null || sub != null)
          Positioned(
            right: Insets.page,
            top: 560,
            width: 640,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (audio != null) _trackTile(Icons.graphic_eq, 'Audio', shortTrackName(audio), () => _tracks(i, 0)),
              const SizedBox(height: 14),
              _trackTile(Icons.closed_caption_outlined, 'Subtitles', sub == null ? 'Off' : shortTrackName(sub), () => _tracks(i, 1)),
              if (i.studios.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14, left: 6), child: Text(i.studios.take(2).join(' · '), style: tv(19, color: Palette.text3))),
            ]),
          ),
      ]),
    );
  }

  Widget _trackTile(IconData icon, String label, String value, VoidCallback onPressed) => TvFocusable(
        onPressed: onPressed,
        ensureVisible: false,
        builder: (context, focused) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: focused ? Palette.surfaceRaised : const Color(0xD1151922),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14FFFFFF)),
            boxShadow: focused ? focusShadow(ring: 3) : null,
          ),
          child: Row(children: [
            Icon(icon, color: Palette.accentText, size: 28),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: tv(18, color: Palette.text3)),
                const SizedBox(height: 4),
                Text(value, style: tv(23, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Palette.text3, size: 28),
          ]),
        ),
      );

  // ---- series --------------------------------------------------------------------------------

  Widget _seriesTop(Item i) {
    final next = _nextUp;
    final playLabel = next == null
        ? 'Play'
        : '${next.userData.playbackPositionTicks > 0 ? 'Resume' : 'Play'} ${next.episodeLabel ?? ''}'.trim();
    final focusEp = _focusedEpisode;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(),
      Padding(
        padding: const EdgeInsets.fromLTRB(Insets.page, 30, Insets.page, 0),
        child: SizedBox(
          width: 1100,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title(i, size: 90),
            const SizedBox(height: 20),
            _meta(i),
            if (i.overview != null) ...[
              const SizedBox(height: 18),
              SizedBox(width: 980, child: Text(i.overview!, style: tv(24, color: Palette.text2, height: 1.55), maxLines: 3, overflow: TextOverflow.ellipsis)),
            ],
            const SizedBox(height: 26),
            Row(children: [
              PillButton(label: playLabel, icon: Icons.play_arrow_rounded, primary: true, autofocus: true, height: 72, onPressed: () => openPlayer(context, widget.session, i)),
              const SizedBox(width: 16),
              PillButton(label: 'Shuffle', icon: Icons.shuffle, height: 72, onPressed: () => openPlayer(context, widget.session, i, shuffle: true)),
              const SizedBox(width: 16),
              ..._iconActions(i),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 36),
      if (_seasons.length > 1)
        SizedBox(
          height: 70,
          child: FocusTraversalGroup(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              clipBehavior: Clip.none,
              children: [
                for (final s in _seasons)
                  Padding(padding: const EdgeInsets.only(right: 12), child: _seasonPill(s)),
              ],
            ),
          ),
        ),
      const SizedBox(height: 18),
      SizedBox(
        height: 330,
        child: _episodes.isEmpty
            ? const Center(child: SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 4, color: Palette.accent)))
            : FocusTraversalGroup(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: Insets.page, vertical: 14),
                  itemCount: _episodes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 30),
                  itemBuilder: (context, n) => _episodeCard(_episodes[n]),
                ),
              ),
      ),
      SizedBox(
        height: 90,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.page, 4, Insets.page, 0),
          child: focusEp == null
              ? null
              : Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${focusEp.indexNumber ?? ''}. ${focusEp.name}', style: tv(22, weight: FontWeight.w600)),
                    if (focusEp.overview != null) TextSpan(text: ' — ${focusEp.overview}', style: tv(22, color: Palette.text2)),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.5),
                ),
        ),
      ),
    ]);
  }

  Widget _seasonPill(Item s) {
    final on = s.id == _seasonId;
    return TvFocusable(
      onPressed: () => _pickSeason(s.id),
      ensureVisible: false,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
          color: focused ? Colors.white : (on ? const Color(0x40FFFFFF) : Palette.surface),
          borderRadius: BorderRadius.circular(999),
          boxShadow: focused ? [const BoxShadow(color: Palette.focusGlow, spreadRadius: 5)] : null,
        ),
        child: Text(s.name, style: tv(23, weight: FontWeight.w600, color: focused ? Palette.ground : (on ? Colors.white : const Color(0xCCFFFFFF)))),
      ),
    );
  }

  Widget _episodeCard(Item e) {
    final rt = e.runtime;
    final meta = [if (rt != null) formatRuntime(rt), if (e.communityRating != null) '★ ${e.communityRating!.toStringAsFixed(1)}'].join(' · ');
    return MediaCard(
      item: e,
      client: _client,
      landscape: true,
      width: 400,
      title: '${e.indexNumber != null ? '${e.indexNumber}. ' : ''}${e.name}',
      subtitle: meta.isEmpty ? null : meta,
      onPressed: () => openItem(context, widget.session, e),
      onFocus: (f) {
        if (f) setState(() => _focusedEpisode = e);
      },
    );
  }

  // ---- cast ----------------------------------------------------------------------------------

  Widget _castRow(Item i) {
    final people = i.people.take(20).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: Insets.page), child: Text('Cast & crew', style: tv(30, weight: FontWeight.w600))),
        const SizedBox(height: 16),
        SizedBox(
          height: 124,
          child: FocusTraversalGroup(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: Insets.page, vertical: 12),
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(width: 30),
              itemBuilder: (context, n) {
                final p = people[n];
                final img = _client.personImage(p);
                final role = (p['Role'] as String?)?.isNotEmpty == true ? p['Role'] as String : (p['Type'] as String? ?? '');
                return TvFocusable(
                  onPressed: () => openItem(context, widget.session, Item({'Id': p['Id'], 'Name': p['Name'], 'Type': 'Person'})),
                  builder: (context, focused) => SizedBox(
                    width: 300,
                    child: Row(children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.surfaceRaised, boxShadow: focused ? focusShadow(ring: 3) : null),
                        clipBehavior: Clip.antiAlias,
                        child: img == null ? const Icon(Icons.person, color: Palette.text3, size: 44) : ClipOval(child: NetImage(img, cacheWidth: 168)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p['Name'] ?? '', style: tv(22, weight: FontWeight.w600, color: focused ? Colors.white : const Color(0xE6FFFFFF)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(role, style: tv(19, color: Palette.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}
