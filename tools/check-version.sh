#!/usr/bin/env bash
# Prints the app version; fails if pubspec.yaml, appinfo.json and the app disagree
# (or, given one, if they differ from the expected version, e.g. the release tag).
set -euo pipefail
cd "$(dirname "$0")/.."
p=$(sed -n 's/^version: \([0-9.]*\).*/\1/p' pubspec.yaml)
a=$(python3 -c 'import json;print(json.load(open("webos/meta/appinfo.json"))["version"])')
c=$(sed -n "s/^const appVersion = '\([^']*\)';/\1/p" lib/api/client.dart)
want=${1:-$p}
if [ "$p" != "$want" ] || [ "$a" != "$want" ] || [ "$c" != "$want" ]; then
  echo "version mismatch: wanted $want; pubspec.yaml $p, appinfo.json $a, lib/api/client.dart $c" >&2
  exit 1
fi
echo "$want"
