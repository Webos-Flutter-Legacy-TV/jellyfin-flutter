// What the player page needs from a video engine, and the two engines that provide it:
// - TvPlayerEngine: the TV's own player (video_player): files it can open itself, the server's HLS.
// - DirectFeedEngine: packages/webos_native_player: the file read by the app and fed to the TV's
//   decoders, so 4K HDR / Dolby Vision MKV, DTS and TrueHD play without the server converting them.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webos_native_player/webos_native_player.dart';

abstract class PlaybackEngine extends ChangeNotifier {
  bool get initialized;
  bool get isPlaying;
  bool get isBuffering;
  /// The engine reached the end of the stream.
  bool get completed;
  Duration get position;
  Duration get duration;
  /// How far the stream is loaded (for the seek bar); `null` when unknown.
  Duration? get bufferedEnd;
  double get aspectRatio;
  String get captionText;
  /// Whether playback speed can be changed.
  bool get canChangeSpeed;

  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration to);
  Future<void> setSpeed(double speed);
  /// WebVTT text subtitles, timed by the engine's position.
  void setCaptions(Future<ClosedCaptionFile> file);
  Widget view();
}

class TvPlayerEngine extends PlaybackEngine {
  TvPlayerEngine(String url) : _c = VideoPlayerController.networkUrl(Uri.parse(url)) {
    _c.addListener(notifyListeners);
  }
  final VideoPlayerController _c;

  VideoPlayerValue get _v => _c.value;
  @override
  bool get initialized => _v.isInitialized;
  @override
  bool get isPlaying => _v.isPlaying;
  @override
  bool get isBuffering => _v.isBuffering;
  @override
  bool get completed =>
      _v.isInitialized && _v.duration > Duration.zero && _v.position >= _v.duration - const Duration(milliseconds: 600) && !_v.isPlaying;
  @override
  Duration get position => _v.position;
  @override
  Duration get duration => _v.duration;
  @override
  Duration? get bufferedEnd => _v.buffered.isEmpty ? null : _v.buffered.last.end;
  @override
  double get aspectRatio => _v.aspectRatio;
  @override
  String get captionText => _v.caption.text;
  @override
  bool get canChangeSpeed => true;

  @override
  Future<void> initialize() => _c.initialize();
  @override
  Future<void> play() => _c.play();
  @override
  Future<void> pause() => _c.pause();
  @override
  Future<void> seekTo(Duration to) => _c.seekTo(to);
  @override
  Future<void> setSpeed(double speed) => _c.setPlaybackSpeed(speed);
  @override
  void setCaptions(Future<ClosedCaptionFile> file) => _c.setClosedCaptionFile(file);
  @override
  Widget view() => Center(child: AspectRatio(aspectRatio: _v.aspectRatio, child: VideoPlayer(_c)));

  @override
  void dispose() {
    _c.removeListener(notifyListeners);
    _c.dispose();
    super.dispose();
  }
}

class DirectFeedEngine extends PlaybackEngine {
  DirectFeedEngine(String url, {Duration startAt = Duration.zero, int? audioStream})
      : _c = NativePlayerController(url, startAt: startAt, audioStream: audioStream) {
    _c.addListener(notifyListeners);
  }
  final NativePlayerController _c;
  List<Caption> _captions = const [];

  NativePlayerValue get _v => _c.value;
  @override
  bool get initialized => _v.initialized;
  @override
  bool get isPlaying => _v.playing;
  @override
  bool get isBuffering => false;
  @override
  bool get completed => _v.completed;
  @override
  Duration get position => _v.position;
  @override
  Duration get duration => _v.duration;
  @override
  Duration? get bufferedEnd => null;
  @override
  double get aspectRatio => _v.size.height > 0 ? _v.size.width / _v.size.height : 16 / 9;
  @override
  String get captionText {
    final p = _v.position;
    for (final c in _captions) {
      if (p >= c.start && p <= c.end) return c.text;
    }
    return '';
  }

  @override
  bool get canChangeSpeed => false;

  @override
  Future<void> initialize() => _c.initialize();
  @override
  Future<void> play() => _c.play();
  @override
  Future<void> pause() => _c.pause();
  @override
  Future<void> seekTo(Duration to) => _c.seekTo(to);
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  void setCaptions(Future<ClosedCaptionFile> file) {
    file.then((f) {
      _captions = f.captions;
      notifyListeners();
    }).catchError((_) {});
  }

  @override
  Widget view() => const NativeVideoView();

  @override
  void dispose() {
    _c.removeListener(notifyListeners);
    _c.dispose();
    super.dispose();
  }
}
