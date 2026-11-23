#!/usr/bin/env python3
"""Build and release Jellyfin TV.

  tools/release.py build                 build both IPKs into dist/ (with checksums, manifest, build info)
  tools/release.py notes [--version X]   print the release description (from CHANGELOG.md, dist/, git)
  tools/release.py prepare X.Y.Z         set the version, date the changelog section, commit, tag vX.Y.Z
  tools/release.py publish [X.Y.Z]       push the branch and the tag: the Release workflow builds and publishes
  tools/release.py release X.Y.Z         prepare + publish (asks first unless --yes)
  tools/release.py check                 what the next release would say (Unreleased section, commits)

The build needs flutter-webos with legacy-webos set up (see README). It is found with
--flutter-webos DIR, $FLUTTER_WEBOS_DIR, .ref/flutter-webos or ../flutter-webos.
"""
import argparse
import datetime
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
CHANGELOG = ROOT / "CHANGELOG.md"
DEFAULT_REPO = "Webos-Flutter-Legacy-TV/jellyfin-flutter"
APP_NAME = "Jellyfin TV"

# Which IPK is which: (file suffix, where flutter-webos writes it, who it is for).
PACKAGES = [
    ("webos-legacy", "build/webos-compat/release/{id}_{v}_arm.ipk",
     "webOS 6 and older (LG TVs up to 2021, e.g. C1, CX, B9)"),
    ("webos26", "build/webos/arm/release/ipk/{id}_{v}_arm.ipk",
     "webOS 26 (LG TVs from 2026)"),
]

SECTION_TITLES = {  # changelog heading -> release heading
    "About": "👋 About",
    "Built on": "🧱 Built on",
    "How to use": "🚀 How to use",
    "Features": "✨ Features",
    "New": "✨ What's new",
    "Improved": "👍 Improved",
    "Fixed": "🐞 Fixed",
    "Known issues": "⚠️ Known issues",
}


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, text=True, **kw)


def out(cmd, **kw):
    return subprocess.run(cmd, check=True, text=True, capture_output=True, cwd=kw.pop("cwd", ROOT), **kw).stdout.strip()


def die(msg):
    print(f"release: {msg}", file=sys.stderr)
    sys.exit(1)


def appinfo():
    return json.loads((ROOT / "webos/meta/appinfo.json").read_text())


def app_version():
    return out(["tools/check-version.sh"])


# ---- changelog ----------------------------------------------------------------------------------

def changelog_section(version):
    """The body of '## [version]' (or '## [Unreleased]'), without the heading."""
    text = CHANGELOG.read_text() if CHANGELOG.exists() else ""
    m = re.search(r"^## \[" + re.escape(version) + r"\][^\n]*\n(.*?)(?=^## \[|\Z)", text, re.S | re.M)
    return m.group(1).strip() if m else None


def changelog_subsections(body):
    """'### Title' blocks of a section, in order: [(title, text)]."""
    parts = re.split(r"^### +(.+)$", body, flags=re.M)
    return [(parts[i].strip(), parts[i + 1].strip()) for i in range(1, len(parts), 2) if parts[i + 1].strip()]


def date_changelog(version):
    text = CHANGELOG.read_text()
    body = changelog_section("Unreleased")
    if not body or not changelog_subsections(body):
        die("CHANGELOG.md has nothing under [Unreleased]; write what changed first")
    if changelog_section(version) is not None:
        die(f"CHANGELOG.md already has a [{version}] section")
    today = datetime.date.today().isoformat()
    text = re.sub(r"^## \[Unreleased\][^\n]*\n", f"## [Unreleased]\n\n## [{version}] - {today}\n", text, count=1, flags=re.M)
    CHANGELOG.write_text(text)


# ---- git ----------------------------------------------------------------------------------------

def previous_tag(before=None):
    ref = f"{before}^" if before else "HEAD"
    try:
        return out(["git", "describe", "--tags", "--abbrev=0", "--match", "v[0-9]*", ref])
    except subprocess.CalledProcessError:
        return None


