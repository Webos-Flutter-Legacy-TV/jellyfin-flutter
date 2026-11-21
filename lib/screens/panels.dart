// Mockup 8 · Audio and subtitles, and mockup 9 · More menu, as side panels.
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/panel.dart';
import '../ui/tv.dart';

/// Formats this TV decodes itself (LG webOS 6, measured on the C1); others are converted by the server.
const _directAudio = {'aac', 'mp3', 'ac3', 'eac3', 'flac', 'opus', 'vorbis', 'mp2', 'pcm_s16le', 'pcm_s24le'};

String _audioNote(Map<String, dynamic> s) {
  final codec = '${s['Codec'] ?? ''}'.toLowerCase();
  if (_directAudio.contains(codec)) return 'Plays as it is';
  if (codec == 'truehd') return 'Converted to Dolby Digital Plus by the server, Atmos kept where it can be';
  if (codec.startsWith('dts')) return 'This TV has no DTS: converted by the server';
  return 'Converted by the server';
}

/// Audio / Subtitles / (later) Quality for an item. Choices are kept for this session.
Future<void> showTracksPanel(BuildContext context, Session session, Item item, {int startTab = 0}) {
  return showSidePanel(context, width: 760, builder: (context) => _TracksPanel(session: session, item: item, startTab: startTab));
}

class _TracksPanel extends StatefulWidget {
  final Session session;
  final Item item;
  final int startTab;
  const _TracksPanel({required this.session, required this.item, required this.startTab});
  @override
  State<_TracksPanel> createState() => _TracksPanelState();
}

class _TracksPanelState extends State<_TracksPanel> {
  late int _tab = widget.startTab;

  int? get _audio => widget.session.trackChoices[widget.item.id]?.audio ?? (widget.item.stream('Audio')?['Index'] as num?)?.toInt();
  int get _sub => widget.session.trackChoices[widget.item.id]?.subtitle ?? (widget.item.stream('Subtitle')?['Index'] as num?)?.toInt() ?? -1;

  @override
  Widget build(BuildContext context) {
    final audio = widget.item.streams('Audio');
    final subs = widget.item.streams('Subtitle');
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 80, 56, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          for (final (n, label) in [(0, 'Audio'), (1, 'Subtitles')])
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TvFocusable(
                ensureVisible: false,
                onPressed: () => setState(() => _tab = n),
                onFocus: (f) {
                  if (f) setState(() => _tab = n);
                },
                builder: (context, focused) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: focused ? Colors.white : (_tab == n ? const Color(0x33FFFFFF) : Palette.surfaceRaised),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(label, style: tv(24, weight: FontWeight.w600, color: focused ? Palette.ground : Colors.white)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 26),
        Expanded(
          child: ListView(children: [
            if (_tab == 0)
              for (final s in audio)
                PanelRow(
                  title: shortTrackName(s),
                  detail: [if (s['IsDefault'] == true) 'Default', _audioNote(s)].join(' · '),
                  tag: _directAudio.contains('${s['Codec']}'.toLowerCase()) ? 'DIRECT' : null,
                  selected: s['Index'] == _audio,
                  autofocus: s['Index'] == _audio,
                  onPressed: () {
                    widget.session.chooseTracks(widget.item.id, audio: (s['Index'] as num).toInt());
                    Navigator.of(context).pop();
                  },
                )
            else ...[
              PanelRow(title: 'Off', selected: _sub == -1, autofocus: _sub == -1, onPressed: () {
                widget.session.chooseTracks(widget.item.id, subtitle: -1);
                Navigator.of(context).pop();
              }),
              for (final s in subs)
                PanelRow(
                  title: shortTrackName(s),
                  detail: [if (s['Title'] != null) '${s['Title']}', if (s['IsExternal'] == true) 'External file', if (s['IsDefault'] == true) 'Default'].join(' · ').ifEmpty,
                  selected: s['Index'] == _sub,
                  autofocus: s['Index'] == _sub,
                  onPressed: () {
                    widget.session.chooseTracks(widget.item.id, subtitle: (s['Index'] as num).toInt());
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ]),
        ),
        if (_tab == 0)
          Text('TrueHD and DTS have no decoder on this TV; the server converts them while the video plays as it is.', style: tv(20, color: Palette.text3, height: 1.5)),
      ]),
    );
  }
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}

/// Viewer actions first; admin actions under Manage, Delete asks to confirm.
Future<void> showMoreMenu(BuildContext context, Session session, Item item, {required VoidCallback onChanged, required void Function(Item) openRelated, required VoidCallback playFromStart}) {
  final client = session.client!;
  final ud = item.userData;
  final admin = session.current?.isAdmin == true;
  Future<void> act(BuildContext ctx, Future<void> Function() f) async {
    Navigator.of(ctx).pop();
    try {
      await f();
      onChanged();
    } on ApiException catch (_) {}
  }

  return showSidePanel(
    context,
    width: 700,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(48, 70, 48, 40),
      child: ListView(children: [
        PanelHeader(kicker: [item.isEpisode ? (item.seriesName ?? '') : item.name, ?item.yearLine].where((e) => e.isNotEmpty).join(' · '), title: 'More'),
        if (ud.playbackPositionTicks > 0)
          PanelRow(title: 'Play from the beginning', icon: Icons.replay, autofocus: true, onPressed: () {
            Navigator.of(ctx).pop();
            playFromStart();
          }),
        PanelRow(title: ud.played ? 'Mark as unwatched' : 'Mark as watched', icon: Icons.check, autofocus: ud.playbackPositionTicks <= 0, onPressed: () => act(ctx, () => client.setPlayed(item.id, !ud.played))),
        PanelRow(title: ud.isFavorite ? 'Remove from favourites' : 'Add to favourites', icon: ud.isFavorite ? Icons.favorite : Icons.favorite_border, onPressed: () => act(ctx, () => client.setFavorite(item.id, !ud.isFavorite))),
        if (item.isEpisode && item.seriesId != null)
          PanelRow(title: 'Go to ${item.seriesName ?? 'series'}', icon: Icons.tv, onPressed: () {
            Navigator.of(ctx).pop();
            openRelated(Item({'Id': item.seriesId, 'Type': 'Series', 'Name': item.seriesName ?? ''}));
          }),
        if (item.isEpisode && item.seasonId != null)
          PanelRow(title: 'Go to season ${item.parentIndexNumber ?? ''}'.trim(), icon: Icons.view_list, onPressed: () {
            Navigator.of(ctx).pop();
            openRelated(Item({'Id': item.seasonId, 'Type': 'Season', 'SeriesId': item.seriesId, 'SeriesName': item.seriesName, 'Name': ''}));
          }),
        if (admin) ...[
          const PanelSection('Manage'),
          PanelRow(title: 'Refresh metadata', icon: Icons.refresh, onPressed: () => act(ctx, () => client.refreshMetadata(item.id))),
          PanelRow(
            title: 'Delete media…',
            icon: Icons.delete_outline,
            danger: true,
            onPressed: () async {
              final ok = await confirmPanel(ctx,
                  title: 'Delete "${item.name}"?',
                  detail: 'The file is removed from the server\'s disk and from the library for everyone. This cannot be undone.',
                  confirm: 'Delete');
              if (!ok || !ctx.mounted) return;
              await act(ctx, () => client.deleteItem(item.id));
              if (context.mounted) Navigator.of(context).maybePop(); // the item is gone: leave its page
            },
          ),
        ],
      ]),
    ),
  );
}
