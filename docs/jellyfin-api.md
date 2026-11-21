# Jellyfin API for a TV client

Checked against the user's server, **Jellyfin 12.0.0** (`GET /System/Info/Public`), using its own
OpenAPI document (`GET /api-docs/openapi.json`, 321 paths). Only the parts a TV client needs are
listed. Paths are relative to the server's base URL, e.g. `http://192.168.x.y:8096`.

## Identifying the client

Every request carries one header (the OpenAPI security scheme `CustomAuthentication`):

```
Authorization: MediaBrowser Client="Jellyfin Flutter TV", Device="LG webOS TV",
               DeviceId="<stable random id>", Version="<app version>", Token="<access token>"
```

- `Token` is left out before login.
- `DeviceId` must stay the same across launches: the server ties sessions, QuickConnect and
  "resume on another device" to it. It is generated once and stored.
- The server lists the client under Dashboard > Devices with this name and device.

## Finding the server

| Step | Request | Notes |
| --- | --- | --- |
| Discovery on the LAN | UDP broadcast `Who is JellyfinServer?` to port 7359 | Servers answer with JSON: `Address`, `Id`, `Name` |
| Check an address | `GET /System/Info/Public` | `ServerName`, `Version`, `Id`, `StartupWizardCompleted`; no login needed |
| Login screen text | `GET /Branding/Configuration` | `LoginDisclaimer`, `CustomCss` (ignored), `SplashscreenEnabled` |

An address typed without a scheme or port is tried as `http://host:8096` and `https://host:8920` first,
then as typed.

## Signing in

| Purpose | Request | Body / result |
| --- | --- | --- |
| Users to show as avatars | `GET /Users/Public` | `Name`, `Id`, `PrimaryImageTag`, `HasPassword` |
| User avatar | `GET /Users/{id}/Images/Primary` (12.0: `GET /UserImage?userId=`) | |
| Password login | `POST /Users/AuthenticateByName` | `{"Username", "Pw"}` → `AuthenticationResult`: `AccessToken`, `User`, `ServerId`, `SessionInfo` |
| Is QuickConnect on? | `GET /QuickConnect/Enabled` | `true` / `false` |
| Start QuickConnect | `POST /QuickConnect/Initiate` | `Code` (shown on the TV), `Secret` |
| Poll it | `GET /QuickConnect/Connect?secret=` | `Authenticated` turns true when approved in another client |
| Finish it | `POST /Users/AuthenticateWithQuickConnect` | `{"Secret"}` → `AuthenticationResult` |
| Current user | `GET /Users/Me` | checks a stored token is still valid |
| Sign out | `POST /Sessions/Logout` | |

QuickConnect matters on a TV: no typing a password with the remote.

On the user's server QuickConnect is enabled and `/Users/Public` is empty (users are hidden), so
the login screen must offer QuickConnect and a typed user name, not only avatars.

## Home screen

The official clients build Home from these sections (order is a user setting, see Display
preferences below):

| Section | Request |
| --- | --- |
| My Media (libraries) | `GET /UserViews?userId=` → `CollectionType`: `movies`, `tvshows`, `music`, `boxsets`, `livetv`, `homevideos`, `playlists`… |
| Continue Watching | `GET /UserItems/Resume?userId=&mediaTypes=Video&limit=` |
| Next Up | `GET /Shows/NextUp?userId=&limit=&enableResumable=false` |
| Latest in each library | `GET /Items/Latest?userId=&parentId=<library>&limit=16` (episodes grouped by series) |
| Live TV now | `GET /LiveTv/Programs/Recommended?isAiring=true` (only with a Live TV library) |

Useful on all list requests: `fields=PrimaryImageAspectRatio,Overview`, `enableImageTypes=Primary,Backdrop,Thumb`,
`imageTypeLimit=1`, `enableUserData=true` (played state, progress, favourite).

## Browsing a library

`GET /Items` is the general query:

| Parameter | Use |
| --- | --- |
| `parentId` | the library (or folder) |
| `includeItemTypes` | `Movie`, `Series`, `BoxSet`, `MusicAlbum`… |
| `recursive=true` | everything under the library, not just its top folder |
| `sortBy` / `sortOrder` | `SortName`, `DateCreated`, `PremiereDate`, `CommunityRating`, `Random`…; `Ascending` / `Descending` |
| `filters` | `IsUnplayed`, `IsPlayed`, `IsFavorite`, `IsResumable` |
| `genres`, `years`, `officialRatings` | filters |
| `nameStartsWith` | the A-Z jump bar |
| `startIndex`, `limit`, `enableTotalRecordCount` | paging (a grid loads in pages of ~100) |

Genres: `GET /Genres?parentId=`. Collections: `includeItemTypes=BoxSet`.

## Details

| Data | Request |
| --- | --- |
| The item | `GET /Items/{id}?userId=` with `fields=Overview,Genres,People,Studios,MediaSources,MediaStreams,Chapters,Trickplay,Taglines,RemoteTrailers,ProviderIds` |
| Seasons of a series | `GET /Shows/{seriesId}/Seasons?userId=` |
| Episodes | `GET /Shows/{seriesId}/Episodes?seasonId=&userId=&fields=Overview` |
| Next episode to watch | `GET /Shows/NextUp?seriesId=` |
| More like this | `GET /Items/{id}/Similar?limit=12` |
| Extras | `GET /Items/{id}/SpecialFeatures`, local trailers through `LocalTrailerCount` |
| Cast photos | `GET /Persons/{name}/Images/Primary`, or `Items/{personId}/Images/Primary` with the `PrimaryImageTag` from `People` |
| Favourite | `POST` / `DELETE /UserFavoriteItems/{id}` |
| Watched | `POST` / `DELETE /UserPlayedItems/{id}` |

