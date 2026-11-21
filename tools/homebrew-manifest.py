#!/usr/bin/env python3
"""Writes the webOS Homebrew Channel manifest for a built IPK.

  tools/homebrew-manifest.py IPK --ipk-url URL --icon-url URL [--source-url URL] -o OUT.json

Homebrew Channel installs from a manifest like this one (the format webosbrew's
apps repository uses): it downloads ipkUrl and checks the SHA-256 before installing.
"""
import argparse
import hashlib
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

ap = argparse.ArgumentParser()
ap.add_argument("ipk")
ap.add_argument("--ipk-url", required=True)
ap.add_argument("--icon-url", required=True)
ap.add_argument("--source-url", default="https://github.com/Webos-Flutter-Legacy-TV/jellyfin-flutter")
ap.add_argument("-o", "--out", required=True)
a = ap.parse_args()

info = json.loads((ROOT / "webos/meta/appinfo.json").read_text())
ipk = pathlib.Path(a.ipk)
sha = hashlib.sha256(ipk.read_bytes()).hexdigest()
manifest = {
    "id": info["id"],
    "version": info["version"],
    "type": info.get("type", "native"),
    "title": info["title"],
    "appDescription": "Jellyfin client for LG TVs (webOS 5 and newer), built with Flutter",
    "iconUri": a.icon_url,
    "sourceUrl": a.source_url,
    "rootRequired": False,
    "ipkUrl": a.ipk_url,
    "ipkHash": {"sha256": sha},
    "ipkSize": ipk.stat().st_size,
}
pathlib.Path(a.out).write_text(json.dumps(manifest, indent=2) + "\n")
print(f"{a.out}: {manifest['id']} {manifest['version']} sha256 {sha}")
