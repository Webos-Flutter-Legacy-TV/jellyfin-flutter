# The official Jellyfin webOS app: design analysis

## What the official app is

`jellyfin/jellyfin-webos` is a thin webOS wrapper. After the user picks a server it loads that
server's **jellyfin-web** in **TV layout** (jellyfin-web switches to it on a `Web0S` user agent).
So "the official webOS design" is jellyfin-web's TV layout with the dark theme.

The screenshots in [`design/official/`](design/official/) were taken on 2026-11-21 from the user's
Jellyfin 12.0.0 server. jellyfin-web was rendered at 1920×1080 with the webOS user agent, signed in
with QuickConnect. They are the user's own library and are kept as reference only.

Sizes below are measured on those 1920×1080 screenshots (the TV's UI resolution).

## Overall look

| Property | Value |
| --- | --- |
| Background | `#101010` (`$background-default`, dark theme) |
| Header bar | `#202020` (`$background-paper`), 117 px tall, full width, not transparent |
| Accent | `#00a4dc` (Jellyfin blue): focus ring, primary buttons, progress bars, badges |
| Text | white for titles, ~70% white for secondary lines |
| Font | Arial / Helvetica (system sans); TV layout sets the root size to 125% → 27 px body text at 1080p |
| Section titles | 48.6 px (1.8 em), regular weight, ~70% white |
| Margins | content starts 64 px from the left edge; rows bleed off the right edge |
| Corners | small (≈ 6–10 px) on cards and buttons |
| Motion | almost none: focus jumps, rows scroll with a short ease |

The look is flat and plain: no backdrop art behind Home or libraries, no blur, no gradients except
the login background.

## Focus and navigation

- D-pad spatial navigation: up/down between rows, left/right within a row.
- The focused card gets a **thick accent ring** (≈ 12 px, rounded) around the image; nothing else
  changes (no scale, no shadow).
- Focused buttons and list rows fill with the accent colour (Settings rows, Play button).
- Focused text links (tags, genres) get an accent highlight box.
- Moving down into a row focuses its **first** card; the page scrolls so the focused row sits in
  the upper part of the screen.
- Rows scroll sideways under focus; the last visible card is cut by the right edge, as a hint that
  there is more.
- Back goes to the previous page; the header has explicit Back and Home buttons on inner pages.

## Header (every page except the player)

| Part | Home | Inner pages |
| --- | --- | --- |
| Left | Jellyfin logo | Back arrow, Home icon, page title (e.g. "Movies") |
| Centre | Tabs: **Home**, **Favorites** | The library's tabs (Movies: Movies, Suggestions, Favorites, Collections, Genres; Shows: Shows, Suggestions, Upcoming, Genres, TV Networks) |
| Right | SyncPlay (people icon), Search, User, clock ("12:26 PM") | same |

The active tab is bold white; others are bold grey. The details page has no title or tabs.

## Screens

### Connect to a server (`30-wrapper-server`)

The wrapper's own page, before jellyfin-web loads: the Jellyfin logo (gradient mark and wordmark)
centred, one address field (placeholder `http://jellyfin.local:8096`), an "Automatically connect on
app launch" checkbox and a full-width **Connect** button. Servers found on the network are listed
above the field when there are any. No artwork, browser-default form controls.

### Login (`01-login`, `02-quickconnect`)

- Background: the server's splash image (a tilted poster wall) under a dark scrim. It is a server
  setting (`SplashscreenEnabled`); without it the background is plain.
- Logo top left. Centred title "Please sign in".
- Full-width (≈ 1460 px) form: User field, Password field, "Remember Me" checkbox.
- Buttons stacked full width: **Sign In** (accent), **Use Quick Connect**, **Forgot Password** (grey
  `#353535`).
- Quick Connect is a full-screen page: title "Quick Connect", "Enter code 181187 to login", a
  **Got It** accent button. It signs in automatically once approved.
- Before login the app shows a server picker (wrapper's own page) and, when the server lists users,
  user avatars. The user's server lists none, so the login form is the first screen.

### Home (`03-home`, `05-home-scrolled`)

Vertical list of sections, each a title and a horizontal row:

1. **My Media**: one 16:9 card per library (≈ 393×220), the library's image with its name in large
  bold white text over it and again below the card. Libraries without an image get an accent tile
  with an icon (Playlists).
2. **Continue Watching**: 16:9 thumbnails (≈ 393×220) with an accent progress bar along the bottom;
  title and year (or `S1:E8 - Episode name`) centred below.
3. **Next Up**: same 16:9 cards; series name, then `S3:E72 - Episode 72`.
4. **Recently Added in Movies**, **Recently Added in Shows** (one row per library): portrait posters
  (≈ 241×362) with title and year below. Series show an unplayed-count badge (accent circle, top
  right); watched items show a check badge.

Cards are separated by ≈ 59 px. Long titles end with "…".

### Library (`08-movies-library`, `09-movies-library-focus`, `10-tv-library`)

- Header tabs as above.
- Toolbar row, centred: "1-43 of 43", Play all, Shuffle, View (grid), Sort (A→Z), Filter.
- Grid of portrait posters, **6 per row** (≈ 227×341), title and year below, 64 px left margin.
- **A–Z jump list** down the right edge (`#`, A … Z).
- Items without art show an accent-tinted tile with a TV icon.

### Movie details (`11-movie-details`, `12-movie-details-scrolled`)

- No backdrop in this setup (plain background).
- Poster on the left (≈ 480×720, x 96, y 113), fixed while the right column scrolls.
- Right column:
  - Title, 48 px bold.
  - Meta line: year, runtime ("1h 56m"), rating in an outlined box ("PG"), ★ community rating,
    critic score, "Ends at 2:23 PM".
  - Action row: **Play** (accent square ≈ 115×104), then icon buttons: Trailer, Played ✓,
    Favourite ♥, More ⋮.
  - Media rows: Video (text), Audio and Subtitles (full-width dropdowns showing the selected
    stream, e.g. "BTM TrueHD Atmos - English - Dolby TrueHD + Dolby Atmos - 7.1 - Default").
  - Tagline (larger), overview, "Tags:" (bold links), then Director / Writers / Studios / Genres as
    label–value rows with bold links.
- Further down: **Cast & Crew** (portrait photos), **More Like This**.

### Series details (`14-series-details`, `16-series-details-scrolled-more`)

Same layout as a movie, with:
- Meta: "2022 - Present", rating box, ★.
- Actions: Play, Trailer, Shuffle, Played, Favourite, More.
- No media rows.
- Sections: **Next Up** (one 16:9 episode card with progress), **Seasons** (portrait posters with
  unplayed badges), Cast & Crew, More Like This.

### Season (`22-season`, `23-season-episodes`)

- Same poster-left layout; title "House of the Dragon", subtitle "Season 3".
- Actions: Play, Shuffle, Played, Favourite, More; season overview.
- **Episode list**: one row per episode, 16:9 still (≈ 576×384) on the left, on the right
  "1. Salt and Sea, Fire and Blood" (48 px), meta ("1h 6m ★ 7.6 Ends at 1:26 PM") and the overview.
- The focused episode row gets a lighter panel (`#2b2b2b`) behind the whole row.

### Library tabs (`32-movies-suggestions`, `33-movies-genres`, `34-tv-upcoming`)

- **Suggestions**: Home-style rows for the library: Continue Watching, Recently Added, then
  "Because you watched …" rows.
- **Genres**: one row per genre, titled "Action ›" (the title opens the genre).
- **Upcoming**: episodes airing soon; empty here ("Nothing here." with a hint about metadata).
- **Favorites** (Home tab): rows per type; the page rendered empty while loading.

### Episode details (`37-episode-details`)

16:9 still where the poster usually is; series name as title, "Season 4 - 10. Being Alive" below,
air date, runtime, ★, "Ends at". Actions: Play, Play from start, Played (red check when played),
Favourite, More. Media rows (Video, Audio, Subtitles dropdown), overview, people, then "More from
Season 4".

### Person (`38-person`)

Portrait photo left, name, Favourite and More buttons, biography, "Born", "Birth place", then their
items grouped by type (Movies, Shows).

### More menu (`39-more-menu`)

A centred list of actions with icons. For an admin it starts with **Delete media**, focused by
default, then Edit metadata, Edit images, Edit subtitles, Identify, Media Info, Refresh metadata.

### Search (`18-search-results`)

- Header title "Search".
- Search field with a magnifier icon, full width, accent outline when focused.
- Results grouped by type: **Shows**, **Movies**, **Episodes**, **People**…, each a section title
  with a row of cards like Home.

### Settings (`19-settings`, `41-settings-display`)

- Header title "Settings". User name as a large heading.
- List of rows with an icon and label: Profile, Quick Connect, Display, Home, Playback, Subtitles,
  Controls; then a "User" section (Sign out…).
- Focused row: full accent background; rows separated by thin grey lines.
- Sub-pages (Display, Home, Playback…) are long forms: section headings and full-width dropdowns
  with help text, the web client's forms at TV size.

### Player (`21-player-osd`)

- Video full screen. The on-screen display appears on any key and hides after a few seconds.
- Top: Back arrow, "Moana (2026)", SyncPlay icon, clock. Top and bottom fade to black.
- Bottom:
  - Seek bar across the width: elapsed ("0:00") left, remaining ("-1:55:41") right, accent knob,
    tick marks at chapters.
  - Buttons left: Previous chapter/replay, Rewind, **Play/Pause** (accent when focused), Fast
    forward, Next; "Ends at 2:24 PM".
  - Buttons right: Favourite, Subtitles (CC), Audio track (♪), Settings (quality, speed, aspect),
    Picture-in-picture.

## Where the official design falls short on a TV

| Area | Problem |
| --- | --- |
| Artwork | The server has backdrops, logos and thumbs, but Home and details show none of them: flat grey pages of posters and text. |
| Hierarchy | Every Home section has the same weight; nothing says "play this next". Section titles are grey and as large as the content. |
| Header | A solid 117 px bar on every page; SyncPlay sits next to Search; the clock and icons crowd the tabs. |
| Focus | A thick flat blue ring; no lift, no depth. Fine to find, but dated. |
| Details | Native dropdowns with raw stream names ("BTM TrueHD Atmos - English - Dolby TrueHD + Dolby Atmos - 7.1 - Default"); long tag clouds; the overview sits far down. |
| Seasons | One episode per 384 px row: three episodes per screen, lots of scrolling. |
| More menu | Admin actions first, **Delete** focused by default: one OK press away from deleting a film. |
| Forms | Settings are web forms (dropdowns, checkboxes) scaled up, not TV controls. |
| Empty states | "Nothing here." with a server-admin hint. |
| Type | Arial at one weight; little contrast between title, meta and body. |

## Our design: same app, more premium

Kept from the official app so it still feels like Jellyfin: the screens and their order, the
header tabs per library, Jellyfin blue as the accent, the same data on each page (nothing hidden),
QuickConnect, A–Z jump bar, D-pad behaviour.

Changed:
- **Artwork first.** Home opens on a hero for the item to continue (backdrop, logo, progress,
  Resume). Details pages sit on the item's backdrop with a scrim; the title logo replaces plain
  text when the server has one.
- **Depth.** Near-black ground (`#0b0d12`), raised surfaces (`#151922`, `#1d2230`), soft shadows.
  Focused cards scale up a little, get a 3 px white ring and a faint accent glow.
- **Type.** Inter (bundled), clear steps: 64 px titles, 34 px section titles in white semibold,
  27 px body, 22 px meta in 60% white.
- **Header.** Transparent over artwork, a slim row of tabs with a pill for the active one; Search
  and the user avatar on the right; the clock small. SyncPlay moves into the user menu.
- **Readable media info.** Badges (4K, Dolby Vision, HDR10, Atmos, 7.1) and a short track name
  ("English · TrueHD Atmos 7.1"); tracks change in a side panel, not a dropdown.
- **Episodes.** Season tabs above a horizontal row of episode cards (still, number, title,
  progress); the focused one shows its overview below.
- **Safe menus.** More menu lists viewer actions first; admin actions sit under "Manage" at the
  end, and Delete asks to confirm. Focus starts on the first viewer action.
- **TV settings.** Rows with the current value on the right; OK opens a side panel of choices.
- **Player.** Larger controls, chapter name and trickplay thumbnail while seeking, "Skip intro"
  from media segments, track panel on the right.

## What this means for the Flutter app

To look like the official app at first:
- Same palette (`#101010`, `#202020`, `#00a4dc`), Arial-like sans (Roboto is closest and is bundled
  with Flutter), 27 px body, 48 px section titles.
- Same header with tabs and icons, same card shapes and sizes, accent ring focus, flat surfaces.
- Same screen set and order: server → login / QuickConnect → Home → library grid → details →
  season → player; Search and Settings from the header.

Things the official app does that are left out at first: SyncPlay, picture-in-picture, Live TV,
music, photos, books, server administration.