def commits(since, until="HEAD"):
    rng = f"{since}..{until}" if since else until
    log = out(["git", "log", "--no-merges", "--format=%h%x09%s", rng])
    return [tuple(line.split("\t", 1)) for line in log.splitlines() if line]


# ---- build --------------------------------------------------------------------------------------

def find_flutter_webos(arg):
    for cand in [arg, os.environ.get("FLUTTER_WEBOS_DIR"), ROOT / ".ref/flutter-webos", ROOT.parent / "flutter-webos"]:
        if cand and (pathlib.Path(cand) / "legacy-webos/env.sh").exists():
            return pathlib.Path(cand).resolve()
    die("flutter-webos not found: clone it to .ref/flutter-webos (README) or pass --flutter-webos DIR")


def plugin_refs():
    """Git dependencies from pubspec.lock: {package: (url, commit)}."""
    refs = {}
    blocks = re.split(r"^  (?=[\w]+:\n)", (ROOT / "pubspec.lock").read_text(), flags=re.M)
    for b in blocks:
        name = b.split(":", 1)[0].strip()
        if "source: git" not in b:
            continue
        url = re.search(r'url: "([^"]+)"', b)
        sha = re.search(r'resolved-ref: "?([0-9a-f]{7,40})"?', b)
        if url and sha:
            refs[name] = (url.group(1), sha.group(1))
    return refs


def cmd_build(a):
    fw = find_flutter_webos(a.flutter_webos)
    info, v = appinfo(), app_version()
    if not a.skip_build:
        print(f"building {APP_NAME} {v} with {fw}")
        run(["bash", "-c", f'. "{fw}/legacy-webos/env.sh" && flutter-webos build webos --release --legacy'], cwd=ROOT)
    tag = a.tag or f"v{v}"
    base = f"https://github.com/{a.repo}/releases/download/{tag}"
    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir()
    files = []
    for suffix, src, _ in PACKAGES:
        p = ROOT / src.format(id=info["id"], v=v)
        if not p.exists():
            die(f"missing {p.relative_to(ROOT)} (did the build run?)")
        dst = DIST / f"{info['id']}_{v}_{suffix}.ipk"
        shutil.copy2(p, dst)
        files.append(dst)
    shutil.copy2(ROOT / "webos/meta/icon.png", DIST / "icon.png")
    legacy = files[0]
    run([sys.executable, "tools/homebrew-manifest.py", str(legacy), "--ipk-url", f"{base}/{legacy.name}",
         "--icon-url", f"{base}/icon.png", "--source-url", f"https://github.com/{a.repo}",
         "-o", str(DIST / f"{info['id']}.manifest.json")], cwd=ROOT)
    sums = [f"{hashlib.sha256(f.read_bytes()).hexdigest()}  {f.name}" for f in files]
    (DIST / "SHA256SUMS").write_text("\n".join(sums) + "\n")
    build_info = {
        "version": v,
        "commit": out(["git", "rev-parse", "HEAD"]),
        "flutter_webos": {"url": out(["git", "remote", "get-url", "origin"], cwd=fw),
                          "commit": out(["git", "rev-parse", "HEAD"], cwd=fw)},
        "plugins": {k: {"url": u, "commit": c} for k, (u, c) in plugin_refs().items()},
        "built": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "files": {f.name: f.stat().st_size for f in files},
    }
    (DIST / "build-info.json").write_text(json.dumps(build_info, indent=2) + "\n")
    print("\n".join(sorted(p.name for p in DIST.iterdir())))


# ---- notes --------------------------------------------------------------------------------------

def human_size(n):
    return f"{n / 1048576:.1f} MB"


def short(url_commit):
    url, commit = url_commit
    name = url.rstrip("/").removesuffix(".git").split("/")[-1]
    web = url.removesuffix(".git")
    return f"[{name} `{commit[:7]}`]({web}/commit/{commit})"


