// Mockup 7 · Player: the video with an on-screen display that hides itself. Left / Right seek
// (with the trickplay frame and chapter name), OK pauses, Skip intro from media segments, text
// subtitles drawn here, progress reported to the server so Continue watching stays right.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../api/playback.dart';
import '../api/remote.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/subtitle_text.dart';
import '../ui/tv.dart';
import '../ui/panel.dart';
import 'panels.dart';

class PlayerScreen extends StatefulWidget {
  final Session session;
  final Item item;
  final bool fromStart;
  /// What plays after this item (Play all, Shuffle, a season or playlist), in order.
  final List<Item> queue;
  /// Start here instead of the resume point (a cast from another device says where).
  final Duration? startAt;
  const PlayerScreen({super.key, required this.session, required this.item, this.fromStart = false, this.queue = const [], this.startAt});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Item? _item;
  PlaybackPlan? _plan;
  VideoPlayerController? _video;
  String? _error;
  bool _osd = true;
  Timer? _hideTimer, _reportTimer;
  Duration? _seekTarget; // while seeking with Left / Right
  Timer? _seekCommit;
  List<({String type, Duration start, Duration end})> _segments = const [];
  final Set<Duration> _autoSkipped = {}; // segments skipped automatically (by start), once each
  String? _skippedNote; // "Skipped intro", shown for a few seconds
  Timer? _noteTimer;
  bool _ended = false;
  Item? _upNext; // the item after this one (queue, or the next episode)
  double _speed = 1.0;
  int? _bitrateOverride;
  final _playFocus = FocusNode();
  final _rootFocus = FocusNode();

  JellyfinClient get _client => widget.session.client!;

  StreamSubscription? _remoteSub, _trackSub;

  @override
  void initState() {
    super.initState();
    _start();
    // Another device controlling this TV (Jellyfin on a phone).
    _remoteSub = remoteControl?.playstate.listen(_onRemote);
    _trackSub = remoteControl?.trackRequests.listen((t) async {
      final item = _item;
      if (item == null) return;
      widget.session.chooseTracks(item.id, audio: t.$1 == 'audio' ? t.$2 : null, subtitle: t.$1 == 'subtitle' ? t.$2 : null);
      final at = _position;
      _stopReporting();
      await _start(at: at);
    });
  }

