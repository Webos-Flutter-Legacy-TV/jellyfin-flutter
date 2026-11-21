// Browsers cannot send UDP: no discovery there (the PC preview build). Servers are typed.
class DiscoveredServer {
  final String id, name, address;
  DiscoveredServer(this.id, this.name, this.address);
}

Future<List<DiscoveredServer>> discoverServers({Duration wait = const Duration(seconds: 3)}) async => const [];
