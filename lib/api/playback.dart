// How to play an item (docs/jellyfin-api.md, Playback): ask the server with a device profile,
// pick direct play or its HLS transcode, and report start / progress / stop.
import 'package:flutter/foundation.dart' show kIsWeb;

import 'client.dart';
import 'models.dart';

const ticksPerMs = 10000;

/// What an LG webOS 6 TV decodes (measured on the user's C1): HEVC/H.264/VP9/AV1 incl. HDR10
/// and Dolby Vision; AAC, MP3, AC-3, E-AC-3 (Atmos passes through), FLAC, Opus. No TrueHD, no DTS.
Map<String, dynamic> webosDeviceProfile({int maxBitrate = 120000000}) => {
      'Name': 'Jellyfin Flutter TV (webOS)',
      'MaxStreamingBitrate': maxBitrate,
      'MaxStaticBitrate': maxBitrate,
      'MusicStreamingTranscodingBitrate': 384000,
      'DirectPlayProfiles': [
        {'Type': 'Video', 'Container': 'mp4,m4v,mkv,webm,ts,mov', 'VideoCodec': 'h264,hevc,vp9,av1', 'AudioCodec': 'aac,mp3,ac3,eac3,flac,opus,vorbis'},
        {'Type': 'Audio', 'Container': 'mp3,aac,m4a,flac,ogg,opus,wav'},
      ],
      'TranscodingProfiles': [
        // fMP4 HLS keeps HEVC / HDR and E-AC-3 (Atmos) when only the audio has to change.
        {'Type': 'Video', 'Container': 'mp4', 'Protocol': 'hls', 'Context': 'Streaming', 'VideoCodec': 'hevc,h264', 'AudioCodec': 'eac3,ac3,aac', 'MaxAudioChannels': '8', 'MinSegments': 2, 'BreakOnNonKeyFrames': true},
        {'Type': 'Audio', 'Container': 'aac', 'Protocol': 'http', 'Context': 'Streaming', 'AudioCodec': 'aac', 'MaxAudioChannels': '2'},
      ],
      'ContainerProfiles': [],
      'CodecProfiles': [
        {
          'Type': 'Video',
          'Codec': 'h264',
          'Conditions': [
            {'Condition': 'LessThanEqual', 'Property': 'VideoLevel', 'Value': '52', 'IsRequired': false},
          ],
        },
      ],
      'SubtitleProfiles': [
        // Text subtitles are drawn by the app from WebVTT; image subtitles are burned in.
        {'Format': 'vtt', 'Method': 'External'},
        {'Format': 'srt', 'Method': 'External'},
        {'Format': 'subrip', 'Method': 'External'},
        {'Format': 'ass', 'Method': 'External'},
        {'Format': 'ssa', 'Method': 'External'},
        {'Format': 'pgssub', 'Method': 'Encode'},
        {'Format': 'dvdsub', 'Method': 'Encode'},
        {'Format': 'dvbsub', 'Method': 'Encode'},
      ],
    };

/// For the PC preview in a browser: H.264 + AAC only, HLS transcode otherwise.
Map<String, dynamic> browserDeviceProfile() => {
      'Name': 'Jellyfin Flutter TV (browser preview)',
      'MaxStreamingBitrate': 20000000,
      'DirectPlayProfiles': [
        {'Type': 'Video', 'Container': 'mp4,m4v', 'VideoCodec': 'h264', 'AudioCodec': 'aac,mp3'},
      ],
      'TranscodingProfiles': [
        {'Type': 'Video', 'Container': 'ts', 'Protocol': 'hls', 'Context': 'Streaming', 'VideoCodec': 'h264', 'AudioCodec': 'aac', 'MaxAudioChannels': '2', 'MinSegments': 2, 'BreakOnNonKeyFrames': true},
      ],
      'SubtitleProfiles': [
        {'Format': 'vtt', 'Method': 'External'},
        {'Format': 'srt', 'Method': 'External'},
        {'Format': 'subrip', 'Method': 'External'},
        {'Format': 'pgssub', 'Method': 'Encode'},
      ],
    };

