// Test hook for the direct-feed player: on the TV, /tmp/webos_native_player.autoplay holding
// "<itemId> [startMs] [direct] [sub=<stream index>]" opens that item in the player when the app starts ("direct" turns the
// direct-feed engine on; sub= picks a subtitle track).
export 'dev_autoplay_stub.dart' if (dart.library.io) 'dev_autoplay_io.dart';
