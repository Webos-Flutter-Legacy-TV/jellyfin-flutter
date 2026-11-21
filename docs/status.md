# Status (2026-11-21, evening)

What the app does compared with the official Jellyfin webOS app (see `design-analysis.md`).
"PC" means checked in the browser preview against the user's server; "TV" on the LG C1.

| Area | Official app | This app | Checked |
| --- | --- | --- | --- |
| Connect to a server | Address field, found servers | Found (UDP 7359) and saved servers, typed address (https, then http :8096) | TV, PC |
| Sign in | Password, Quick Connect, user avatars | Quick Connect beside the password form; public users as chips | TV (code shown), PC (signed in) |
| Users | Select server / user | Several users per server stay signed in; "Who's watching?" at start and from Settings; Add user, Sign out per user | PC |
| Home | My media, Continue watching, Next up, Recently added (user's order) | Hero for the title to continue, then the same sections in the user's order; libraries and Favorites as tabs | PC |
| Library | Tabs, grid, sort, filter, A–Z | All, Suggestions, Upcoming (shows), Favorites, Collections (movies), Genres, Networks (shows); sort and filter chips; A–Z jump | PC |
| Movie / episode details | Poster, meta, actions, tracks, people, more like this | Backdrop, logo, badges, tagline, actions, track tiles, cast, Extras, More from this season, More like this; Trailer when local | PC |
| Series | Next up, seasons, cast | Resume / Shuffle, season tabs, episode row with summary, cast | PC |
| Person | Photo, bio, titles | Same, with birth date and place | PC |
| Search | Field and grouped results | Own keyboard, grouped results, recent searches | PC |
| Favorites | Home tab | Rows of movies, shows, episodes, collections, people | PC |
| Playlists, collections | Lists | Lists that play in order or shuffled | PC |
| More menu | Admin actions first, Delete focused | Viewer actions first; Manage (refresh, delete with confirm) | PC |
| Audio / subtitles | Dropdowns | Side panel; server converts when another audio track is picked; text subtitles drawn by the app | PC |
| Player | OSD, seek, tracks, settings | OSD, seek with trickplay and chapters, Skip intro/recap/credits, Up next, speed, quality, favourite, progress reports | PC (browser, server converts) |
| Settings | Many web forms | Only TV settings: quality, languages, auto-play next, intro skipping, seek step, subtitle look (size, colour, background, position, with a preview), screensaver, account | PC |
| Live updates, casting | Remote control from other clients | WebSocket session: Play on this TV from a phone, pause/seek/stop, track changes, messages, Go home; watched state refreshes | PC |
| Offline / start-up | — | Last Home shown at once from cache, images cached on disk (300 MB), offline banner | PC |
| Screensaver | Backdrops | Library backdrops with logo and clock after idle minutes; never during a video; the waking key does nothing else | PC |
| Releases | — | GitHub Actions builds the IPK, checks it against webOS 5+ firmware symbols, releases tags with a Homebrew Channel manifest | Local build and check |

## Not in this app (yet)

- Music, books, photos, Live TV, SyncPlay, picture-in-picture (no such libraries on the user's server;
  SyncPlay and PiP are not TV features we need now).
- Server administration (dashboard, editing metadata or images): done in a browser.

## To check on the TV

- Playback through the TV's video plane: direct play of HEVC / Dolby Vision / E-AC-3, the server's
  HLS when audio is converted, seeking times on webOS 6.
- Text subtitles over the video plane.
- The sign-in keyboard fix and focus on every page with the real remote.
- Back on the remote waking the screensaver (it arrives as a route pop on the TV).
- Remote control from a phone (Play on), with the TV's video plane.
- Frame rate of the scrims, scaling cards and side panels on the C1's GPU.