  void _onRemote(RemotePlaystate c) {
    final v = _video;
    if (v == null) return;
    switch (c.command) {
      case 'Pause':
        if (v.value.isPlaying) _togglePlay();
      case 'Unpause':
        if (!v.value.isPlaying) _togglePlay();
      case 'PlayPause':
        _togglePlay();
      case 'Stop':
        setState(() => _osd = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
      case 'NextTrack':
        _playUpNext();
      case 'PreviousTrack':
        _seekBy(-_position);
      case 'Seek':
        if (c.seekTo != null) {
          setState(() => _seekTarget = c.seekTo);
          _commitSeek();
        }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _noteTimer?.cancel();
    _reportTimer?.cancel();
    _seekCommit?.cancel();
    _remoteSub?.cancel();
    _trackSub?.cancel();
    _stopReporting();
    _video?.dispose();
    _playFocus.dispose();
    _rootFocus.dispose();
    super.dispose();
  }

  Duration get _position => _video?.value.position ?? Duration.zero;
  Duration get _duration {
    final d = _video?.value.duration ?? Duration.zero;
    if (d > Duration.zero) return d;
    return _item?.runtime ?? Duration.zero;
  }

  Future<void> _start({Duration? at}) async {
    try {
      final item = _item ?? await _client.item(widget.item.id);
      final choice = widget.session.trackChoices[item.id];
      final start = at ?? widget.startAt ?? (widget.fromStart ? Duration.zero : item.position);
      final plan = await _client.plan(item, audioIndex: choice?.audio, subtitleIndex: choice?.subtitle, start: start, maxBitrate: _bitrateOverride ?? widget.session.maxBitrate);
      // A transcode starts where it was asked to; a direct file is seeked once open.
      final controller = VideoPlayerController.networkUrl(Uri.parse(plan.url));
      await controller.initialize();
      if (plan.method == PlayMethod.directPlay && start > Duration.zero) await controller.seekTo(start);
      if (plan.subtitleUrl != null) {
        controller.setClosedCaptionFile(http.get(Uri.parse(plan.subtitleUrl!)).then<ClosedCaptionFile>((r) => WebVTTCaptionFile(r.body)));
      }
      controller.addListener(_onTick);
      final old = _video;
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _item = item;
        _plan = plan;
        _video = controller;
        _error = null;
      });
      old?.removeListener(_onTick);
      await old?.dispose();
      await controller.play();
      _client.reportStart(item, plan, start).catchError((_) {});
      _reportTimer?.cancel();
      _reportTimer = Timer.periodic(const Duration(seconds: 10), (_) => _report());
      if (_speed != 1.0) await controller.setPlaybackSpeed(_speed);
      // Focus starts on Pause (the page's own key handler would otherwise hold it).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _osd) _playFocus.requestFocus();
      });
      _segments = await _client.segments(item.id);
      _autoSkipped.clear();
      _upNext ??= await _findNext(item);
      _showOsd();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'This video could not be played ($e).');
    }
  }

  void _onTick() {
    final v = _video?.value;
    if (v == null || !mounted) return;
    if (!_ended && v.isInitialized && v.duration > Duration.zero && v.position >= v.duration - const Duration(milliseconds: 600) && !v.isPlaying) {
      _ended = true;
      _finish();
      return;
    }
    _autoSkip(v.position);
    setState(() {}); // position, buffering, caption
  }

  /// "Skip automatically": jump over an intro or recap the first time playback enters it.
  void _autoSkip(Duration pos) {
    if (widget.session.skipSegments != 'auto') return;
    final seg = _segments.where((s) => (s.type == 'Intro' || s.type == 'Recap') && pos >= s.start && pos < s.end - const Duration(seconds: 2)).firstOrNull;
    if (seg == null || !_autoSkipped.add(seg.start)) return;
    _video?.seekTo(seg.end);
    _report();
    _skippedNote = seg.type == 'Intro' ? 'Skipped intro' : 'Skipped recap';
    _noteTimer?.cancel();
    _noteTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _skippedNote = null);
    });
  }

  void _report() {
    final item = _item, plan = _plan, v = _video;
    if (item == null || plan == null || v == null) return;
    _client.reportProgress(item, plan, v.value.position, paused: !v.value.isPlaying).catchError((_) {});
  }

  void _stopReporting() {
    final item = _item, plan = _plan, v = _video;
    _reportTimer?.cancel();
    if (item == null || plan == null || v == null) return;
    _client.reportStopped(item, plan, v.value.position).catchError((_) {});
  }

  /// At the end: the next episode when that setting is on, else back to where we came from.
  void _playNext(Item next, List<Item> rest) {
    _stopReporting();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => PlayerScreen(session: widget.session, item: next, fromStart: true, queue: rest),
      transitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  /// What plays next: the queue's next item, or (with auto-play on) the series' next episode.
  Future<Item?> _findNext(Item item) async {
    if (widget.queue.isNotEmpty) return widget.queue.first;
    if (!item.isEpisode || item.seriesId == null || !widget.session.autoplayNext) return null;
    try {
      final j = await _client.get('/Shows/${item.seriesId}/Episodes', {'userId': _client.userId, 'startItemId': item.id, 'limit': 2, 'fields': 'Overview', 'enableImageTypes': 'Primary,Thumb', 'imageTypeLimit': 1});
      return ItemsPage.fromJson(j).items.where((e) => e.id != item.id).firstOrNull;
    } on ApiException catch (_) {
      return null;
    }
  }

  void _playUpNext() {
    final next = _upNext;
    if (next == null || !mounted) return;
    final rest = widget.queue.isNotEmpty ? widget.queue.sublist(1) : const <Item>[];
    _playNext(next, rest);
  }

  Future<void> _finish() async {
    if (_upNext != null && mounted) {
      _playUpNext();
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  // ---- OSD and keys --------------------------------------------------------------------------

  void _showOsd({bool keep = false}) {
    _hideTimer?.cancel();
    if (!_osd) {
      setState(() => _osd = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !(_playFocus.hasFocus)) _playFocus.requestFocus();
      });
    }
    if (!keep && (_video?.value.isPlaying ?? false)) {
      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _seekTarget == null) {
          setState(() => _osd = false);
          _rootFocus.requestFocus();
        }
      });
    }
  }

  void _togglePlay() {
    final v = _video;
    if (v == null) return;
    if (v.value.isPlaying) {
      v.pause();
      _showOsd(keep: true);
    } else {
      v.play();
      _showOsd();
    }
    _report();
  }

  void _seekBy(Duration d) {
    final base = _seekTarget ?? _position;
    var t = base + d;
    if (t < Duration.zero) t = Duration.zero;
    if (_duration > Duration.zero && t > _duration) t = _duration - const Duration(seconds: 1);
    setState(() => _seekTarget = t);
    _showOsd(keep: true);
    // Seek after the presses stop, so holding the key scrubs without a seek per press.
    _seekCommit?.cancel();
    _seekCommit = Timer(const Duration(milliseconds: 700), _commitSeek);
  }

  Future<void> _commitSeek() async {
    final t = _seekTarget, v = _video;
    if (t == null || v == null) return;
    final plan = _plan;
    if (plan != null && plan.method != PlayMethod.directPlay && (t - _position).abs() > const Duration(seconds: 30)) {
      // A far jump in a server stream: ask the server to start there.
      setState(() => _seekTarget = null);
      await _start(at: t);
    } else {
      await v.seekTo(t);
      setState(() => _seekTarget = null);
      _report();
    }
    _showOsd();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    // The remote's media buttons work whether the controls show or not.
    if (k == LogicalKeyboardKey.mediaPlayPause || (k == LogicalKeyboardKey.mediaPlay && !(_video?.value.isPlaying ?? true)) || (k == LogicalKeyboardKey.mediaPause && (_video?.value.isPlaying ?? false))) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaPlay || k == LogicalKeyboardKey.mediaPause) return KeyEventResult.handled;
    if (k == LogicalKeyboardKey.mediaStop) {
      setState(() => _osd = false); // so the pop is not taken as "hide the controls"
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaTrackNext && _upNext != null) {
      _playUpNext();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaTrackPrevious) {
      _seekBy(-_position);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaFastForward) {
      _seekBy(Duration(seconds: widget.session.seekForward));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaRewind) {
      _seekBy(Duration(seconds: -widget.session.seekBack));
      return KeyEventResult.handled;
    }
    if (!_osd) {
      // OSD hidden: Left / Right seek straight away, OK pauses, anything else shows the OSD.
      if (k == LogicalKeyboardKey.arrowLeft) {
        _seekBy(Duration(seconds: -widget.session.seekBack));
      } else if (k == LogicalKeyboardKey.arrowRight) {
        _seekBy(Duration(seconds: widget.session.seekForward));
      } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.select) {
        _togglePlay();
      } else {
        _showOsd();
      }
      return KeyEventResult.handled;
    }
    _showOsd(keep: !(_video?.value.isPlaying ?? false));
    return KeyEventResult.ignored;
  }

  Future<void> _openTracks(int tab) async {
    final item = _item;
    if (item == null) return;
    _hideTimer?.cancel();
    final before = widget.session.trackChoices[item.id];
    await showTracksPanel(context, widget.session, item, startTab: tab);
    final after = widget.session.trackChoices[item.id];
    if (after != before) {
      // New tracks: ask the server again from here.
      final at = _position;
      _stopReporting();
      await _start(at: at);
    } else {
      _showOsd();
    }
  }

  // ---- build ---------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_osd || _error != null || _video == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // First Back hides the controls; the next one leaves.
        setState(() => _osd = false);
        _rootFocus.requestFocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        // On the TV the video plane under the Flutter surface shows through; a browser draws the
        // video itself, so the bars around it are black there.
        backgroundColor: kIsWeb ? Colors.black : Colors.transparent,
        body: Focus(
          focusNode: _rootFocus,
          autofocus: _video == null,
          onKeyEvent: _onKey,
          child: Stack(fit: StackFit.expand, children: [
            if (_video != null && _video!.value.isInitialized)
              Center(child: AspectRatio(aspectRatio: _video!.value.aspectRatio, child: VideoPlayer(_video!))),
            if (_video == null && _error == null) const ColoredBox(color: Colors.black, child: StateMessage(title: 'Starting…', loading: true)),
            if (_error != null)
              ColoredBox(
                color: Palette.ground,
                child: StateMessage(title: 'Could not play this', detail: _error, action: PillButton(label: 'Back', autofocus: true, onPressed: () => Navigator.of(context).maybePop())),
              ),
            if (_video?.value.isBuffering == true && _osd == false)
              const Center(child: SizedBox(width: 64, height: 64, child: CircularProgressIndicator(strokeWidth: 5, color: Colors.white))),
            _captions(),
            if (_video != null) _skipButton(),
            if (_video != null) _upNextCard(),
            if (_video != null)
              AnimatedOpacity(
                opacity: _osd ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: IgnorePointer(ignoring: !_osd, child: ExcludeFocus(excluding: !_osd, child: _controls())),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _captions() {
    final text = _video?.value.caption.text ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    final lift = widget.session.subLift.toDouble();
    return Positioned(
      left: 200,
      right: 200,
      bottom: _osd ? (lift < 330 ? 330 : lift) : lift,
      child: Center(child: SubtitleText(text.replaceAll(RegExp(r'<[^>]+>'), ''), session: widget.session)),
    );
  }

  /// In the credits (or the last 40 s): the next item, playable at once.
  Widget _upNextCard() {
    final next = _upNext, item = _item;
    if (next == null || item == null) return const SizedBox.shrink();
    final pos = _position, dur = _duration;
    final inCredits = _segments.any((s) => s.type == 'Outro' && pos >= s.start);
    if (!(inCredits || (dur > Duration.zero && dur - pos < const Duration(seconds: 40)))) return const SizedBox.shrink();
    final left = (dur - pos).inSeconds.clamp(0, 999);
    final still = _client.landscape(next, width: 480);
    return Positioned(
      right: Insets.page,
      bottom: _osd ? 330 : 90,
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xEB0F1219), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x1FFFFFFF))),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 192, height: 108, child: still == null ? const ColoredBox(color: Palette.surfaceRaised) : Image.network(still, fit: BoxFit.cover))),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('UP NEXT${widget.session.autoplayNext || widget.queue.isNotEmpty ? ' · ${left}s' : ''}', style: tv(18, weight: FontWeight.w700, color: Palette.accentText, spacing: 1.5)),
              const SizedBox(height: 4),
              Text(next.isEpisode ? [?next.episodeLabel, next.name].join(' · ') : next.name, style: tv(22, weight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              PillButton(label: 'Play now', icon: Icons.skip_next_rounded, height: 56, autofocus: !_osd, onPressed: _playUpNext),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _openSettings() async {
    _hideTimer?.cancel();
    final pick = await showSidePanel<(String, num)>(
      context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(48, 70, 48, 40),
        child: ListView(children: [
          const PanelHeader(title: 'Playback'),
          const PanelSection('Speed'),
          for (final sp in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
            PanelRow(title: sp == 1.0 ? 'Normal' : '${sp}x', selected: sp == _speed, autofocus: sp == _speed, onPressed: () => Navigator.of(context).pop(('speed', sp))),
          const PanelSection('Quality'),
          for (final (label, br) in const [('Auto', 120000000), ('40 Mbps · 4K', 40000000), ('20 Mbps · 1080p', 20000000), ('8 Mbps · 1080p', 8000000), ('4 Mbps · 720p', 4000000)])
            PanelRow(title: label, selected: br == (_bitrateOverride ?? widget.session.maxBitrate), onPressed: () => Navigator.of(context).pop(('quality', br))),
        ]),
      ),
    );
    if (pick == null) {
      _showOsd();
      return;
    }
    if (pick.$1 == 'speed') {
      _speed = pick.$2.toDouble();
      await _video?.setPlaybackSpeed(_speed);
      _showOsd();
    } else if (pick.$2 != (_bitrateOverride ?? widget.session.maxBitrate)) {
      _bitrateOverride = pick.$2.toInt();
      final at = _position;
      _stopReporting();
      await _start(at: at);
    }
  }

  Future<void> _toggleFavorite() async {
    final item = _item;
    if (item == null) return;
    try {
      await _client.setFavorite(item.id, !item.userData.isFavorite);
      final raw = {...item.raw, 'UserData': {...?(item.raw['UserData'] as Map<String, dynamic>?), 'IsFavorite': !item.userData.isFavorite}};
      if (mounted) setState(() => _item = Item(raw));
    } on ApiException catch (_) {}
    _showOsd();
  }

  Widget _skipButton() {
    final note = _skippedNote;
    if (note != null) {
      return Positioned(
        right: Insets.page,
        bottom: _osd ? 330 : 90,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xCC12151D), borderRadius: BorderRadius.circular(40)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Text(note, style: tv(24, weight: FontWeight.w600)),
          ]),
        ),
      );
    }
    final pos = _position;
    final offerIntro = widget.session.skipSegments != 'off';
    final seg = _segments.where((s) => (offerIntro && (s.type == 'Intro' || s.type == 'Recap') || (s.type == 'Outro' && _upNext == null)) && pos >= s.start && pos < s.end - const Duration(seconds: 1)).firstOrNull;
    if (seg == null) return const SizedBox.shrink();
    final label = switch (seg.type) { 'Intro' => 'Skip intro', 'Recap' => 'Skip recap', _ => 'Skip credits' };
    return Positioned(
      right: Insets.page,
      bottom: _osd ? 330 : 90,
      child: PillButton(label: label, icon: Icons.skip_next_rounded, height: 68, autofocus: !_osd, onPressed: () {
        _video?.seekTo(seg.end);
        _report();
      }),
    );
  }

  Widget _controls() {
    final item = _item, plan = _plan;
    if (item == null || plan == null) return const SizedBox.shrink();
    final v = _video!.value;
    final shown = _seekTarget ?? v.position;
    final dur = _duration;
    final frac = dur.inMilliseconds == 0 ? 0.0 : (shown.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
    final buffered = v.buffered.isEmpty ? 0.0 : (v.buffered.last.end.inMilliseconds / (dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds)).clamp(0.0, 1.0);
    final chapters = ((item.raw['Chapters'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final chapterTicks = [for (final c in chapters) ((c['StartPositionTicks'] as num?) ?? 0).toInt() ~/ 10000];
    String? chapterName;
    for (final c in chapters) {
      final at = ((c['StartPositionTicks'] as num?) ?? 0).toInt() ~/ 10000;
      if (at <= shown.inMilliseconds) chapterName = c['Name'] as String?;
    }
    final ends = DateTime.now().add(dur - shown);
    final title = item.isEpisode ? (item.seriesName ?? item.name) : item.name;
    final sub = [
      if (item.isEpisode) [?item.episodeLabel, item.name].join(' · ') else if (item.productionYear != null) '${item.productionYear}',
      ...mediaBadges(item).where((b) => b != 'HD'),
      plan.describe,
    ].join(' · ');
    return Stack(children: [
      const Positioned(left: 0, right: 0, top: 0, height: 260, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xBF000000), Color(0x00000000)])))),
      const Positioned(left: 0, right: 0, bottom: 0, height: 460, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xE0000000), Color(0x00000000)], stops: [0.2, 1])))),
      Positioned(
        left: Insets.page,
        right: Insets.page,
        top: 60,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: tv(44, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(sub, style: tv(22, color: Palette.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Text(_clock(DateTime.now()), style: tv(26, weight: FontWeight.w500, color: const Color(0xD9FFFFFF))),
        ]),
      ),
      // Seek bar with chapter ticks, trickplay frame and chapter name while seeking.
      Positioned(
        left: Insets.page,
        right: Insets.page,
        bottom: 170,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final tp = _seekTarget == null ? null : _client.trickplay(item, plan.mediaSourceId, shown);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 250,
              child: Stack(clipBehavior: Clip.none, children: [
                if (_seekTarget != null)
                  Positioned(
                    left: (w * frac - 160).clamp(0.0, w - 320),
                    bottom: 20,
                    child: Column(children: [
                      if (tp != null) _TrickplayFrame(tp: tp),
                      if (chapterName != null || tp != null) const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xBF0B0D12), borderRadius: BorderRadius.circular(8)),
                        child: Text([?chapterName, _fmt(shown)].join(' · '), style: tv(22, weight: FontWeight.w600)),
                      ),
                    ]),
                  ),
              ]),
            ),
            Focus(
              onKeyEvent: (node, e) {
                if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
                if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _seekBy(Duration(seconds: -widget.session.seekBack));
                  return KeyEventResult.handled;
                }
                if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _seekBy(Duration(seconds: widget.session.seekForward));
                  return KeyEventResult.handled;
                }
                if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.select) {
                  _seekCommit?.cancel();
                  _commitSeek();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(builder: (context) {
                final focused = Focus.of(context).hasFocus;
                return SizedBox(
                  height: 30,
                  child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
                    Container(height: 10, decoration: BoxDecoration(color: const Color(0x40FFFFFF), borderRadius: BorderRadius.circular(5))),
                    FractionallySizedBox(widthFactor: buffered, child: Container(height: 10, decoration: BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(5)))),
                    FractionallySizedBox(widthFactor: frac, child: Container(height: 10, decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(5)))),
                    for (final t in chapterTicks)
                      if (dur.inMilliseconds > 0 && t > 0) Positioned(left: w * t / dur.inMilliseconds, child: Container(width: 3, height: 10, color: const Color(0xCC0B0D12))),
                    Positioned(
                      left: w * frac - 15,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: focused ? [const BoxShadow(color: Palette.focusGlow, spreadRadius: 8)] : null),
                      ),
                    ),
                  ]),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Text(_fmt(shown), style: tv(22, color: const Color(0xCCFFFFFF))),
              const Spacer(),
              Text('−${_fmt(dur - shown)} · ends ${_clock(ends)}', style: tv(22, color: const Color(0xCCFFFFFF))),
            ]),
          ]);
        }),
      ),
      Positioned(
        left: Insets.page,
        right: Insets.page,
        bottom: 56,
        child: FocusTraversalGroup(
          child: Row(children: [
            Expanded(
              child: Row(children: [
                PillButton(icon: item.userData.isFavorite ? Icons.favorite : Icons.favorite_border, tooltip: 'Favourite', height: 68, onPressed: _toggleFavorite),
              ]),
            ),
            PillButton(icon: Icons.replay_10, tooltip: 'Back 10 seconds', height: 76, onPressed: () => _seekBy(Duration(seconds: -widget.session.seekBack))),
            const SizedBox(width: 26),
            PillButton(icon: v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, tooltip: v.isPlaying ? 'Pause' : 'Play', height: 100, primary: true, focusNode: _playFocus, autofocus: true, onPressed: _togglePlay),
            const SizedBox(width: 26),
            PillButton(icon: Icons.forward_30, tooltip: 'Forward 30 seconds', height: 76, onPressed: () => _seekBy(Duration(seconds: widget.session.seekForward))),
            Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                PillButton(icon: Icons.closed_caption_outlined, tooltip: 'Subtitles', height: 68, onPressed: () => _openTracks(1)),
                const SizedBox(width: 14),
                PillButton(icon: Icons.graphic_eq, tooltip: 'Audio', height: 68, onPressed: () => _openTracks(0)),
                const SizedBox(width: 14),
                PillButton(icon: Icons.tune, tooltip: 'Speed and quality', height: 68, onPressed: _openSettings),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  static String _fmt(Duration d) {
    final neg = d.isNegative;
    d = d.abs();
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    final t = h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}';
    return neg ? '-$t' : t;
  }

  static String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// One thumbnail cut out of a trickplay tile sheet.
class _TrickplayFrame extends StatelessWidget {
  final ({String url, int col, int row, int tileW, int tileH, int cols}) tp;
  const _TrickplayFrame({required this.tp});
  @override
  Widget build(BuildContext context) {
    const w = 320.0;
    final scale = w / tp.tileW;
    final h = tp.tileH * scale;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(12), color: Colors.black),
      clipBehavior: Clip.antiAlias,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.translate(
          offset: Offset(-tp.col * w, -tp.row * h),
          child: Image.network(tp.url, width: tp.cols * w, fit: BoxFit.fitWidth, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox.shrink()),
        ),
      ),
    );
  }
}
