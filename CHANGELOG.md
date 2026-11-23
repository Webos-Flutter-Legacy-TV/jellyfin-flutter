# Changelog

What changed in each release of Jellyfin TV, written for the people using it. `tools/release.py`
turns a version's section into its GitHub release description.

Sections: **New** (things you can do that you could not before), **Improved**, **Fixed**,
**Known issues**. Add entries under `[Unreleased]` as you go; `tools/release.py prepare X.Y.Z`
moves them under the new version.

## [Unreleased]

### New

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
