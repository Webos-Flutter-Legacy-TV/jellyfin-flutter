// Test hook for the direct-feed player: on the TV, /tmp/webos_native_player.autoplay holding
// "<itemId> [startMs]" opens that item in the direct player when the app starts.
export 'dev_autoplay_stub.dart' if (dart.library.io) 'dev_autoplay_io.dart';
