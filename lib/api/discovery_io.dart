// Finds Jellyfin servers on the LAN: a UDP broadcast "Who is JellyfinServer?" to port 7359,
// each server answers with JSON {Address, Id, Name}.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveredServer {
  final String id, name, address;
  DiscoveredServer(this.id, this.name, this.address);
}

Future<List<DiscoveredServer>> discoverServers({Duration wait = const Duration(seconds: 3)}) async {
  final found = <String, DiscoveredServer>{};
  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final done = Completer<void>();
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket!.receive();
      if (dg == null) return;
      try {
        final j = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
        final id = j['Id'] as String?, addr = j['Address'] as String?;
        if (id != null && addr != null) found[id] = DiscoveredServer(id, (j['Name'] as String?) ?? 'Jellyfin', addr);
      } catch (_) {}
    });
    final msg = utf8.encode('Who is JellyfinServer?');
    socket.send(msg, InternetAddress('255.255.255.255'), 7359);
    Timer(wait, () => done.complete());
    await done.future;
    await sub.cancel();
  } catch (_) {
    // No network or broadcast refused: nothing found.
  } finally {
    socket?.close();
  }
  return found.values.toList();
}
