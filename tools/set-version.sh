#!/usr/bin/env bash
# Sets the app version everywhere it is written: pubspec.yaml, the webOS appinfo.json and
# the version the app reports to Jellyfin.   tools/set-version.sh 0.2.0
set -euo pipefail
v=${1:?usage: tools/set-version.sh X.Y.Z}
[[ $v =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must be X.Y.Z (webOS needs three numbers)" >&2; exit 1; }
cd "$(dirname "$0")/.."
build=$(sed -n 's/^version: .*+\([0-9]*\)$/\1/p' pubspec.yaml)
sed -i "s/^version: .*/version: $v+$((${build:-0} + 1))/" pubspec.yaml
sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$v\"/" webos/meta/appinfo.json
sed -i "s/^const appVersion = '[^']*';/const appVersion = '$v';/" lib/api/client.dart
tools/check-version.sh "$v"
