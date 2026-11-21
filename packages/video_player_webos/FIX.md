# Local copy of video_player_webos

Copied from https://github.com/Webos-Flutter-Legacy-TV/plugins (packages/video_player, commit
a6310ed) with one change in `lib/video_player_webos.dart`:

The native player binds a slot to the exported window it was first initialised with and keeps
that for the process lifetime (NDL init is never repeated; legacy firmware cannot move the
window either). Disposing a player destroyed that window, so on webOS 6 the second video never
loaded: the media pipeline failed, the plugin disposed the player and the app's next call got
`PlatformException(Invalid argument, Player not found.)`. Disposed players now hand their window
to a pool that the next `create` reuses.

Upstream this to the plugins repository, then go back to the git dependency.
