#!/usr/bin/env python3
"""Install missing desktop apps without updating or adopting existing bundles."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile


def bundle_id(path):
    try:
        with (path / "Contents/Info.plist").open("rb") as source:
            return plistlib.load(source).get("CFBundleIdentifier")
    except (OSError, ValueError, plistlib.InvalidFileException):
        return None


def find_app(app, roots, spotlight="/usr/bin/mdfind"):
    def scan_error(error):
        raise error

    for root in roots:
        if not root.exists():
            continue
        for directory, names, _ in os.walk(root, onerror=scan_error):
            for name in list(names):
                path = Path(directory) / name
                if name.lower().endswith(".app"):
                    names.remove(name)
                    if name.casefold() == app["bundle"].casefold() or bundle_id(path) == app["id"]:
                        return path
    if spotlight:
        result = subprocess.run(
            [spotlight, "-0", f"kMDItemCFBundleIdentifier == '{app['id']}'"],
            check=True, capture_output=True,
        )
        for value in result.stdout.split(b"\0"):
            if value:
                path = Path(os.fsdecode(value))
                if path.is_dir() and bundle_id(path) == app["id"]:
                    return path
    return None


def publish_bundle(source, destination, bundle, writable=False):
    destination.mkdir(parents=True, exist_ok=True)
    # Stage on the destination filesystem so interrupted copies never look installed.
    with tempfile.TemporaryDirectory(prefix=".dotfiles-app-", dir=destination) as staging:
        staged = Path(staging) / bundle
        shutil.copytree(source, staged, symlinks=True)
        if writable:
            # Legacy Nix app copies are read-only; make only the new copy user-writable.
            for directory, _, files in os.walk(staged):
                for path in [Path(directory)] + [Path(directory) / name for name in files]:
                    if not path.is_symlink():
                        path.chmod(path.stat().st_mode | 0o200)
        target = destination / bundle
        if not target.exists() and not target.is_symlink():
            staged.rename(target)


def install_zip(app, destination, roots, spotlight):
    version = subprocess.check_output(["/usr/bin/sw_vers", "-productVersion"], text=True).strip()
    if tuple(map(int, version.split("."))) < tuple(map(int, app["minimum_macos"].split("."))):
        raise RuntimeError(f"{app['bundle']} requires macOS {app['minimum_macos']} or later")
    with tempfile.TemporaryDirectory(prefix="dotfiles-app-") as work:
        archive = Path(work) / "app.zip"
        subprocess.run(["/usr/bin/curl", "--fail", "--location", "--proto", "=https",
                        "--proto-redir", "=https", "--tlsv1.2", app["url"], "-o", str(archive)], check=True)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != app["sha256"]:
            raise RuntimeError(f"Checksum mismatch for {app['bundle']}")
        extracted = Path(work) / "extracted"
        subprocess.run(["/usr/bin/ditto", "-x", "-k", str(archive), str(extracted)], check=True)
        source = extracted / app["bundle"]
        if bundle_id(source) != app["id"]:
            raise RuntimeError(f"Unexpected application identity for {app['bundle']}")
        subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(source)], check=True)
        if find_app(app, roots, spotlight):
            return
        publish_bundle(source, destination, app["bundle"])


def preserve_legacy(apps, destination, roots):
    # Older configurations put Wallper in a directory nix-darwin prunes on activation.
    # Copy its exact contents into user-owned storage before that cleanup occurs.
    for app in apps:
        if "url" not in app:
            continue
        for root in roots:
            source = root / "Nix Apps" / app["bundle"]
            if not source.is_dir():
                continue
            target = destination / app["bundle"]
            if target.exists():
                continue
            publish_bundle(source, destination, app["bundle"], writable=True)
            print(f"Preserved existing {app['bundle']} in {destination}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--home", required=True, type=Path)
    parser.add_argument("--brew", required=True)
    parser.add_argument("--applications-root", action="append", type=Path)
    parser.add_argument("--spotlight", default="/usr/bin/mdfind")
    parser.add_argument("--preserve-legacy", action="store_true")
    args = parser.parse_args()
    apps = json.loads(args.manifest.read_text())
    destination = args.home / "Applications"
    roots = args.applications_root or [Path("/Applications"), destination]
    if args.preserve_legacy:
        preserve_legacy(apps, destination, roots)
        return
    for app in apps:
        existing = find_app(app, roots, args.spotlight)
        if existing:
            print(f"Skipping {app['bundle']}: already installed at {existing}")
            continue
        if "cask" in app:
            destination.mkdir(parents=True, exist_ok=True)
            environment = dict(os.environ, HOME=str(args.home), HOMEBREW_NO_AUTO_UPDATE="1",
                               HOMEBREW_NO_INSTALL_CLEANUP="1", HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK="1")
            subprocess.run([args.brew, "install", "--cask", "--appdir", str(destination), app["cask"]],
                           env=environment, check=True)
            if not find_app(app, roots, args.spotlight):
                raise RuntimeError(f"Homebrew finished but {app['bundle']} was not found")
        else:
            install_zip(app, destination, roots, args.spotlight)


if __name__ == "__main__":
    main()
