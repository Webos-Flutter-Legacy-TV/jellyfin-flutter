// The parts of Jellyfin's DTOs the app reads (docs/jellyfin-api.md). Unknown fields are ignored.

class PublicSystemInfo {
  final String id, name, version;
  PublicSystemInfo({required this.id, required this.name, required this.version});
  factory PublicSystemInfo.fromJson(Map<String, dynamic> j) =>
      PublicSystemInfo(id: j['Id'] ?? '', name: j['ServerName'] ?? 'Jellyfin', version: j['Version'] ?? '');
}

class UserDto {
  final String id, name;
  final String? primaryImageTag;
  final bool isAdmin;
  UserDto({required this.id, required this.name, this.primaryImageTag, this.isAdmin = false});
  factory UserDto.fromJson(Map<String, dynamic> j) => UserDto(
      id: j['Id'],
      name: j['Name'] ?? '',
      primaryImageTag: j['PrimaryImageTag'],
      isAdmin: (j['Policy'] as Map<String, dynamic>?)?['IsAdministrator'] == true);
}

class AuthResult {
  final String accessToken, serverId;
  final UserDto user;
  AuthResult({required this.accessToken, required this.serverId, required this.user});
  factory AuthResult.fromJson(Map<String, dynamic> j) =>
      AuthResult(accessToken: j['AccessToken'], serverId: j['ServerId'] ?? '', user: UserDto.fromJson(j['User']));
}

class QuickConnectState {
  final String secret, code;
  final bool authenticated;
  QuickConnectState({required this.secret, required this.code, required this.authenticated});
  factory QuickConnectState.fromJson(Map<String, dynamic> j) =>
      QuickConnectState(secret: j['Secret'] ?? '', code: j['Code'] ?? '', authenticated: j['Authenticated'] == true);
}

class UserData {
  final double? playedPercentage;
  final int playbackPositionTicks;
  final bool played, isFavorite;
  final int? unplayedItemCount;
  UserData({this.playedPercentage, this.playbackPositionTicks = 0, this.played = false, this.isFavorite = false, this.unplayedItemCount});
  factory UserData.fromJson(Map<String, dynamic>? j) => j == null
      ? UserData()
      : UserData(
          playedPercentage: (j['PlayedPercentage'] as num?)?.toDouble(),
          playbackPositionTicks: (j['PlaybackPositionTicks'] as num?)?.toInt() ?? 0,
          played: j['Played'] == true,
          isFavorite: j['IsFavorite'] == true,
          unplayedItemCount: (j['UnplayedItemCount'] as num?)?.toInt());
}

/// A library item, folder or view (BaseItemDto).
class Item {
  final Map<String, dynamic> raw;
  Item(this.raw);

  String get id => raw['Id'];
  String get name => raw['Name'] ?? '';
  String get type => raw['Type'] ?? '';
  String? get collectionType => raw['CollectionType'];
  String? get overview => raw['Overview'];
  int? get productionYear => (raw['ProductionYear'] as num?)?.toInt();
  String? get officialRating => raw['OfficialRating'];
  double? get communityRating => (raw['CommunityRating'] as num?)?.toDouble();
  int? get runTimeTicks => (raw['RunTimeTicks'] as num?)?.toInt();
  String? get seriesId => raw['SeriesId'];
  String? get seriesName => raw['SeriesName'];
  int? get indexNumber => (raw['IndexNumber'] as num?)?.toInt();
  int? get parentIndexNumber => (raw['ParentIndexNumber'] as num?)?.toInt();
  String? get status => raw['Status'];
  String? get endDate => raw['EndDate'];
  double? get primaryImageAspectRatio => (raw['PrimaryImageAspectRatio'] as num?)?.toDouble();
  UserData get userData => UserData.fromJson(raw['UserData']);
  Map<String, dynamic> get imageTags => (raw['ImageTags'] as Map<String, dynamic>?) ?? const {};
  List<dynamic> get backdropImageTags => (raw['BackdropImageTags'] as List?) ?? const [];
  List<dynamic> get parentBackdropImageTags => (raw['ParentBackdropImageTags'] as List?) ?? const [];
  String? get parentBackdropItemId => raw['ParentBackdropItemId'];
  String? get parentThumbItemId => raw['ParentThumbItemId'];
  String? get parentThumbImageTag => raw['ParentThumbImageTag'];
  String? get seriesPrimaryImageTag => raw['SeriesPrimaryImageTag'];
  String? get parentLogoItemId => raw['ParentLogoItemId'];
  String? get parentLogoImageTag => raw['ParentLogoImageTag'];