def cmd_notes(a):
    info = appinfo()
    v = a.version or app_version()
    tag = f"v{v}"
    has_tag = subprocess.run(["git", "rev-parse", "-q", "--verify", f"refs/tags/{tag}"], cwd=ROOT,
                             capture_output=True).returncode == 0
    section = changelog_section(v)
    if section is None:
        section = changelog_section("Unreleased") or ""
    prev = previous_tag(tag if has_tag else None)
    changes = commits(prev, tag if has_tag else "HEAD")
    bi = json.loads((DIST / "build-info.json").read_text()) if (DIST / "build-info.json").exists() else None
    sums = (DIST / "SHA256SUMS").read_text().strip() if (DIST / "SHA256SUMS").exists() else None
    repo_url = f"https://github.com/{a.repo}"
    date = re.search(r"^## \[" + re.escape(v) + r"\] - (\S+)", CHANGELOG.read_text(), re.M) if CHANGELOG.exists() else None

    L = []
    L.append(f"# {APP_NAME} {v}")
    L.append("")
    L.append(f"A Jellyfin client for LG TVs, made with Flutter."
             f"{' Released ' + date.group(1) + '.' if date else ''}")
    L.append("")
    subs = changelog_subsections(section)
    if subs:
        for title, text in subs:
            L.append(f"## {SECTION_TITLES.get(title, title)}")
            L.append("")
            L.append(text)
            L.append("")
    else:
        L.append("_No changelog entry for this version; the list of changes is below._")
        L.append("")

    L.append("## 📥 Which file do I need?")
    L.append("")
    L.append("| Your TV | Download |")
    L.append("| --- | --- |")
    for suffix, _, who in PACKAGES:
        name = f"{info['id']}_{v}_{suffix}.ipk"
        size = f" ({human_size(bi['files'][name])})" if bi and name in bi.get("files", {}) else ""
        L.append(f"| {who} | [`{name}`]({repo_url}/releases/download/{tag}/{name}){size} |")
    L.append("")
    L.append("Not sure? On the TV open **Settings → General → About This TV**: the webOS TV version is "
             "listed there. Other webOS versions have not been tested yet.")
    L.append("")
    L.append("## 📺 How to install")
    L.append("")
    L.append("- **Developer Mode** (any LG TV): with the [webOS CLI](https://webostv.developer.lge.com/develop/tools/cli-installation) "
             f"connected to the TV, run `ares-install -d <tv> {info['id']}_{v}_<package>.ipk`, or use "
             "[webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop) and pick the file.")
    L.append(f"- **Homebrew Channel** (rooted TVs): `{info['id']}.manifest.json` is attached for app "
             "repositories in the webosbrew format; it points at the webOS 6 and older package.")
    L.append("- Updating keeps your servers, users and settings.")
    L.append("")
    if bi:
        L.append("## 🔧 Built with")
        L.append("")
        L.append(f"- App: [`{bi['commit'][:7]}`]({repo_url}/commit/{bi['commit']}), built {bi['built']}")
        L.append(f"- Toolchain: {short((bi['flutter_webos']['url'], bi['flutter_webos']['commit']))} "
                 "(Flutter for webOS with the legacy package for older TVs)")
        seen = set()
        for name, p in sorted(bi.get("plugins", {}).items()):
            key = (p["url"], p["commit"])
            if key in seen:
                continue
            seen.add(key)
            pkgs = sorted(n for n, q in bi["plugins"].items() if (q["url"], q["commit"]) == key)
            L.append(f"- Plugins: {short(key)} ({', '.join(pkgs)})")
        L.append("")
    if sums:
        L.append("## 🔒 Checksums (SHA-256)")
        L.append("")
        L.append("```")
        L.append(sums)
        L.append("```")
        L.append("")
    if changes:
        since = f"since {prev}" if prev else "in this first release"
        L.append(f"<details><summary>All changes {since} ({len(changes)} commits)</summary>")
        L.append("")
        for h, s in changes:
            L.append(f"- {s} ([`{h}`]({repo_url}/commit/{h}))")
        L.append("")
        if prev:
            L.append(f"Full comparison: {repo_url}/compare/{prev}...{tag}")
            L.append("")
        L.append("</details>")
    text = "\n".join(L).rstrip() + "\n"
    if a.out:
        pathlib.Path(a.out).write_text(text)
        print(f"wrote {a.out}")
    else:
        print(text)


