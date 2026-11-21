// Images kept on disk (the app's cache folder) so posters and backdrops appear at once on the
// next start. Server image URLs carry the image's tag, so a changed image gets a new file.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Directory? _dir;
Future<Directory?>? _dirFuture;
const _maxBytes = 300 * 1024 * 1024;

Future<Directory?> _cacheDir() => _dirFuture ??= () async {
      try {
        final base = await getApplicationCacheDirectory();
        final d = Directory('${base.path}/images');
        await d.create(recursive: true);
        _dir = d;
        unawaited(_prune(d));
        return d;
      } catch (_) {
        return null; // no cache folder: images still load from the network
      }
    }();

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
    final dir = _dir ?? await _cacheDir();
    final file = dir == null ? null : File('${dir.path}/${_key(url)}');
    Uint8List? bytes;
    if (file != null && await file.exists()) {
      try {
        bytes = await file.readAsBytes();
      } catch (_) {}
    }
    if (bytes == null || bytes.isEmpty) {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw StateError('image ${res.statusCode}');
      bytes = res.bodyBytes;
      if (file != null) unawaited(file.writeAsBytes(bytes, flush: false).then((_) {}, onError: (_) {}));
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is CachedNetworkImage && other.url == url;
  @override
  int get hashCode => url.hashCode;
}

ImageProvider cachedImage(String url) => CachedNetworkImage(url);
