# Jellyfin Flutter TV

A Jellyfin client for LG webOS TVs written in Flutter, built with
[Webos-Flutter-Legacy-TV/flutter-webos](https://github.com/Webos-Flutter-Legacy-TV/flutter-webos)
(`--legacy` packages for older TVs). First target: webOS 6.

The first version follows the official Jellyfin webOS app's design; it gets its own look later.

## Plan

1. `docs/jellyfin-api.md`: the parts of the Jellyfin API a TV client uses.
2. `docs/design-analysis.md`: how the official webOS app looks and behaves.
3. Mockups of each screen, for approval.
4. The app, screen by screen.

## Build

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

On the user's LG C1 (webOS 6.5.3) the app's logical screen is 1920×1080, the size the mockups use.

## Releases

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

A release carries `com.sostk.jellyfintv_<version>_webos-legacy.ipk` (webOS 6 and older),
`com.sostk.jellyfintv_<version>_webos26.ipk`, `SHA256SUMS`, the icon and
`com.sostk.jellyfintv.manifest.json` (webosbrew's app-repository format, for the legacy package).
The workflow builds with flutter-webos `main` (a manual run can name another branch or tag) and
accepts the LG SDK License Agreement for the webOS NDK, as flutter-webos's own CI does.

## Preview on the PC

The same code builds for the browser (no UDP discovery there; type the server address). The
browser preview uses the plain Flutter tool inside the toolchain:

```sh
.ref/flutter-webos/flutter/bin/flutter build web --release
python3 -m http.server 8099 --bind 127.0.0.1 --directory build/web   # open http://127.0.0.1:8099
```

Arrow keys, Enter and Escape stand in for the remote. Jellyfin answers browsers from other origins
(CORS `*`), so the preview talks to the server directly.