## Images

`GET /Items/{id}/Images/{type}` with `type` one of `Primary` (poster), `Backdrop`, `Thumb` (16:9
card), `Logo`, `Banner`, `Art`.

- Size it on the server: `fillWidth`/`fillHeight` (crop to fill), or `maxWidth`/`maxHeight`; `quality=90`.
- Always send `tag=<ImageTags[type]>`: the URL then changes when the image changes, so it can be
  cached for long.
- Episodes without a thumb use the series' (`SeriesId` + `SeriesPrimaryImageTag`), or the parent's
  backdrop (`ParentBackdropItemId` + `ParentBackdropImageTags`).
- `blur=` gives a server-side blurred copy (cheap backgrounds on a TV).

## Playback

1. **Ask how to play:** `POST /Items/{id}/PlaybackInfo?userId=` with `PlaybackInfoDto`:
   `DeviceProfile` (what the TV decodes), `MaxStreamingBitrate`, `StartTimeTicks`,
   `AudioStreamIndex`, `SubtitleStreamIndex`, `MediaSourceId`, `EnableDirectPlay/DirectStream/Transcoding`.
   The answer has `MediaSources` and a `PlaySessionId`.
2. **Pick the URL** from the chosen `MediaSourceInfo`:
   - `SupportsDirectPlay`: `GET /Videos/{id}/stream?static=true&mediaSourceId=&playSessionId=&api_key=`
     (the file as it is).
   - otherwise `TranscodingUrl` (an HLS playlist the server builds; relative, add the base URL).
     The HLS routes are not in the 12.0 OpenAPI document, so the client uses this URL as given.
3. **Report:** `POST /Sessions/Playing` at start, `POST /Sessions/Playing/Progress` every ~10 s
   and on pause/seek/track change, `POST /Sessions/Playing/Stopped` at the end. Bodies are
   `PlaybackStartInfo` / `PlaybackProgressInfo`: `ItemId`, `MediaSourceId`, `PlaySessionId`,
   `PositionTicks`, `IsPaused`, `PlayMethod` (`DirectPlay`, `DirectStream`, `Transcode`),
   `AudioStreamIndex`, `SubtitleStreamIndex`. This is what keeps Continue Watching and played state
   right.
4. **Times are ticks:** 1 tick = 100 ns, so seconds × 10 000 000.

### The device profile

The server decides direct play vs transcode from the `DeviceProfile`. For an LG webOS 6 TV
(measured on the user's C1, see the CloudStream project's notes):

- Containers: mp4, m4v, mkv, webm, ts, mov.
- Video: h264, hevc (incl. 10-bit, HDR10, Dolby Vision), vp9, av1.
- Audio: aac, mp3, ac3, eac3 (Atmos passes through over eARC), flac, opus, vorbis. **No TrueHD,
  no DTS** on webOS 6: those must be transcoded (to eac3, not ac3, to keep 5.1/7.1).
- Transcoding target: HLS, fMP4 segments, h264/hevc + aac/eac3.
- Subtitles: srt/vtt rendered by the app (`DeliveryMethod: External`), ass/ssa as text or burned in,
  PGS burned in.

What the Flutter `video_player` plugin on webOS actually plays decides the final profile; it is
measured on the TV before the profile is written.

### Subtitles, chapters, skipping, trickplay

| Feature | Request |
| --- | --- |
| External subtitle | `GET /Videos/{id}/{mediaSourceId}/Subtitles/{index}/Stream.vtt` (or `.srt`) |
| Chapters | `Chapters` field on the item (`StartPositionTicks`, `Name`, `ImageTag`) |
| Skip intro / credits | `GET /MediaSegments/{id}` → `Type` `Intro`, `Outro`, `Recap`, `Preview`, `Commercial` with start/end ticks |
| Seek thumbnails | `Trickplay` field on the item, then `GET /Videos/{id}/Trickplay/{width}/{index}.jpg` (tile sheets) |

## Search

- `GET /Search/Hints?searchTerm=&limit=` for suggestions while typing.
- `GET /Items?searchTerm=&recursive=true&includeItemTypes=Movie,Series,Episode,Person` for
  results grouped by type (what the web client shows).

## Settings stored on the server

`GET` / `POST /DisplayPreferences/usersettings?userId=&client=emby` holds the web client's Home
layout (`CustomPrefs.homesection0`…`homesection9`: `smalllibrarytiles`, `resume`, `nextup`,
`latestmedia`, `livetv`, `none`…). Reading it lets this app show Home in the order the user set
in the official clients.

## Live updates (later)

`ws(s)://server/socket?api_key=&deviceid=` sends `UserDataChanged`, `LibraryChanged`, `Play`,
`Playstate` and `GeneralCommand` messages (remote control from another client). Not needed for the
first version.
