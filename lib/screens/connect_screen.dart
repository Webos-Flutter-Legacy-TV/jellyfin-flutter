// Mockup 1 · Connect to server: servers found on the network and saved ones on the left,
// "Add a server" on the right.
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/discovery.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/logo.dart';
import '../ui/tv.dart';

class ConnectScreen extends StatefulWidget {
  final Session session;
  const ConnectScreen({super.key, required this.session});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ServerChoice {
  final String id, name, url, detail;
  final bool onNetwork;
  _ServerChoice(this.id, this.name, this.url, this.detail, this.onNetwork);
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _address = TextEditingController();
  List<DiscoveredServer> _found = [];
  bool _searching = true, _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _discover();
  }

  Future<void> _discover() async {
    setState(() => _searching = true);
    final found = await discoverServers();
    if (!mounted) return;
    setState(() {
      _found = found;
      _searching = false;
    });
  }

  List<_ServerChoice> get _choices {
    final out = <_ServerChoice>[];
    for (final d in _found) {
      final saved = widget.session.servers.where((s) => s.id == d.id).firstOrNull;
      final who = saved?.userName != null ? ' · ${saved!.signedIn ? 'signed in as' : 'last user'} ${saved.userName}' : '';
      out.add(_ServerChoice(d.id, d.name, d.address, '${Uri.tryParse(d.address)?.authority ?? d.address}$who', true));
    }
    for (final s in widget.session.servers) {
      if (out.any((c) => c.id == s.id)) continue;
      final who = s.userName != null ? ' · ${s.signedIn ? 'signed in as' : 'last user'} ${s.userName}' : '';
      out.add(_ServerChoice(s.id, s.name, s.url, '${Uri.tryParse(s.url)?.authority ?? s.url}$who', false));
    }
    return out;
  }

  Future<void> _connect(List<String> urls) async {
    if (urls.isEmpty || _connecting) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    String? lastError;
    for (final url in urls) {
      try {
        final info = await widget.session.clientForUrl(url).publicInfo();
        await widget.session.selectServer(url, info);
        return; // the app switches to sign in (or Home)
      } on ApiException catch (e) {
        lastError = e.message;
      } catch (e) {
        lastError = '$e';
      }
    }
    if (mounted) {
      setState(() {
        _connecting = false;
        _error = lastError == null ? null : 'No Jellyfin server answered at that address.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = _choices;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0.56, -0.45), radius: 1.1, colors: [Color(0xFF13233A), Palette.ground], stops: [0, 0.7]),
        ),
        padding: const EdgeInsets.fromLTRB(140, 140, 140, 120),
        child: FocusTraversalGroup(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 820,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const JellyfinMark(size: 84), const SizedBox(width: 22), Text('Jellyfin', style: tv(52, weight: FontWeight.w600))]),
                const SizedBox(height: 76),
                Text('Choose your server', style: tv(64, weight: FontWeight.w700, spacing: -1)),
                const SizedBox(height: 36),
                Text(
                  _searching ? 'Looking for servers on this network…' : 'Servers on this network appear here on their own. Pick one, or type its address.',
                  style: tv(27, color: Palette.text2, height: 1.45),
                ),
                const SizedBox(height: 40),
                for (var i = 0; i < choices.length && i < 4; i++)
                  Padding(padding: const EdgeInsets.only(bottom: 18), child: _serverTile(choices[i], autofocus: i == 0)),
                if (!_searching && choices.isEmpty)
                  Text('None found. Add one with its address.', style: tv(24, color: Palette.text3)),
              ]),
            ),
            const SizedBox(width: 120),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(56),
                  decoration: BoxDecoration(color: const Color(0xEB151922), borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0x0FFFFFFF))),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Add a server', style: tv(36, weight: FontWeight.w600)),
                    const SizedBox(height: 28),
                    TvTextField(
                      controller: _address,
                      label: 'Server address',
                      hint: '192.168.1.20 or jellyfin.example.org',
                      autofocus: choices.isEmpty,
                      action: TextInputAction.go,
                      onSubmitted: (v) => _connect(candidateUrls(v)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _error ?? 'Port 8096 and http are added when left out; https is tried first.',
                      style: tv(21, color: _error != null ? Palette.danger : Palette.text3, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    PillButton(
                      label: _connecting ? 'Connecting…' : 'Connect',
                      primary: true,
                      height: 84,
                      onPressed: () => _connect(candidateUrls(_address.text)),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _serverTile(_ServerChoice c, {bool autofocus = false}) {
    return TvFocusable(
      autofocus: autofocus,
      scale: 1.02,
      ensureVisible: false,
      onPressed: () => _connect([c.url]),
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
        decoration: BoxDecoration(
          color: focused ? Palette.surfaceRaised : Palette.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: focused ? focusShadow(ring: 3) : null,
        ),
        child: Row(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: c.onNetwork ? Palette.accent : const Color(0xFF262C3B), borderRadius: BorderRadius.circular(18)),
            child: Icon(c.onNetwork ? Icons.dns_outlined : Icons.public, color: Colors.white, size: 38),
          ),
          const SizedBox(width: 26),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: tv(32, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(c.detail, style: tv(22, color: Palette.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (c.onNetwork)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: const Color(0x2900A4DC), borderRadius: BorderRadius.circular(999)),
              child: Text('On this network', style: tv(20, weight: FontWeight.w600, color: Palette.accentText)),
            ),
        ]),
      ),
    );
  }
}
