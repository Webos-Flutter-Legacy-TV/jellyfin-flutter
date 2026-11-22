// Test hook for the direct-feed player: on the TV, /tmp/webos_native_player.autoplay holding
// "<itemId> [startMs] [direct]" opens that item in the player when the app starts ("direct" turns the direct-feed engine on).
export 'dev_autoplay_stub.dart' if (dart.library.io) 'dev_autoplay_io.dart';
