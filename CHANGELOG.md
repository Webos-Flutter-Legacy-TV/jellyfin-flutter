# Changelog

What changed in each release of Jellyfin TV, written for the people using it. `tools/release.py`
turns a version's section into its GitHub release description.

Sections: **New** (things you can do that you could not before), **Improved**, **Fixed**,
**Known issues** (the first release also has **About**, **Built on**, **How to use** and
**Features**). Add entries under `[Unreleased]` as you go; `tools/release.py prepare X.Y.Z`
moves them under the new version.

## [Unreleased]

## [0.1.0] - 2026-11-23

### About

The first release of **Jellyfin TV**, an unofficial [Jellyfin](https://jellyfin.org) client for
LG webOS TVs. It plays the movies and shows on your own Jellyfin server, with screens made for the
TV remote, and it also runs on older LG TVs (webOS 6, the 2021 models, and earlier). Its look
follows the official Jellyfin webOS app for now; its own design comes later.

### Built on

- [Flutter](https://flutter.dev), with LG's Flutter for webOS and the community
  [flutter-webos](https://github.com/Webos-Flutter-Legacy-TV/flutter-webos) legacy package, which
  makes Flutter apps run on webOS 6 and older.
- [Webos-Flutter-Legacy-TV plugins](https://github.com/Webos-Flutter-Legacy-TV/plugins), including
  `webos_native_player`: the app's own video player that reads the file with FFmpeg and feeds the
  TV's hardware decoders (subtitles drawn with libass).
- The [Jellyfin](https://jellyfin.org) server API. Not affiliated with or endorsed by the Jellyfin
  project or LG Electronics.

### How to use

1. **Install** the package for your TV (see *Which file do I need?* and *How to install* below).
2. **Open Jellyfin TV.** Servers on your home network are found by themselves; otherwise type the
   server's address (for example `http://192.168.1.10:8096`).
3. **Sign in** with your user and password, or with **Quick Connect** (enter the code shown on the
   TV in another Jellyfin app). Add more people later under *Who's watching?*.
4. **Watch.** Pick something on Home or in a library and press OK. In the player: Left / Right
   seek, OK pauses, Down opens the controls (audio, subtitles, speed and quality, playback info),
   Back hides the controls and then leaves.
5. **For 4K HDR, Dolby Vision, DTS or TrueHD files**, turn on **Settings → Playback → Player
   engine → Direct feed**: the TV then plays the original file without the server converting it.
   If a title does not play that way, it continues with the TV's own player.
6. **With a Magic Remote**, point and click anywhere; rest the pointer at either end of a row to
   scroll it.

Needs a Jellyfin server (tested with Jellyfin 12.0) reachable from the TV.

### Features

- Browse your Jellyfin server on an LG TV: Home (following your Home layout from the other
  Jellyfin apps), libraries with sorting, filters and an A-Z jump, search with its own on-screen
  keyboard, details for movies, series and episodes, people, favourites, collections and playlists.
- Several people on one TV: "Who's watching?", with add, switch and sign out for each user.
- Playback: next episode plays by itself, skip intro and recap (a button, automatic, or off),
  play all and shuffle, chapters and preview pictures on the seek bar.
- Subtitle look: size, colour, background and position, with a live preview.
- Cast to the TV and control it from another Jellyfin app; watched state updates live.
- Screensaver: drifting backdrops from your libraries with the time, after a few idle minutes
  (never during a video).
- Magic Remote: point and click, scroll with the wheel, and rows scroll by themselves when the
  pointer rests at either end.
- Direct-feed player (Settings → Playback → Player engine): the app reads the file itself and hands
  it to the TV's decoders, so the server does not have to convert anything:
  - 4K HDR and Dolby Vision, including Dolby Vision from UHD Blu-ray (profile 7), which the TV
    otherwise shows as plain HDR;
  - DTS, TrueHD and other sound the TV cannot play itself, turned into Dolby Digital Plus 5.1 on
    the TV, Dolby Atmos passed through;
  - AV1 videos;
  - subtitles inside the file, including Blu-ray picture subtitles (PGS) and styled anime
    subtitles (ASS), and SRT in your own subtitle style;
  - switching audio track while the video plays;
  - playback speed 0.5x to 2x with natural-sounding voices;
  - audio delay (lip-sync) from -500 to +500 ms;
  - a Playback info panel (what the TV is showing, audio path, bitrate, buffer).
  If the direct-feed player cannot play a title, it carries on with the TV's own player.

### Improved

- Smoother on older TVs (webOS 6): faster drawing and images kept on the TV between starts.

### Known issues

- The direct-feed player is new: if a title misbehaves, switch Player engine back to TV player.
- Going back a few seconds can land a little later than asked on some Blu-ray files (the picture
  can only restart at certain frames).
