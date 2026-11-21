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

## Preview on the PC

The same code builds for the browser (no UDP discovery there; type the server address). The
browser preview uses the plain Flutter tool inside the toolchain:

```sh
.ref/flutter-webos/flutter/bin/flutter build web --release
python3 -m http.server 8099 --bind 127.0.0.1 --directory build/web   # open http://127.0.0.1:8099
```

Arrow keys, Enter and Escape stand in for the remote. Jellyfin answers browsers from other origins
(CORS `*`), so the preview talks to the server directly.