# ---- prepare / publish --------------------------------------------------------------------------

def check_clean():
    if out(["git", "status", "--porcelain"]):
        die("the working tree has uncommitted changes; commit or stash them first")


def cmd_prepare(a):
    v = a.version
    if not re.fullmatch(r"\d+\.\d+\.\d+", v):
        die("version must be X.Y.Z")
    check_clean()
    if subprocess.run(["git", "rev-parse", "-q", "--verify", f"refs/tags/v{v}"], cwd=ROOT, capture_output=True).returncode == 0:
        die(f"tag v{v} already exists")
    date_changelog(v)
    run(["tools/set-version.sh", v], cwd=ROOT)
    run(["git", "commit", "-q", "-am", f"Version {v}"], cwd=ROOT)
    run(["git", "tag", "-a", f"v{v}", "-m", f"{APP_NAME} {v}"], cwd=ROOT)
    print(f"committed 'Version {v}' and tagged v{v}; `tools/release.py publish {v}` starts the release")


def cmd_publish(a):
    v = a.version or app_version()
    if subprocess.run(["git", "rev-parse", "-q", "--verify", f"refs/tags/v{v}"], cwd=ROOT, capture_output=True).returncode != 0:
        die(f"no tag v{v}; run `tools/release.py prepare {v}` first")
    run(["git", "push", "origin", "HEAD"], cwd=ROOT)
    run(["git", "push", "origin", f"v{v}"], cwd=ROOT)
    print(f"pushed v{v}: the Release workflow builds the IPKs and publishes https://github.com/{a.repo}/releases/tag/v{v}")


def cmd_release(a):
    if not a.yes:
        body = changelog_section("Unreleased") or "(empty)"
        print(f"Release {APP_NAME} {a.version} with these notes:\n\n{body}\n")
        if input("Commit, tag and push? [y/N] ").strip().lower() != "y":
            die("cancelled")
    cmd_prepare(a)
    cmd_publish(a)


def cmd_check(a):
    body = changelog_section("Unreleased")
    prev = previous_tag()
    print(f"version in the app: {app_version()}; last release: {prev or 'none'}")
    print("\n[Unreleased] in CHANGELOG.md:\n" + (body or "(nothing yet)"))
    cs = commits(prev)
    print(f"\n{len(cs)} commits since {prev or 'the start'}:")
    for h, s in cs[:40]:
        print(f"  {h} {s}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", DEFAULT_REPO), help="owner/name on GitHub")
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build", help="build both IPKs into dist/")
    b.add_argument("--flutter-webos", help="flutter-webos checkout (with legacy-webos set up)")
    b.add_argument("--tag", help="release tag the manifest's URLs point at (default v<version>)")
    b.add_argument("--skip-build", action="store_true", help="only collect an existing build")
    n = sub.add_parser("notes", help="print the release description")
    n.add_argument("--version")
    n.add_argument("--out")
    p = sub.add_parser("prepare", help="version, changelog, commit, tag")
    p.add_argument("version")
    u = sub.add_parser("publish", help="push branch and tag")
    u.add_argument("version", nargs="?")
    r = sub.add_parser("release", help="prepare + publish")
    r.add_argument("version")
    r.add_argument("--yes", action="store_true")
    sub.add_parser("check", help="what the next release would contain")
    a = ap.parse_args()
    {"build": cmd_build, "notes": cmd_notes, "prepare": cmd_prepare, "publish": cmd_publish,
     "release": cmd_release, "check": cmd_check}[a.cmd](a)


if __name__ == "__main__":
    main()
