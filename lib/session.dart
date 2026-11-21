// Saved servers, the signed-in user and the device id, kept in shared_preferences.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/client.dart';
import 'api/models.dart';

class SavedServer {
  final String id, name, url;
  final String? userId, userName, token, version;
  final bool isAdmin;
  SavedServer({required this.id, required this.name, required this.url, this.userId, this.userName, this.token, this.version, this.isAdmin = false});

  bool get signedIn => token != null && userId != null;

  SavedServer copyWith({String? name, String? url, String? version, String? userId, String? userName, String? token, bool? isAdmin, bool signOut = false}) =>
      SavedServer(
          id: id,
          name: name ?? this.name,
          url: url ?? this.url,
          version: version ?? this.version,
          userId: signOut ? null : userId ?? this.userId,
          userName: signOut ? userName ?? this.userName : userName ?? this.userName,
          token: signOut ? null : token ?? this.token,
          isAdmin: signOut ? false : isAdmin ?? this.isAdmin);

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'url': url, 'version': version,
        'userId': userId, 'userName': userName, 'token': token, 'isAdmin': isAdmin,
      };
  factory SavedServer.fromJson(Map<String, dynamic> j) => SavedServer(
      id: j['id'], name: j['name'], url: j['url'], version: j['version'],
      userId: j['userId'], userName: j['userName'], token: j['token'], isAdmin: j['isAdmin'] == true);
}

class Session extends ChangeNotifier {
  static const _kServers = 'servers', _kCurrent = 'currentServer', _kDevice = 'deviceId';

  final SharedPreferences _prefs;
  late final String deviceId;
  List<SavedServer> servers = [];
  SavedServer? current;
  JellyfinClient? client;

  Session(this._prefs) {
    deviceId = _prefs.getString(_kDevice) ?? _newDeviceId();
    _prefs.setString(_kDevice, deviceId);
    final raw = _prefs.getString(_kServers);
    if (raw != null) {
      try {
        servers = (jsonDecode(raw) as List).map((e) => SavedServer.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        servers = [];
      }
    }
    final cur = _prefs.getString(_kCurrent);
    current = servers.where((s) => s.id == cur).firstOrNull;
    if (current != null) client = _clientFor(current!);
  }

  static Future<Session> load() async => Session(await SharedPreferences.getInstance());

  static String _newDeviceId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  JellyfinClient _clientFor(SavedServer s) => JellyfinClient(baseUrl: s.url, deviceId: deviceId, token: s.token, userId: s.userId);

  JellyfinClient clientForUrl(String url) => JellyfinClient(baseUrl: url, deviceId: deviceId);

  Future<void> _save() async {
    await _prefs.setString(_kServers, jsonEncode(servers.map((s) => s.toJson()).toList()));
    if (current != null) {
      await _prefs.setString(_kCurrent, current!.id);
    } else {
      await _prefs.remove(_kCurrent);
    }
  }

  void _put(SavedServer s) {
    servers = [s, ...servers.where((e) => e.id != s.id)];
    current = s;
    client = _clientFor(s);
  }

  /// Remembers a server the user picked (not signed in yet).
  Future<void> selectServer(String url, PublicSystemInfo info) async {
    final old = servers.where((s) => s.id == info.id).firstOrNull;
    _put(old?.copyWith(url: url, name: info.name, version: info.version) ??
        SavedServer(id: info.id, name: info.name, url: url, version: info.version));
    await _save();
    notifyListeners();
  }

  Future<void> signedIn(AuthResult auth) async {
    final s = current!.copyWith(userId: auth.user.id, userName: auth.user.name, token: auth.accessToken, isAdmin: auth.user.isAdmin);
    _put(s);
    await _save();
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await client?.logout();
    } catch (_) {}
    if (current != null) _put(current!.copyWith(signOut: true));
    await _save();
    notifyListeners();
  }

  /// Back to the server list (keeps the server's saved sign-in).
  Future<void> leaveServer() async {
    current = null;
    client = null;
    await _save();
    notifyListeners();
  }

  Future<void> forget(SavedServer s) async {
    servers = servers.where((e) => e.id != s.id).toList();
    if (current?.id == s.id) {
      current = null;
      client = null;
    }
    await _save();
    notifyListeners();
  }
}
