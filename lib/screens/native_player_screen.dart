// Test page for the direct-feed player (packages/webos_native_player): plays the file itself
// from the server with no conversion. OK pauses, left / right seek, Back leaves.
// Kept apart from the main player until the engine is proven on the TV.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webos_native_player/webos_native_player.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../session.dart';
import '../theme.dart';

class NativePlayerScreen extends StatefulWidget {
  final Session session;
  final Item item;
  final bool fromStart;
  final Duration? startAt;
  const NativePlayerScreen({super.key, required this.session, required this.item, this.fromStart = false, this.startAt});
  @override
  State<NativePlayerScreen> createState() => _NativePlayerScreenState();
}

class _NativePlayerScreenState extends State<NativePlayerScreen> {
  NativePlayerController? _player;
  String? _error;
  bool _osd = true;

  JellyfinClient get _client => widget.session.client!;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final item = await _client.item(widget.item.id);
      final sources = (item.raw['MediaSources'] as List?) ?? const [];
      final sourceId = sources.isEmpty ? item.id : (sources.first as Map)['Id'] as String;
      final url = _client.uri('/Videos/${item.id}/stream', {
        'static': true,
        'mediaSourceId': sourceId,
        'deviceId': _client.deviceId,
        _client.keyParam: _client.token,
      }).toString();
      final player = NativePlayerController(url, startAt: widget.startAt ?? (widget.fromStart ? Duration.zero : item.position));
      player.addListener(() {
        if (mounted) setState(() {});
        if (player.value.completed && mounted) Navigator.of(context).maybePop();
      });
      setState(() => _player = player);
      await player.initialize();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final p = _player;
    final k = e.logicalKey;
    if (p == null) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.mediaPlayPause) {
      p.value.playing ? p.pause() : p.play();
      setState(() => _osd = true);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
      final step = Duration(seconds: k == LogicalKeyboardKey.arrowLeft ? -widget.session.seekBack : widget.session.seekForward);
      var to = p.value.position + step;
      if (to < Duration.zero) to = Duration.zero;
      p.seekTo(to);
      setState(() => _osd = true);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      setState(() => _osd = !_osd);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final v = _player?.value;
    final error = _error ?? v?.error;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(children: [
          const NativeVideoView(),
          if (v == null || (!v.initialized && error == null))
            const Center(child: CircularProgressIndicator()),
          if (error != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(40),
                color: const Color(0xE6000000),
                child: Text('Direct player: $error', style: tv(26), textAlign: TextAlign.center),
              ),
            ),
          if (_osd && v != null && v.initialized)
            Positioned(
              left: 96,
              right: 96,
              bottom: 70,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Icon(v.playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
                  const SizedBox(width: 18),
                  Expanded(child: Text(widget.item.name, style: tv(26, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${_fmt(v.position)} / ${_fmt(v.duration)}', style: tv(24)),
                  const SizedBox(width: 24),
                  Text('Direct · ${v.videoCodec} ${v.size.width.toInt()}×${v.size.height.toInt()}${v.audioCodec.isEmpty ? ' · no sound' : ' · ${v.audioCodec}'}',
                      style: tv(20, color: Palette.text3)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
