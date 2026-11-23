# Jellyfin TV

An unofficial [Jellyfin](https://jellyfin.org) client for **LG webOS TVs**, made with Flutter.
Watch the movies and shows on your own Jellyfin server with screens made for the TV remote, on
new LG TVs and on older ones (webOS 6, the 2021 models, and earlier).

**[Download the latest release](https://github.com/Webos-Flutter-Legacy-TV/jellyfin-flutter/releases/latest)**
· [What changed](CHANGELOG.md)

Its look follows the official Jellyfin webOS app for now; its own design comes later. Not
affiliated with or endorsed by the Jellyfin project or LG Electronics.

## Features

**Browse**
- Home that follows your Home layout from the other Jellyfin apps: continue watching, next up,
  recently added, your libraries.
- Libraries with sorting, filters, an A-Z jump, Suggestions, Upcoming, Collections, Genres and
  Networks tabs.
- Details for movies, series, seasons and episodes: cast, extras, trailers, more like this.
- People pages, favourites, collections and playlists (play in order or shuffled).
- Search with its own on-screen keyboard, results grouped by type, recent searches.

**Watch**
- The next episode plays by itself; skip intro and recap (a button, automatic, or off).
- Chapters and preview pictures on the seek bar, how far the stream is buffered.
- Audio and subtitle tracks, subtitle look (size, colour, background, position, with a preview).
- Playback speed and quality, a Playback info panel.

**Direct-feed player** (Settings → Playback → Player engine → Direct feed): the app reads the file
itself and hands it to the TV's own decoders, so the server does not convert anything.
- 4K HDR and **Dolby Vision**, including UHD Blu-ray Dolby Vision (profile 7), which the TV
  otherwise shows as plain HDR.
- **DTS, TrueHD** and other sound the TV cannot play itself, turned into Dolby Digital Plus 5.1;
  Dolby Atmos passed through.
- **AV1** videos.
- Subtitles inside the file: Blu-ray picture subtitles (**PGS**), styled anime subtitles (**ASS**,
  with the file's fonts), and SRT in your own subtitle style.
- Switch audio track while the video plays; speed 0.5x-2x with natural voices; audio delay
  (lip-sync) from -500 to +500 ms.
- If a title does not play this way, it carries on with the TV's own player.

**Around the app**
- Several people on one TV: "Who's watching?", add, switch and sign out per user.
- Cast to the TV from a phone or another Jellyfin app, and control it from there; watched state
  updates live.
- Magic Remote: point and click, scroll with the wheel, rows scroll by themselves when the pointer
  rests at either end.
- Starts fast: the last Home shows at once, pictures are kept on the TV.
- Screensaver with drifting backdrops from your libraries and the time (never during a video).

## Which TVs

| TV | Package | Tested |
| --- | --- | --- |
| webOS 6 and older (LG TVs up to 2021, e.g. C1, CX, B9) | `…_webos-legacy.ipk` | LG C1, webOS 6.5.3 |
| webOS 26 (LG TVs from 2026) | `…_webos26.ipk` | not yet on a TV |

Find your version on the TV under **Settings → General → About This TV**. Other webOS versions have
not been tried yet. You also need a Jellyfin server the TV can reach (tested with Jellyfin 12.0).

## Install

Download the package for your TV from the
[latest release](https://github.com/Webos-Flutter-Legacy-TV/jellyfin-flutter/releases/latest), then
either:

- **Developer Mode** (any LG TV): install LG's *Developer Mode* app on the TV and turn it on, then
  use [webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop) (pick the file) or the
  [webOS CLI](https://webostv.developer.lge.com/develop/tools/cli-installation):
  `ares-install -d <tv> com.sostk.jellyfintv_<version>_webos-legacy.ipk`.
- **Homebrew Channel** (rooted TVs): each release carries `com.sostk.jellyfintv.manifest.json` in
  the webosbrew app-repository format.

Installing a newer version keeps your servers, users and settings.

## How to use

1. **Open Jellyfin TV.** Servers on your home network are found by themselves; otherwise type the
   server's address (for example `http://192.168.1.10:8096`).
2. **Sign in** with your user and password, or with **Quick Connect**: enter the code shown on the
   TV in another Jellyfin app. Add more people later under *Who's watching?*.
3. **Pick something** on Home or in a library and press OK.
4. **For 4K HDR, Dolby Vision, DTS or TrueHD files**, turn on Settings → Playback → Player engine →
   **Direct feed**.

### Remote

| Button | Browsing | In the player |
| --- | --- | --- |
| Arrows | Move | Left / Right: back 10 s / forward 30 s (the steps are in Settings); Up / Down: show the controls |
| OK | Open | Pause / play |
| Back | Go back; twice on Home to leave | Hide the controls, then leave the player |
| Play/Pause, Stop, Rewind, Fast forward, Next | | As labelled; Next plays the next episode |
| Channel up / down | Page up / down in lists | |
| Magic Remote pointer and wheel | Point, click, scroll; rest at a row's end to scroll it | Point and click the controls |

The player's controls: favourite, **Playback info**, back / play / forward, **Subtitles**,
**Audio**, and **Speed and quality** (speed, audio delay with the direct-feed player, quality).

## Settings

- **Playback**: quality, preferred audio and subtitle languages, play the next episode, intro and
  recap skipping, seek steps, **Player engine** (TV player or Direct feed).
- **Subtitles**: size, colour, background and position, with a live preview.
- **Screen**: screensaver and how soon it starts.
- **Account**: users on this TV, sign out.

## Troubleshooting

- **A title does not play with Direct feed:** it switches to the TV's own player by itself; you can
  also set Player engine back to TV player. The Playback info panel shows what the TV is doing.
- **"The TV's video decoder is in use":** another app is playing video; close it and try again.
- **"Could not open the stream: 404":** the server cannot read the file (for example a library
  drive that is offline). Check the file in the Jellyfin dashboard.
- **Going back a few seconds lands a little later** on some Blu-ray files: the picture can only
  restart at certain frames.
- Known issues for each version are in the [changelog](CHANGELOG.md).

## Built on

- [Flutter](https://flutter.dev) with LG's Flutter for webOS and the community
  [flutter-webos](https://github.com/Webos-Flutter-Legacy-TV/flutter-webos) legacy package, which
  makes Flutter apps run on webOS 6 and older.
- [Webos-Flutter-Legacy-TV plugins](https://github.com/Webos-Flutter-Legacy-TV/plugins), including
  `webos_native_player`, the direct-feed player (FFmpeg reads the file, the TV's decoders play it,
  libass draws styled subtitles).
- The [Jellyfin](https://jellyfin.org) server API.

---

## Development

### Build

The toolchain lives in `.ref/flutter-webos` (a clone of
[Webos-Flutter-Legacy-TV/flutter-webos](https://github.com/Webos-Flutter-Legacy-TV/flutter-webos),
not committed). Setting it up installs the LG webOS NDK under the LG SDK License Agreement.

```sh
git clone https://github.com/Webos-Flutter-Legacy-TV/flutter-webos.git .ref/flutter-webos
(cd .ref/flutter-webos/legacy-webos && WEBOS_NDK_ACCEPT_EULA=1 ./setup.sh)
. .ref/flutter-webos/legacy-webos/env.sh
flutter-webos build webos --release --legacy
#   build/webos-compat/release/com.sostk.jellyfintv_<version>_arm.ipk   webOS 6 and older
#   build/webos/arm/release/ipk/com.sostk.jellyfintv_<version>_arm.ipk  webOS 26
ares-install -d tv build/webos-compat/release/com.sostk.jellyfintv_*_arm.ipk
```

On an LG C1 (webOS 6.5.3) the app's logical screen is 1920×1080, the size the designs use.

To work on `webos_native_player` alongside the app, point the dependency at a local plugins clone
with an untracked `pubspec_overrides.yaml` (`dependency_overrides: webos_native_player: path:
../plugins/packages/webos_native_player`); remove it and run `flutter pub upgrade
webos_native_player` before committing, so `pubspec.lock` points at GitHub again.

### Releases

`tools/release.py` builds and releases the app; `.github/workflows/release.yml` does the same on
GitHub. Every push to main builds both IPKs and keeps them as a workflow artifact; a version tag
publishes a GitHub release.

```sh
tools/release.py check            # what the next release would contain
tools/release.py build            # dist/: both IPKs, SHA256SUMS, icon, Homebrew manifest, build-info.json
tools/release.py notes            # the release description, as GitHub will show it
tools/release.py release 0.2.0    # version + changelog + commit + tag, then push: the workflow publishes
```

Write what changed under `[Unreleased]` in [CHANGELOG.md](CHANGELOG.md) (New, Improved, Fixed,
Known issues, in words a TV viewer understands). `release` moves it under the new version, and the
release description is built from that section plus which file is for which TV, how to install,
the exact flutter-webos and plugins commits, checksums and every commit since the last release.
The workflow builds with flutter-webos `main` (a manual run can name another branch or tag) and
accepts the LG SDK License Agreement for the webOS NDK, as flutter-webos's own CI does.

### Preview on the PC

The same code builds for the browser (no UDP discovery there; type the server address):

```sh
.ref/flutter-webos/flutter/bin/flutter build web --release
python3 -m http.server 8099 --bind 127.0.0.1 --directory build/web   # open http://127.0.0.1:8099
```

Arrow keys, Enter and Escape stand in for the remote. Jellyfin answers browsers from other origins
(CORS `*`), so the preview talks to the server directly.

### Layout

- `lib/api/` — Jellyfin API client, playback plans, server discovery.
- `lib/screens/` — Home, library, details, search, player, settings and the other screens.
- `lib/player/engine.dart` — the two playback engines (TV player, direct feed).
- `lib/ui/` — TV widgets: focusable cards, rows, edge scrolling, panels.
- `docs/` — the Jellyfin API a TV client uses, design analysis, status against the official app.
- `tools/` — version and release tools.
