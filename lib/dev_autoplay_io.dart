import 'dart:io';

Future<(String, int, bool, int?)?> readDevAutoplay() async {
  try {
    final f = File('/tmp/webos_native_player.autoplay');
    if (!await f.exists()) return null;
    final parts = (await f.readAsString()).trim().split(RegExp(r'\s+'));
    try {
      await f.delete();
    } catch (_) {}  // written by root: the test script removes it
    if (parts.isEmpty || parts.first.isEmpty) return null;
    final sub = parts.where((p) => p.startsWith('sub=')).map((p) => int.tryParse(p.substring(4))).firstOrNull;
    return (parts.first, parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0, parts.contains('direct'), sub);
  } catch (_) {
    return null;
  }
}