  String? get seasonId => raw['SeasonId'];
  List<String> get genres => ((raw['Genres'] as List?) ?? const []).cast<String>();
  List<String> get taglines => ((raw['Taglines'] as List?) ?? const []).cast<String>();
  List<Map<String, dynamic>> get people => ((raw['People'] as List?) ?? const []).cast<Map<String, dynamic>>();
  List<String> get studios => ((raw['Studios'] as List?) ?? const []).map((e) => (e as Map)['Name'] as String).toList();
  int? get childCount => (raw['ChildCount'] as num?)?.toInt();

  /// The audio or subtitle stream the server picks for this user (its DefaultAudioStreamIndex /
  /// DefaultSubtitleStreamIndex, which follow the user's language settings). Null: none / off.
  Map<String, dynamic>? stream(String type) {
    final sources = (raw['MediaSources'] as List?) ?? const [];
    if (sources.isEmpty) return null;
    final src = sources.first as Map<String, dynamic>;
    final streams = ((src['MediaStreams'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final index = (src[type == 'Audio' ? 'DefaultAudioStreamIndex' : 'DefaultSubtitleStreamIndex'] as num?)?.toInt();
    if (index == null || index < 0) return type == 'Audio' ? streams.where((s) => s['Type'] == 'Audio').firstOrNull : null;
    return streams.where((s) => s['Type'] == type && s['Index'] == index).firstOrNull;
  }

  /// All streams of one type in the first media source.
  List<Map<String, dynamic>> streams(String type) {
    final sources = (raw['MediaSources'] as List?) ?? const [];
    if (sources.isEmpty) return const [];
    return (((sources.first as Map)['MediaStreams'] as List?) ?? const []).cast<Map<String, dynamic>>().where((s) => s['Type'] == type).toList();
  }

  bool get isEpisode => type == 'Episode';
  bool get isSeries => type == 'Series';
  bool get isFolderish => raw['IsFolder'] == true;

  /// "S1:E8" for an episode.
  String? get episodeLabel {
    if (!isEpisode) return null;
    final s = parentIndexNumber, e = indexNumber;
    if (s == null && e == null) return null;
    return 'S${s ?? 0}:E${e ?? 0}';
  }

  /// Year line as the official cards show it: "2026", or "2022 - Present" for a running series.
  String? get yearLine {
    final y = productionYear;
    if (y == null) return null;
    if (isSeries) {
      if (status == 'Continuing') return '$y – present';
      final end = endDate != null ? DateTime.tryParse(endDate!)?.year : null;
      if (end != null && end != y) return '$y – $end';
    }
    return '$y';
  }

  Duration? get runtime => runTimeTicks == null ? null : Duration(microseconds: runTimeTicks! ~/ 10);
  Duration get position => Duration(microseconds: userData.playbackPositionTicks ~/ 10);
}

class ItemsPage {
  final List<Item> items;
  final int total;
  ItemsPage(this.items, this.total);
  factory ItemsPage.fromJson(dynamic j) {
    if (j is List) return ItemsPage(j.map((e) => Item(e as Map<String, dynamic>)).toList(), j.length);
    final m = j as Map<String, dynamic>;
    final items = ((m['Items'] as List?) ?? const []).map((e) => Item(e as Map<String, dynamic>)).toList();
    return ItemsPage(items, (m['TotalRecordCount'] as num?)?.toInt() ?? items.length);
  }
}

String formatRuntime(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Badges for the hero and details: 4K, DOLBY VISION / HDR10, ATMOS, 7.1 (from the first media source).
List<String> mediaBadges(Item i) {
  final sources = (i.raw['MediaSources'] as List?) ?? const [];
  final streams = (sources.isNotEmpty ? (sources.first as Map)['MediaStreams'] as List? : null) ?? (i.raw['MediaStreams'] as List?) ?? const [];
  final out = <String>[];
  final video = streams.cast<Map>().where((s) => s['Type'] == 'Video').firstOrNull;
  if (video != null) {
    final w = (video['Width'] as num?)?.toInt() ?? 0, h = (video['Height'] as num?)?.toInt() ?? 0;
    if (w >= 3200 || h >= 2000) {
      out.add('4K');
    } else if (w >= 1800 || h >= 1000) {
      out.add('HD');
    }
    final range = '${video['VideoRangeType'] ?? ''}';
    if (range.startsWith('DOVI')) {
      out.add('DOLBY VISION');
      if (range.contains('HDR10')) out.add('HDR10');
    } else if (range.contains('HDR10Plus')) {
      out.add('HDR10+');
    } else if (range.contains('HDR10')) {
      out.add('HDR10');
    } else if (range == 'HLG') {
      out.add('HLG');
    }
  }
  final audio = i.stream('Audio');
  if (audio != null) {
    final desc = '${audio['Profile'] ?? ''} ${audio['DisplayTitle'] ?? ''}';
    if (desc.contains('Atmos')) out.add('ATMOS');
    final ch = (audio['Channels'] as num?)?.toInt() ?? 0;
    if (ch >= 8) {
      out.add('7.1');
    } else if (ch >= 6) {
      out.add('5.1');
    }
  }
  return out;
}

/// "English · TrueHD Atmos 7.1" instead of the server's long DisplayTitle.
String shortTrackName(Map<String, dynamic> s) {
  final lang = s['Language'] as String?;
  final langName = languageName(lang);
  if (s['Type'] == 'Subtitle') {
    final codec = '${s['Codec'] ?? ''}'.toUpperCase();
    return [?langName, if (codec.isNotEmpty) codec == 'SUBRIP' ? 'SRT' : codec, if (s['IsForced'] == true) 'Forced'].join(' · ');
  }
  final codec = '${s['Codec'] ?? ''}'.toLowerCase();
  final profile = '${s['Profile'] ?? ''}';
  var name = const {'truehd': 'TrueHD', 'eac3': 'Dolby Digital Plus', 'ac3': 'Dolby Digital', 'dts': 'DTS', 'aac': 'AAC', 'flac': 'FLAC', 'opus': 'Opus', 'mp3': 'MP3', 'vorbis': 'Vorbis'}[codec] ?? codec.toUpperCase();
  if (profile.contains('Atmos') || '${s['DisplayTitle']}'.contains('Atmos')) name = '$name Atmos';
  if (codec == 'dts' && profile.contains('MA')) name = 'DTS-HD MA';
  final ch = (s['Channels'] as num?)?.toInt() ?? 0;
  final layout = ch >= 8 ? '7.1' : ch >= 6 ? '5.1' : ch == 2 ? 'stereo' : ch == 1 ? 'mono' : null;
  return [?langName, [name, ?layout].join(' ')].join(' · ');
}

const _languages = {
  'eng': 'English', 'hin': 'Hindi', 'jpn': 'Japanese', 'spa': 'Spanish', 'fre': 'French', 'fra': 'French',
  'ger': 'German', 'deu': 'German', 'ita': 'Italian', 'kor': 'Korean', 'chi': 'Chinese', 'zho': 'Chinese',
  'tam': 'Tamil', 'tel': 'Telugu', 'nep': 'Nepali', 'dan': 'Danish', 'swe': 'Swedish', 'nor': 'Norwegian',
  'nob': 'Norwegian', 'fin': 'Finnish', 'dut': 'Dutch', 'nld': 'Dutch', 'por': 'Portuguese', 'rus': 'Russian',
  'pol': 'Polish', 'tur': 'Turkish', 'ara': 'Arabic', 'heb': 'Hebrew', 'gre': 'Greek', 'ell': 'Greek',
  'cze': 'Czech', 'ces': 'Czech', 'hun': 'Hungarian', 'rum': 'Romanian', 'ron': 'Romanian', 'tha': 'Thai',
  'vie': 'Vietnamese', 'ind': 'Indonesian', 'may': 'Malay', 'msa': 'Malay', 'ukr': 'Ukrainian', 'bul': 'Bulgarian',
  'hrv': 'Croatian', 'srp': 'Serbian', 'slv': 'Slovenian', 'slo': 'Slovak', 'slk': 'Slovak', 'est': 'Estonian',
  'lav': 'Latvian', 'lit': 'Lithuanian', 'ice': 'Icelandic', 'isl': 'Icelandic', 'cat': 'Catalan', 'baq': 'Basque',
  'eus': 'Basque', 'glg': 'Galician', 'per': 'Persian', 'fas': 'Persian', 'urd': 'Urdu', 'ben': 'Bengali',
  'mal': 'Malayalam', 'kan': 'Kannada', 'mar': 'Marathi', 'pan': 'Punjabi', 'guj': 'Gujarati', 'fil': 'Filipino',
  'und': 'Unknown',
};

/// "English" for "eng"; the code itself when not in the list.
String? languageName(String? code) => code == null ? null : _languages[code.toLowerCase()] ?? code.toUpperCase();
