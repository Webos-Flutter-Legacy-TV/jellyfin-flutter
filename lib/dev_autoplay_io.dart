import 'dart:io';

Future<(String, int)?> readDevAutoplay() async {
  try {
    final f = File('/tmp/webos_native_player.autoplay');
    if (!await f.exists()) return null;
    final parts = (await f.readAsString()).trim().split(RegExp(r'\s+'));
    try {
      await f.delete();
    } catch (_) {}  // written by root: the test script removes it
    if (parts.isEmpty || parts.first.isEmpty) return null;
    return (parts.first, parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  } catch (_) {
    return null;
  }
}