enum PlayMethod { directPlay, directStream, transcode }

class PlaybackPlan {
  final String url;
  final PlayMethod method;
  final String playSessionId, mediaSourceId;
  final Map<String, dynamic> mediaSource;
  final int? audioIndex, subtitleIndex;
  /// External text subtitle to draw (WebVTT), when one is selected and not burned in.
  final String? subtitleUrl;
  PlaybackPlan({required this.url, required this.method, required this.playSessionId, required this.mediaSourceId, required this.mediaSource, this.audioIndex, this.subtitleIndex, this.subtitleUrl});

  String get methodName => switch (method) { PlayMethod.directPlay => 'DirectPlay', PlayMethod.directStream => 'DirectStream', PlayMethod.transcode => 'Transcode' };
  String get describe => switch (method) {
        PlayMethod.directPlay => 'Direct play',
        PlayMethod.directStream => 'Direct stream',
        PlayMethod.transcode => 'Converted by the server',
      };
}

extension Playback on JellyfinClient {
  /// Ask the server how to play `item` with the chosen tracks, from `start`.
  Future<PlaybackPlan> plan(Item item, {int? audioIndex, int? subtitleIndex, Duration start = Duration.zero, int maxBitrate = 120000000}) async {
    // The TV's player cannot switch audio tracks inside a file: another track than the file's
    // default goes through the server, which remuxes or converts it into HLS with that track.
    final defaultAudio = (item.stream('Audio')?['Index'] as num?)?.toInt();
    final wantsOtherAudio = audioIndex != null && defaultAudio != null && audioIndex != defaultAudio;
    final body = {
      'UserId': userId,
      'DeviceProfile': kIsWeb ? browserDeviceProfile() : webosDeviceProfile(maxBitrate: maxBitrate),
      'MaxStreamingBitrate': maxBitrate,
      'StartTimeTicks': start.inMilliseconds * ticksPerMs,
      'AudioStreamIndex': ?audioIndex,
      'SubtitleStreamIndex': ?subtitleIndex,
      'EnableDirectPlay': !wantsOtherAudio,
      'EnableDirectStream': true,
      'EnableTranscoding': true,
      'AllowVideoStreamCopy': true,
      'AllowAudioStreamCopy': true,
      'AutoOpenLiveStream': true,
    };
    final res = await post('/Items/${item.id}/PlaybackInfo', query: {'userId': userId}, body: body) as Map<String, dynamic>;
    final sources = (res['MediaSources'] as List?) ?? const [];
    if (sources.isEmpty) throw ApiException('The server offered no way to play this.');
    final src = sources.first as Map<String, dynamic>;
    final session = res['PlaySessionId'] as String? ?? '';
    final msid = src['Id'] as String;
    final audio = audioIndex ?? (src['DefaultAudioStreamIndex'] as num?)?.toInt();
    final sub = subtitleIndex ?? (src['DefaultSubtitleStreamIndex'] as num?)?.toInt();

    String url;
    PlayMethod method;
    final transcodingUrl = src['TranscodingUrl'] as String?;
    if (src['SupportsDirectPlay'] == true && !wantsOtherAudio && transcodingUrl == null) {
      url = uri('/Videos/${item.id}/stream', {'static': true, 'mediaSourceId': msid, 'playSessionId': session, 'deviceId': deviceId, keyParam: token, 'container': src['Container']}).toString();
      method = PlayMethod.directPlay;
    } else if (transcodingUrl != null) {
      url = '$baseUrl$transcodingUrl';
      method = transcodingUrl.contains('/master.m3u8') && src['SupportsDirectStream'] == true && !transcodingUrl.contains('TranscodeReasons') ? PlayMethod.directStream : PlayMethod.transcode;
    } else {
      url = uri('/Videos/${item.id}/stream', {'static': true, 'mediaSourceId': msid, 'playSessionId': session, 'deviceId': deviceId, keyParam: token}).toString();
      method = PlayMethod.directPlay;
    }

    // A text subtitle the server delivers as a separate file: fetch it as WebVTT and draw it.
    String? subUrl;
    if (sub != null && sub >= 0) {
      final stream = ((src['MediaStreams'] as List?) ?? const []).cast<Map<String, dynamic>>().where((s) => s['Index'] == sub).firstOrNull;
      if (stream != null && stream['DeliveryMethod'] == 'External') {
        subUrl = uri('/Videos/${item.id}/$msid/Subtitles/$sub/0/Stream.vtt', {keyParam: token}).toString();
      }
    }
    return PlaybackPlan(url: url, method: method, playSessionId: session, mediaSourceId: msid, mediaSource: src, audioIndex: audio, subtitleIndex: sub, subtitleUrl: subUrl);
  }

