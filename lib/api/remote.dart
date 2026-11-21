// The server's WebSocket (docs/jellyfin-api.md, "Live updates"): this TV registers as a
// session that can be controlled, so Jellyfin on a phone can cast to it, pause, seek or stop it,
// send it a message; and the app hears when the user's watched state changes elsewhere.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../session.dart';
import 'client.dart';
import 'models.dart';

/// A command for the player from another device.
class RemotePlaystate {
  final String command; // Stop, Pause, Unpause, PlayPause, NextTrack, PreviousTrack, Seek
  final Duration? seekTo;
  RemotePlaystate(this.command, {this.seekTo});
}

class RemoteControl extends ChangeNotifier {
  final Session session;
  RemoteControl(this.session) {
    session.addListener(_onSession);
    _onSession();
  }

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _keepAlive, _retry;
  String? _connectedFor; // server+user the socket belongs to
  int _attempt = 0;

  /// Items another device asked this TV to play, with where to start.
  final _play = StreamController<({List<Item> items, Duration start})>.broadcast();
  Stream<({List<Item> items, Duration start})> get playRequests => _play.stream;

  final _playstate = StreamController<RemotePlaystate>.broadcast();
  Stream<RemotePlaystate> get playstate => _playstate.stream;

  /// Track changes asked by another device: ('audio' | 'subtitle', stream index).
  final _tracks = StreamController<(String, int)>.broadcast();
  Stream<(String, int)> get trackRequests => _tracks.stream;

  final _messages = StreamController<(String, String)>.broadcast();
  Stream<(String, String)> get messages => _messages.stream;

  final _goHome = StreamController<void>.broadcast();
  Stream<void> get goHome => _goHome.stream;

  final _openItem = StreamController<String>.broadcast();
  Stream<String> get openItem => _openItem.stream;

  /// Bumped when the user's data (watched, favourites, progress) changed on the server.
  int userDataVersion = 0;

  void _onSession() {
    final s = session.current;
    final key = s != null && s.signedIn ? '${s.id}/${s.userId}' : null;
    if (key == _connectedFor) return;
    _close();
    _connectedFor = key;
    if (key != null) _connect();
  }

  void _close() {
    _keepAlive?.cancel();
    _retry?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> _connect() async {
    final client = session.client;
    if (client == null || client.token == null) return;
    final base = Uri.parse(client.baseUrl);
    final ws = base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '${base.path}/socket', queryParameters: {client.keyParam: client.token, 'deviceid': client.deviceId});
    try {
      final ch = WebSocketChannel.connect(ws);
      await ch.ready;
      _channel = ch;
      _attempt = 0;
      _sub = ch.stream.listen(_onMessage, onDone: _scheduleRetry, onError: (_) => _scheduleRetry());
      await _reportCapabilities(client);
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _keepAlive?.cancel();
    _channel = null;
    if (_connectedFor == null) return;
    _attempt++;
    final wait = Duration(seconds: (5 * _attempt).clamp(5, 60));
    _retry?.cancel();
    _retry = Timer(wait, _connect);
  }

  /// Tells the server what this TV can be asked to do (it then shows in "Play on" lists).
  Future<void> _reportCapabilities(JellyfinClient client) async {
    try {
      await client.post('/Sessions/Capabilities/Full', body: {
        'PlayableMediaTypes': ['Video'],
        'SupportedCommands': [
          'DisplayContent', 'DisplayMessage', 'GoHome', 'SetAudioStreamIndex', 'SetSubtitleStreamIndex', 'Play', 'PlayState', 'PlayNext', 'PlayMediaSource',
        ],
        'SupportsMediaControl': true,
        'SupportsPersistentIdentifier': true,
      });
    } catch (_) {}
  }

  void _send(String type, [Object? data]) {
    _channel?.sink.add(jsonEncode({'MessageType': type, 'Data': ?data}));
  }

  Future<void> _onMessage(dynamic raw) async {
    Map<String, dynamic> m;
    try {
      m = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = m['MessageType'] as String?;
    final data = m['Data'];
    switch (type) {
      case 'ForceKeepAlive':
        final secs = (data as num?)?.toInt() ?? 60;
        _keepAlive?.cancel();
        _keepAlive = Timer.periodic(Duration(seconds: (secs / 2).floor().clamp(5, 60)), (_) => _send('KeepAlive'));
        _send('KeepAlive');
      case 'Play':
        final d = (data as Map).cast<String, dynamic>();
        final ids = ((d['ItemIds'] as List?) ?? const []).cast<String>();
        final start = Duration(microseconds: ((d['StartPositionTicks'] as num?) ?? 0).toInt() ~/ 10);
        final client = session.client;
        if (ids.isEmpty || client == null) return;
        try {
          final page = await client.items({'ids': ids.join(','), 'fields': 'Overview'});
          // Keep the order the other device asked for.
          final byId = {for (final i in page.items) i.id: i};
          final items = [for (final id in ids) ?byId[id]];
          if (items.isNotEmpty) _play.add((items: items, start: start));
        } catch (_) {}
      case 'Playstate':
        final d = (data as Map).cast<String, dynamic>();
        final ticks = (d['SeekPositionTicks'] as num?)?.toInt();
        _playstate.add(RemotePlaystate('${d['Command']}', seekTo: ticks == null ? null : Duration(microseconds: ticks ~/ 10)));
      case 'GeneralCommand':
        final d = (data as Map).cast<String, dynamic>();
        final args = ((d['Arguments'] as Map?) ?? const {}).cast<String, dynamic>();
        switch (d['Name']) {
          case 'DisplayMessage':
            _messages.add(('${args['Header'] ?? 'Message'}', '${args['Text'] ?? ''}'));
          case 'GoHome':
            _goHome.add(null);
          case 'DisplayContent':
            final id = args['ItemId'] as String?;
            if (id != null) _openItem.add(id);
          case 'SetAudioStreamIndex':
            final i = int.tryParse('${args['Index']}');
            if (i != null) _tracks.add(('audio', i));
          case 'SetSubtitleStreamIndex':
            final i = int.tryParse('${args['Index']}');
            if (i != null) _tracks.add(('subtitle', i));
        }
      case 'UserDataChanged':
        userDataVersion++;
        notifyListeners();
    }
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    _connectedFor = null;
    _close();
    super.dispose();
  }
}

/// The app's one connection (set in main once the session is loaded).
RemoteControl? remoteControl;
