// A small Jellyfin API client: the client header, JSON requests and image URLs
// (docs/jellyfin-api.md). One instance per server; the token is set after login.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

const appName = 'Jellyfin Flutter TV';
const appVersion = '0.1.0';

class ApiException implements Exception {
  final int? status;
  final String message;
  ApiException(this.message, {this.status});
  bool get unauthorized => status == 401;
  @override
  String toString() => message;
}

class JellyfinClient {
  final String baseUrl; // no trailing slash
  final String deviceId;
  final String deviceName;
  String? token;
  String? userId;
  final http.Client _http;

  JellyfinClient({required String baseUrl, required this.deviceId, this.deviceName = 'LG webOS TV', this.token, this.userId, http.Client? httpClient})
      : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _http = httpClient ?? http.Client();

  String get authorization {
    final parts = ['Client="$appName"', 'Device="${_q(deviceName)}"', 'DeviceId="$deviceId"', 'Version="$appVersion"'];
    if (token != null) parts.add('Token="$token"');
    return 'MediaBrowser ${parts.join(', ')}';
  }

  static String _q(String s) => s.replaceAll('"', "'");

  Uri uri(String path, [Map<String, Object?>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null) q[k] = v is List ? v.join(',') : '$v';
    });
    return Uri.parse('$baseUrl$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<dynamic> get(String path, [Map<String, Object?>? query]) => _send('GET', path, query: query);
  Future<dynamic> post(String path, {Map<String, Object?>? query, Object? body}) => _send('POST', path, query: query, body: body);
  Future<dynamic> delete(String path, {Map<String, Object?>? query}) => _send('DELETE', path, query: query);

  Future<dynamic> _send(String method, String path, {Map<String, Object?>? query, Object? body, Duration timeout = const Duration(seconds: 20)}) async {
    final req = http.Request(method, uri(path, query))
      ..headers['Authorization'] = authorization
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final http.StreamedResponse res;
    try {
      res = await _http.send(req).timeout(timeout);
    } on TimeoutException {
      throw ApiException('The server did not answer in time.');
    } catch (e) {
      throw ApiException('Could not reach the server.');
    }
    final text = await res.stream.bytesToString();
    if (res.statusCode == 401) throw ApiException('Signed out by the server.', status: 401);
    if (res.statusCode >= 400) throw ApiException(text.isNotEmpty && text.length < 200 ? text : 'Server error ${res.statusCode}.', status: res.statusCode);
    if (text.isEmpty) return null;
    final type = res.headers['content-type'] ?? '';
    return type.contains('json') ? jsonDecode(text) : text;
  }

  // ---- server and login ------------------------------------------------------------------------

  Future<PublicSystemInfo> publicInfo({Duration timeout = const Duration(seconds: 6)}) async =>
      PublicSystemInfo.fromJson(await _send('GET', '/System/Info/Public', timeout: timeout));

  Future<AuthResult> authenticateByName(String user, String password) async =>
      AuthResult.fromJson(await post('/Users/AuthenticateByName', body: {'Username': user, 'Pw': password}));

  Future<bool> quickConnectEnabled() async => (await get('/QuickConnect/Enabled')) == true;
  Future<QuickConnectState> quickConnectInitiate() async => QuickConnectState.fromJson(await post('/QuickConnect/Initiate'));
  Future<QuickConnectState> quickConnectPoll(String secret) async =>
      QuickConnectState.fromJson(await get('/QuickConnect/Connect', {'secret': secret}));
  Future<AuthResult> authenticateWithQuickConnect(String secret) async =>
      AuthResult.fromJson(await post('/Users/AuthenticateWithQuickConnect', body: {'Secret': secret}));

  Future<UserDto> me() async => UserDto.fromJson(await get('/Users/Me'));

  /// The user's server-side preferences (audio / subtitle language, subtitle mode, …).
  Future<Map<String, dynamic>> userConfiguration() async => ((await get('/Users/Me')) as Map<String, dynamic>)['Configuration'] as Map<String, dynamic>? ?? {};
  Future<void> saveUserConfiguration(Map<String, dynamic> config) => post('/Users/Configuration', query: {'userId': userId}, body: config);
  Future<void> logout() async => post('/Sessions/Logout');

  // ---- browsing --------------------------------------------------------------------------------

  static const listFields = 'PrimaryImageAspectRatio,Overview,ParentId';

  Future<List<Item>> userViews() async => ItemsPage.fromJson(await get('/UserViews', {'userId': userId})).items;

  Future<List<Item>> resume({int limit = 16}) async => ItemsPage.fromJson(await get('/UserItems/Resume', {
        'userId': userId,
        'limit': limit,
        'mediaTypes': 'Video',
        'fields': listFields,
        'enableImageTypes': 'Primary,Backdrop,Thumb,Logo',
        'imageTypeLimit': 1,
        'enableUserData': true,
      })).items;

  Future<List<Item>> nextUp({int limit = 16, String? seriesId, bool resumable = false}) async => ItemsPage.fromJson(await get('/Shows/NextUp', {
        'userId': userId,
        'limit': limit,
        'seriesId': seriesId,
        'fields': listFields,
        'enableImageTypes': 'Primary,Backdrop,Thumb',
        'imageTypeLimit': 1,
        'enableResumable': resumable,
        'enableUserData': true,
      })).items;

  Future<List<Item>> latest(String parentId, {int limit = 16}) async => ItemsPage.fromJson(await get('/Items/Latest', {
        'userId': userId,
        'parentId': parentId,
        'limit': limit,
        'fields': listFields,
        'enableImageTypes': 'Primary,Backdrop,Thumb',
        'imageTypeLimit': 1,
        'enableUserData': true,
      })).items;

  Future<ItemsPage> items(Map<String, Object?> query) async =>
      ItemsPage.fromJson(await get('/Items', {'userId': userId, 'enableUserData': true, ...query}));

  Future<Item> item(String id) async => Item(await get('/Items/$id', {
        'userId': userId,
        'fields': 'Overview,Genres,People,Studios,MediaSources,MediaStreams,Chapters,Trickplay,Taglines,ProviderIds,ChildCount',
      }));

  Future<List<Item>> seasons(String seriesId) async =>
      ItemsPage.fromJson(await get('/Shows/$seriesId/Seasons', {'userId': userId, 'enableUserData': true, 'fields': 'PrimaryImageAspectRatio'})).items;

  Future<List<Item>> episodes(String seriesId, {String? seasonId}) async => ItemsPage.fromJson(await get('/Shows/$seriesId/Episodes', {
        'userId': userId,
        'seasonId': seasonId,
        'fields': 'Overview,PrimaryImageAspectRatio',
        'enableUserData': true,
        'enableImageTypes': 'Primary,Thumb',
      })).items;

  Future<List<Item>> similar(String id, {int limit = 16}) async =>
      ItemsPage.fromJson(await get('/Items/$id/Similar', {'userId': userId, 'limit': limit, 'fields': listFields})).items;

  Future<void> setPlayed(String id, bool played) =>
      played ? post('/UserPlayedItems/$id', query: {'userId': userId}) : delete('/UserPlayedItems/$id', query: {'userId': userId});

  Future<void> setFavorite(String id, bool fav) =>
      fav ? post('/UserFavoriteItems/$id', query: {'userId': userId}) : delete('/UserFavoriteItems/$id', query: {'userId': userId});

  Future<void> refreshMetadata(String id) => post('/Items/$id/Refresh', query: {'metadataRefreshMode': 'Default', 'imageRefreshMode': 'Default'});
  Future<void> deleteItem(String id) => delete('/Items/$id');

  String? personImage(Map<String, dynamic> person, {int size = 168}) {
    final tag = person['PrimaryImageTag'] as String?;
    final id = person['Id'] as String?;
    if (tag == null || id == null) return null;
    return image(id, 'Primary', tag, fillWidth: size, fillHeight: size);
  }

  // ---- images ----------------------------------------------------------------------------------

  /// URL of an item's image sized on the server; `tag` makes it cacheable. Null when there is no tag.
  String? image(String itemId, String type, String? tag, {int? fillWidth, int? fillHeight, int? maxWidth, int quality = 90, int? index}) {
    if (tag == null) return null;
    final path = index == null ? '/Items/$itemId/Images/$type' : '/Items/$itemId/Images/$type/$index';
    return uri(path, {'tag': tag, 'fillWidth': fillWidth, 'fillHeight': fillHeight, 'maxWidth': maxWidth, 'quality': quality}).toString();
  }

  /// Poster: the item's own, or for an episode its series' poster.
  String? primary(Item i, {int? fillWidth, int? fillHeight}) {
    if (i.isEpisode && i.seriesId != null && i.seriesPrimaryImageTag != null) {
      return image(i.seriesId!, 'Primary', i.seriesPrimaryImageTag, fillWidth: fillWidth, fillHeight: fillHeight);
    }
    return image(i.id, 'Primary', i.imageTags['Primary'], fillWidth: fillWidth, fillHeight: fillHeight);
  }

  /// A 16:9 picture for a card: the item's thumb, its backdrop, an episode's own still, or its series'.
  String? landscape(Item i, {int width = 768}) {
    final h = (width * 9 / 16).round();
    if (i.imageTags['Thumb'] != null) return image(i.id, 'Thumb', i.imageTags['Thumb'], fillWidth: width, fillHeight: h);
    if (i.isEpisode && i.imageTags['Primary'] != null) return image(i.id, 'Primary', i.imageTags['Primary'], fillWidth: width, fillHeight: h);
    if (i.backdropImageTags.isNotEmpty) return image(i.id, 'Backdrop', i.backdropImageTags.first, fillWidth: width, fillHeight: h);
    if (i.parentThumbItemId != null) return image(i.parentThumbItemId!, 'Thumb', i.parentThumbImageTag, fillWidth: width, fillHeight: h);
    if (i.parentBackdropItemId != null && i.parentBackdropImageTags.isNotEmpty) {
      return image(i.parentBackdropItemId!, 'Backdrop', i.parentBackdropImageTags.first, fillWidth: width, fillHeight: h);
    }
    // Libraries (and other folders) usually have only a Primary image, already wide.
    if (i.imageTags['Primary'] != null) return image(i.id, 'Primary', i.imageTags['Primary'], fillWidth: width, fillHeight: h);
    return null;
  }

  String? backdrop(Item i, {int width = 1920}) {
    if (i.backdropImageTags.isNotEmpty) return image(i.id, 'Backdrop', i.backdropImageTags.first, maxWidth: width, quality: 80);
    if (i.parentBackdropItemId != null && i.parentBackdropImageTags.isNotEmpty) {
      return image(i.parentBackdropItemId!, 'Backdrop', i.parentBackdropImageTags.first, maxWidth: width, quality: 80);
    }
    return null;
  }

  String? logo(Item i, {int maxWidth = 900}) {
    if (i.imageTags['Logo'] != null) return image(i.id, 'Logo', i.imageTags['Logo'], maxWidth: maxWidth);
    if (i.parentLogoItemId != null) return image(i.parentLogoItemId!, 'Logo', i.parentLogoImageTag, maxWidth: maxWidth);
    return null;
  }

  String userImage(String userId, String tag) => uri('/UserImage', {'userId': userId, 'tag': tag}).toString();
}

/// Turns what the user typed into candidate base URLs, most likely first.
List<String> candidateUrls(String input) {
  var s = input.trim();
  if (s.isEmpty) return const [];
  if (s.endsWith('/')) s = s.substring(0, s.length - 1);
  if (s.startsWith('http://') || s.startsWith('https://')) {
    final u = Uri.tryParse(s);
    if (u == null) return const [];
    if (u.hasPort) return [s];
    return [s, '${u.scheme}://${u.host}:${u.scheme == 'https' ? 8920 : 8096}${u.path}'];
  }
  final hasPort = RegExp(r':\d+$').hasMatch(s.split('/').first);
  if (hasPort) return ['http://$s', 'https://$s'];
  return ['https://$s', 'http://$s:8096', 'https://$s:8920', 'http://$s'];
}
