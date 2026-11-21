// Saved servers, the signed-in user and the device id, kept in shared_preferences.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/client.dart';
import 'api/models.dart';

/// One signed-in user on a server.
class Account {
  final String userId, userName, token;
  final bool isAdmin;
  final String? imageTag;
  Account({required this.userId, required this.userName, required this.token, this.isAdmin = false, this.imageTag});
  Map<String, dynamic> toJson() => {'userId': userId, 'userName': userName, 'token': token, 'isAdmin': isAdmin, 'imageTag': imageTag};
  factory Account.fromJson(Map<String, dynamic> j) =>
      Account(userId: j['userId'], userName: j['userName'] ?? '', token: j['token'], isAdmin: j['isAdmin'] == true, imageTag: j['imageTag']);
}

class SavedServer {
  final String id, name, url;
  final String? version;
  final List<Account> accounts; // users signed in on this TV, most recent first
  final String? currentUserId;
  final String? lastUserName; // shown in the sign-in form after signing out
  SavedServer({required this.id, required this.name, required this.url, this.version, this.accounts = const [], this.currentUserId, this.lastUserName});

  Account? get account => accounts.where((a) => a.userId == currentUserId).firstOrNull;
  bool get signedIn => account != null;
  String? get userId => account?.userId;
  String? get userName => account?.userName ?? lastUserName;
  String? get token => account?.token;
  bool get isAdmin => account?.isAdmin ?? false;

  SavedServer copyWith({String? name, String? url, String? version, List<Account>? accounts, String? currentUserId, bool clearUser = false, String? lastUserName}) => SavedServer(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      version: version ?? this.version,
      accounts: accounts ?? this.accounts,
      currentUserId: clearUser ? null : currentUserId ?? this.currentUserId,
      lastUserName: lastUserName ?? this.lastUserName);

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'url': url, 'version': version, 'currentUserId': currentUserId, 'lastUserName': lastUserName,
        'accounts': [for (final a in accounts) a.toJson()],
      };
  factory SavedServer.fromJson(Map<String, dynamic> j) {
    var accounts = ((j['accounts'] as List?) ?? const []).map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
    var current = j['currentUserId'] as String?;
    // Saved by an earlier version: one user in the server's own fields.
    if (accounts.isEmpty && j['token'] != null && j['userId'] != null) {
      accounts = [Account(userId: j['userId'], userName: j['userName'] ?? '', token: j['token'], isAdmin: j['isAdmin'] == true)];
      current = j['userId'];
    }
    return SavedServer(id: j['id'], name: j['name'], url: j['url'], version: j['version'], accounts: accounts, currentUserId: current, lastUserName: j['lastUserName'] ?? j['userName']);
  }
}

class Session extends ChangeNotifier {
  static const _kServers = 'servers', _kCurrent = 'currentServer', _kDevice = 'deviceId';

  final SharedPreferences _prefs;
  late final String deviceId;
  List<SavedServer> servers = [];
  SavedServer? current;
  JellyfinClient? client;

