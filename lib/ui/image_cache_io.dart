// Images kept on disk (the app's cache folder) so posters and backdrops appear at once on the
// next start. Server image URLs carry the image's tag, so a changed image gets a new file.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../perf_probe.dart';

Directory? _dir;
Future<Directory?>? _dirFuture;
const _maxBytes = 300 * 1024 * 1024;

Future<Directory?> _cacheDir() => _dirFuture ??= () async {
      try {
        // LG's webOS path_provider has no cache directory (it throws), so fall back to the
        // app's support folder, which webOS keeps between starts.
        final Directory base;
        try {
          base = await getApplicationCacheDirectory();
        } catch (_) {
          final support = await getApplicationSupportDirectory();
          return _ready(Directory('${support.path}/image-cache'));
        }
        return _ready(Directory('${base.path}/images'));
      } catch (_) {
        return null; // no cache folder: images still load from the network
      }
    }();

Future<Directory?> _ready(Directory d) async {
  await d.create(recursive: true);
  _dir = d;
  unawaited(_prune(d));
  return d;
}

/// Keeps the cache under 300 MB, dropping the least recently used files.
Future<void> _prune(Directory d) async {
  try {
    final files = await d.list().where((e) => e is File).cast<File>().toList();
    final stats = [for (final f in files) (f, await f.stat())];
    var total = stats.fold<int>(0, (n, s) => n + s.$2.size);
    if (total <= _maxBytes) return;
    stats.sort((a, b) => a.$2.accessed.compareTo(b.$2.accessed));
    for (final (f, st) in stats) {
      if (total <= _maxBytes * 0.8) break;
      await f.delete();
      total -= st.size;
    }
  } catch (_) {}
}

/// FNV-1a 64-bit of the URL: the file name.
String _key(String url) {
  var h = 0xcbf29ce484222325;
  for (final c in url.codeUnits) {
    h ^= c;
    h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return h.toUnsigned(64).toRadixString(16);
}

class CachedNetworkImage extends ImageProvider<CachedNetworkImage> {
  final String url;
  const CachedNetworkImage(this.url);

  @override
  Future<CachedNetworkImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(CachedNetworkImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1.0, debugLabel: url);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final sw = Stopwatch()..start();
    var source = 'disk';
    final dir = _dir ?? await _cacheDir();
    final file = dir == null ? null : File('${dir.path}/${_key(url)}');
    Uint8List? bytes;
    if (file != null && await file.exists()) {
      try {
        bytes = await file.readAsBytes();
      } catch (_) {}
    }
    if (bytes == null || bytes.isEmpty) {
      source = 'net';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw StateError('image ${res.statusCode}');
      bytes = res.bodyBytes;
      if (file != null) unawaited(file.writeAsBytes(bytes, flush: false).then((_) {}, onError: (_) {}));
    }
    final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    if (!perfProbe) return codec;
    return _TimedCodec(codec, url, source, bytes.length, sw.elapsedMicroseconds / 1000);
  }

  @override
  bool operator ==(Object other) => other is CachedNetworkImage && other.url == url;
  @override
  int get hashCode => url.hashCode;
}

ImageProvider cachedImage(String url) => CachedNetworkImage(url);

/// Times the first frame decode of an image (the probe only).
class _TimedCodec implements ui.Codec {
  final ui.Codec _c;
  final String url, source;
  final int bytes;
  final double fetchMs;
  bool _done = false;
  _TimedCodec(this._c, this.url, this.source, this.bytes, this.fetchMs);
  @override
  int get frameCount => _c.frameCount;
  @override
  int get repetitionCount => _c.repetitionCount;
  @override
  void dispose() => _c.dispose();
  @override
  Future<ui.FrameInfo> getNextFrame() async {
    final sw = Stopwatch()..start();
    final f = await _c.getNextFrame();
    if (!_done) {
      _done = true;
      perfImage(url, source, bytes, fetchMs, sw.elapsedMicroseconds / 1000, f.image.width, f.image.height);
    }
    return f;
  }
}
