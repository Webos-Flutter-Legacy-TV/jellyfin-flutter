// Performance probe (off unless built with --dart-define=PERF_PROBE=true).
// Logs to stdout (compat.log on the TV):
//   [perf] slow frame ...  every frame over 20 ms: build (UI thread) vs raster (GPU thread)
//   [perf] summary ...     every 120 frames: averages and 90th percentiles
//   [perf] key ...         remote key to the end of the first frame drawn after it
//   [perf] image ...       each image load: source, bytes, fetch and decode time
import 'dart:developer' show Timeline;
import 'dart:io' show File, Platform, stderr;
import 'dart:ui' show FramePhase;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const perfProbe = bool.fromEnvironment('PERF_PROBE');

final _build = <double>[], _raster = <double>[], _total = <double>[];
int? _pendingKeyUs;
String _pendingKey = '';

void startPerfProbe() {
  if (!perfProbe) return;
  final t0 = Timeline.now;
  _log('[perf] probe on');
  perfFlag('');
  HardwareKeyboard.instance.addHandler((e) {
    if (e is KeyDownEvent && _pendingKeyUs == null) {
      _pendingKeyUs = Timeline.now;
      _pendingKey = e.logicalKey.keyLabel;
    }
    return false;
  });
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      final b = t.buildDuration.inMicroseconds / 1000;
      final r = t.rasterDuration.inMicroseconds / 1000;
      final tot = t.totalSpan.inMicroseconds / 1000;
      final at = (t.timestampInMicroseconds(FramePhase.vsyncStart) - t0) / 1e6;
      if (b + r > 20) {
        _log('[perf] slow frame at ${at.toStringAsFixed(2)}s: build ${b.toStringAsFixed(1)} raster ${r.toStringAsFixed(1)} '
            'total ${tot.toStringAsFixed(1)} ms (layers ${t.layerCacheCount}/${(t.layerCacheBytes / 1048576).toStringAsFixed(1)}MB, '
            'pictures ${t.pictureCacheCount}/${(t.pictureCacheBytes / 1048576).toStringAsFixed(1)}MB)');
      }
      final k = _pendingKeyUs;
      if (k != null && t.timestampInMicroseconds(FramePhase.buildStart) >= k) {
        final done = t.timestampInMicroseconds(FramePhase.rasterFinish);
        _log('[perf] key $_pendingKey at ${((k - t0) / 1e6).toStringAsFixed(2)}s: ${((done - k) / 1000).toStringAsFixed(1)} ms to a drawn frame '
            '(build ${b.toStringAsFixed(1)} raster ${r.toStringAsFixed(1)})');
        _pendingKeyUs = null;
      }
      _build.add(b);
      _raster.add(r);
      _total.add(tot);
      if (_build.length == 120) {
        _log('[perf] summary 120 frames: build avg/p90/max ${_stat(_build)}  raster ${_stat(_raster)}  total ${_stat(_total)}');
        _build.clear();
        _raster.clear();
        _total.clear();
      }
    }
  });
}

Set<String>? _flags;

/// Experiment switches for the probe build: words in the file perf-flags next to the app's executable.
bool perfFlag(String name) {
  if (!perfProbe) return false;
  return (_flags ??= () {
    try {
      final f = File('${File(Platform.resolvedExecutable).parent.path}/perf-flags');
      final set = f.existsSync() ? f.readAsStringSync().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet() : <String>{};
      _log('[perf] flags: ${set.join(' ')}');
      return set;
    } catch (_) {
      return <String>{};
    }
  }())
      .contains(name);
}

void _log(String s) => stderr.writeln(s);

String _stat(List<double> v) {
  final s = [...v]..sort();
  final avg = s.reduce((a, b) => a + b) / s.length;
  return '${avg.toStringAsFixed(1)}/${s[s.length * 9 ~/ 10].toStringAsFixed(1)}/${s.last.toStringAsFixed(1)}';
}

/// Image load timing, called by the image cache.
void perfImage(String url, String source, int bytes, double fetchMs, double decodeMs, int w, int h) {
  if (!perfProbe) return;
  final q = Uri.tryParse(url);
  final what = q == null ? url : '${q.pathSegments.length > 3 ? q.pathSegments[3] : q.path} ${q.queryParameters['fillWidth'] ?? q.queryParameters['maxWidth'] ?? ''}';
  _log('[perf] image $what: $source ${(bytes / 1024).round()} KB, fetch ${fetchMs.toStringAsFixed(0)} ms, '
      'decode ${decodeMs.toStringAsFixed(0)} ms, ${w}x$h');
}