  Map<String, dynamic> _report(Item item, PlaybackPlan p, Duration position, {bool paused = false}) => {
        'ItemId': item.id,
        'MediaSourceId': p.mediaSourceId,
        'PlaySessionId': p.playSessionId,
        'PositionTicks': position.inMilliseconds * ticksPerMs,
        'IsPaused': paused,
        'IsMuted': false,
        'CanSeek': true,
        'PlayMethod': p.methodName,
        'AudioStreamIndex': ?p.audioIndex,
        'SubtitleStreamIndex': ?p.subtitleIndex,
      };

  Future<void> reportStart(Item item, PlaybackPlan p, Duration position) => post('/Sessions/Playing', body: _report(item, p, position));
  Future<void> reportProgress(Item item, PlaybackPlan p, Duration position, {required bool paused}) =>
      post('/Sessions/Playing/Progress', body: {..._report(item, p, position, paused: paused), 'EventName': 'timeupdate'});
  Future<void> reportStopped(Item item, PlaybackPlan p, Duration position) => post('/Sessions/Playing/Stopped', body: _report(item, p, position));

  /// Intro / outro / recap segments ("Skip intro").
  Future<List<({String type, Duration start, Duration end})>> segments(String itemId) async {
    try {
      final j = await get('/MediaSegments/$itemId') as Map<String, dynamic>;
      return ((j['Items'] as List?) ?? const []).cast<Map<String, dynamic>>().map((s) {
        final st = ((s['StartTicks'] as num?) ?? 0).toInt() ~/ 10, en = ((s['EndTicks'] as num?) ?? 0).toInt() ~/ 10;
        return (type: '${s['Type']}', start: Duration(microseconds: st), end: Duration(microseconds: en));
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Trickplay tile sheet for the time `at` (null when the server has none for this item).
  ({String url, int col, int row, int tileW, int tileH, int cols})? trickplay(Item item, String mediaSourceId, Duration at) {
    final tp = item.raw['Trickplay'] as Map<String, dynamic>?;
    final bySource = tp?[mediaSourceId] as Map<String, dynamic>?;
    if (bySource == null || bySource.isEmpty) return null;
    final widths = bySource.keys.map(int.parse).toList()..sort();
    final w = widths.firstWhere((x) => x >= 320, orElse: () => widths.last);
    final info = bySource['$w'] as Map<String, dynamic>;
    final interval = (info['Interval'] as num).toInt(), cols = (info['TileWidth'] as num).toInt(), rows = (info['TileHeight'] as num).toInt();
    final count = (info['ThumbnailCount'] as num).toInt();
    final n = (at.inMilliseconds ~/ interval).clamp(0, count - 1);
    final perSheet = cols * rows;
    return (
      url: uri('/Videos/${item.id}/Trickplay/$w/${n ~/ perSheet}.jpg', {'mediaSourceId': mediaSourceId, keyParam: token}).toString(),
      col: (n % perSheet) % cols,
      row: (n % perSheet) ~/ cols,
      tileW: (info['Width'] as num).toInt(),
      tileH: (info['Height'] as num).toInt(),
      cols: cols,
    );
  }
}