  /// Show "Who's watching?" (several users saved on this server, at start or when switching).
  bool choosingUser = false;
  /// Show the sign-in page to add another user while others stay signed in.
  bool addingUser = false;

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
    choosingUser = (current?.accounts.length ?? 0) > 1;
  }

  static Future<Session> load() async => Session(await SharedPreferences.getInstance());

  static String _newDeviceId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  JellyfinClient _clientFor(SavedServer s) => JellyfinClient(baseUrl: s.url, deviceId: deviceId, token: s.token, userId: s.userId, serverVersion: s.version);

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
    var s = old?.copyWith(url: url, name: info.name, version: info.version) ?? SavedServer(id: info.id, name: info.name, url: url, version: info.version);
    // One saved user: straight in; several: "Who's watching?".
    if (!s.signedIn && s.accounts.length == 1) s = s.copyWith(currentUserId: s.accounts.first.userId);
    _put(s);
    choosingUser = s.accounts.length > 1;
    addingUser = false;
    await _save();
    notifyListeners();
  }

  Future<void> signedIn(AuthResult auth) async {
    final a = Account(userId: auth.user.id, userName: auth.user.name, token: auth.accessToken, isAdmin: auth.user.isAdmin, imageTag: auth.user.primaryImageTag);
    final cur = current!;
    _put(cur.copyWith(accounts: [a, ...cur.accounts.where((x) => x.userId != a.userId)], currentUserId: a.userId, lastUserName: a.userName));
    addingUser = false;
    choosingUser = false;
    await _save();
    notifyListeners();
  }

  /// Signs the current user out of this TV; the others stay (and are offered to pick from).
  Future<void> signOut() async {
    try {
      await client?.logout();
    } catch (_) {}
    final cur = current;
    if (cur != null) {
      final rest = cur.accounts.where((a) => a.userId != cur.currentUserId).toList();
      _put(cur.copyWith(accounts: rest, clearUser: true, lastUserName: cur.userName));
      choosingUser = rest.isNotEmpty;
    }
    await _save();
    notifyListeners();
  }

  /// "Who's watching?" again.
  void chooseUser() {
    choosingUser = true;
    notifyListeners();
  }

  Future<void> switchTo(Account a) async {
    final cur = current!;
    _put(cur.copyWith(accounts: [a, ...cur.accounts.where((x) => x.userId != a.userId)], currentUserId: a.userId, lastUserName: a.userName));
    choosingUser = false;
    await _save();
    notifyListeners();
  }

  void addUser() {
    addingUser = true;
    choosingUser = false;
    notifyListeners();
  }

  void cancelAddUser() {
    addingUser = false;
    choosingUser = (current?.accounts.length ?? 0) > 1 || current?.signedIn != true && (current?.accounts.isNotEmpty ?? false);
    notifyListeners();
  }

  /// Audio / subtitle picked for an item this session (stream indexes; -1 subtitle = off).
  final Map<String, ({int? audio, int? subtitle})> trackChoices = {};
  void chooseTracks(String itemId, {int? audio, int? subtitle}) {
    final old = trackChoices[itemId];
    trackChoices[itemId] = (audio: audio ?? old?.audio, subtitle: subtitle ?? old?.subtitle);
    notifyListeners();
  }

  // App settings kept on this TV.
  int get maxBitrate => _prefs.getInt('maxBitrate') ?? 120000000;
  bool get autoplayNext => _prefs.getBool('autoplayNext') ?? true;
  int get seekBack => _prefs.getInt('seekBack') ?? 10;
  int get seekForward => _prefs.getInt('seekForward') ?? 30;
  /// Subtitle text size (logical px on the 1080p canvas), colour, background and height.
  int get subSize => _prefs.getInt('subSize') ?? 44;
  String get subColor => _prefs.getString('subColor') ?? 'white';
  String get subBackground => _prefs.getString('subBackground') ?? 'shadow';
  int get subLift => _prefs.getInt('subLift') ?? 90;
  /// Intros and recaps: 'button' (offer Skip), 'auto' (skip them), 'off'.
  String get skipSegments => _prefs.getString('skipSegments') ?? 'button';
  Future<void> setString(String key, String v) async {
    await _prefs.setString(key, v);
    notifyListeners();
  }

  Future<void> setInt(String key, int v) async {
    await _prefs.setInt(key, v);
    notifyListeners();
  }

  Future<void> setBool(String key, bool v) async {
    await _prefs.setBool(key, v);
    notifyListeners();
  }

  String? getCached(String key) => _prefs.getString('cache.$key');
  Future<void> setCached(String key, String value) => _prefs.setString('cache.$key', value);

  List<String> get recentSearches => _prefs.getStringList('recentSearches') ?? const [];
  Future<void> addRecentSearch(String q) async {
    final t = q.trim();
    if (t.isEmpty) return;
    await _prefs.setStringList('recentSearches', [t, ...recentSearches.where((e) => e != t)].take(6).toList());
  }

  /// Back to the server list (keeps the server's saved sign-in).
  Future<void> leaveServer() async {
    current = null;
    client = null;
    choosingUser = false;
    addingUser = false;
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
