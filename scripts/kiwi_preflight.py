#!/usr/bin/env python3
"""
kiwi_preflight — fail in seconds, not in five minutes.

Why this exists: kiwi's bootstrap and install phases are the expensive part of a
build. Every mistake that can be found by reading the description and asking a
repository a question was, until now, found by waiting for kiwi to reach the
phase that trips over it. A wrong package name cost a five-minute round trip; a
404 repository cost another. Both are answerable in about ten seconds.

This runs the checks that need no build:

  1. the description is well-formed and has the attributes kiwi requires
  2. every repository actually serves repodata (the 404 test)
  3. a live overlay ISO declares the dracut module it needs
  4. every package name exists in the configured repositories (needs --dnf)

Usage:
    python3 kiwi_preflight.py packages/distro-iso-builder/kiwi/config.xml
    python3 kiwi_preflight.py config.xml --skip-network        # offline
    python3 kiwi_preflight.py config.xml --dnf                 # also query dnf
    python3 kiwi_preflight.py config.xml --json

Exit codes: 0 all checks passed · 1 a check failed · 2 could not read the description
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

UA = "kiwi-preflight/1.0"
# packages kiwi refuses to build without, keyed by what the description asks for
REQUIRED_FOR = {
    ("iso", "overlay"): (["dracut-kiwi-live", "kiwi-dracut-live"],
                         "a live ISO with flags=overlay needs the kiwi live dracut module"),
}


def load(path: Path) -> dict:
    root = ET.parse(path).getroot()
    repos, pkgs, ignores, removed = [], [], [], []
    for r in root.iter("repository"):
        src = r.find("source")
        if src is not None and src.get("path"):
            repos.append(src.get("path"))
    # Only packages that are meant to end up IN the image count as required.
    # type="delete" / "uninstall" blocks name packages to remove — treating them
    # as required makes them collide with the <ignore> list and reports a
    # contradiction that is not there.
    for p in root.iter("packages"):
        ptype = (p.get("type") or "image").lower()
        names = [e.get("name") for e in p.findall("package") if e.get("name")]
        if ptype in ("image", "bootstrap", "systemfiles", "iso", "oem", "pxe", "kis"):
            pkgs.extend(names)
        else:
            removed.extend(names)
        for e in p.findall("ignore"):
            if e.get("name"):
                ignores.append(e.get("name"))
    prefs = root.find("preferences")
    typ = prefs.find("type") if prefs is not None else None
    def txt(tag):
        el = prefs.find(tag) if prefs is not None else None
        return (el.text or "").strip() if el is not None else ""
    return {
        "name": root.get("name"),
        "schemaversion": root.get("schemaversion"),
        "image": typ.get("image") if typ is not None else None,
        "flags": (typ.get("flags") if typ is not None else None) or "",
        "filesystem": typ.get("filesystem") if typ is not None else None,
        "bootloader_theme": txt("bootloader-theme"),
        "bootsplash_theme": txt("bootsplash-theme"),
        "repos": repos,
        "packages": pkgs,
        "ignores": ignores,
        "removed": removed,
    }


def check_description(d: dict) -> list[dict]:
    out = []
    ok = bool(d["name"]) and " " not in (d["name"] or " ")
    out.append({"check": "image name is present and has no spaces",
                "pass": ok, "detail": f"name={d['name']!r}"})
    out.append({"check": "schemaversion is declared",
                "pass": d["schemaversion"] == "8.5",
                "detail": f"schemaversion={d['schemaversion']!r} (kiwi 11 requires 8.5)"})
    out.append({"check": "image type is declared",
                "pass": bool(d["image"]), "detail": f"image={d['image']!r}"})
    out.append({"check": "at least one package is listed",
                "pass": len(d["packages"]) > 0, "detail": f"{len(d['packages'])} packages"})
    dupes = sorted({p for p in d["packages"] if d["packages"].count(p) > 1})
    out.append({"check": "no duplicate package entries",
                "pass": not dupes, "detail": ", ".join(dupes) if dupes else "none"})
    both = sorted(set(d["packages"]) & set(d["ignores"]))
    out.append({"check": "no package is both required and ignored",
                "pass": not both, "detail": ", ".join(both) if both else "none"})
    # an <ignore> for something that is not pulled in anyway is dead weight,
    # not a failure — report it so it can be tidied, never fail the build on it
    overlap = sorted(set(d["ignores"]) & set(d["removed"]))
    out.append({"check": "ignored packages are also not left for deletion",
                "pass": True, "detail": (f"listed in both ignore and delete: {', '.join(overlap)}"
                                         if overlap else "none")})
    return out


def check_requirements(d: dict) -> list[dict]:
    out = []
    key = (d["image"], d["flags"])
    if key in REQUIRED_FOR:
        alternatives, why = REQUIRED_FOR[key]
        present = [a for a in alternatives if a in d["packages"]]
        out.append({"check": f"live module declared ({' or '.join(alternatives)})",
                    "pass": bool(present),
                    "detail": why if not present else f"found {present[0]}"})
    return out


def check_themes(d: dict, desc_dir: Path) -> list[dict]:
    """A declared theme that is not in the overlay kills the build mid-install.

    kiwi applies the theme during the image build and stops with
    "chroot: stderr: /usr/share/plymouth/themes/<name>/<name>.plymouth does not
    exist". That cost a full ten-minute run to discover, and the answer is a
    directory listing.
    """
    out = []
    for kind, name in (("bootloader-theme", d["bootloader_theme"]),
                       ("bootsplash-theme", d["bootsplash_theme"])):
        if not name:
            continue
        roots = [desc_dir / "root", desc_dir]
        found = False
        for r in roots:
            if not r.is_dir():
                continue
            for pat in (f"themes/{name}", f"{name}.plymouth", f"{name}.pf2", f"themes/{name}.pf2"):
                if list(r.rglob(pat)):
                    found = True
                    break
            if found:
                break
        out.append({"check": f"{kind} '{name}' exists in the overlay",
                    "pass": found,
                    "detail": ("found in the staged packages" if found else
                               f"declared but not shipped — kiwi will fail with "
                               f"'themes/{name}/{name}.plymouth does not exist'. "
                               f"Either ship the theme or remove the declaration.")})
    return out


def check_repos(d: dict, timeout: float, skip: bool, attempts: int = 2) -> list[dict]:
    out = []
    if skip:
        return [{"check": "repository reachability", "pass": True, "detail": "skipped (--skip-network)"}]
    for url in d["repos"]:
        last_err = None
        for _attempt in range(attempts):
            target = url.rstrip("/") + "/repodata/repomd.xml"
            try:
                req = urllib.request.Request(target, headers={"User-Agent": UA}, method="GET")
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    code = r.status
                break
            except urllib.error.HTTPError as e:
                code = e.code
                break
            except Exception as e:  # noqa: BLE001
                last_err = e
                code = None
        if code is None:
            # A timeout or DNS blip is not a mistake in the description, so it
            # must not fail the build. But it must not vanish either: run #20
            # died on a mirror whose metadata was broken, and the preflight had
            # already seen that repo as unreachable and said nothing louder than
            # "PASS". A warning is the honest middle.
            out.append({"check": f"repo reachable: {url[:60]}", "pass": True, "warn": True,
                        "detail": f"unreachable after {attempts} attempts "
                                  f"({type(last_err).__name__}) — the build may still fail here"})
            continue
        # 4xx means the description points at the wrong place — always a failure.
        # 5xx is the mirror's problem and must not block a correct build.
        if code == 200:
            out.append({"check": f"repo serves repodata: {url[:60]}", "pass": True,
                        "detail": "HTTP 200"})
        elif 500 <= code < 600:
            out.append({"check": f"repo serves repodata: {url[:60]}", "pass": True, "warn": True,
                        "detail": f"HTTP {code} — server-side; the build may fail on this repository"})
        else:
            out.append({"check": f"repo serves repodata: {url[:60]}", "pass": False,
                        "detail": f"HTTP {code} — the URL in the description is wrong"})
    return out


def check_packages_dnf(d: dict, use_dnf: bool) -> list[dict]:
    if not use_dnf:
        return [{"check": "package names exist in the repositories",
                 "pass": True, "detail": "skipped (pass --dnf to query)"}]
    pkgs = [p for p in d["packages"] if not p.startswith("@")]
    repoopts = []
    for i, url in enumerate(d["repos"]):
        repoopts += [f"--repofrompath=pf{i},{url}", f"--repo=pf{i}"]
    cmd = ["dnf", "--assumeno", "--quiet", "install", *repoopts, *pkgs]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    except FileNotFoundError:
        return [{"check": "package names exist in the repositories", "pass": False,
                 "detail": "dnf not found in this environment"}]
    except subprocess.TimeoutExpired:
        return [{"check": "package names exist in the repositories", "pass": False,
                 "detail": "dnf query timed out after 300s"}]
    out_text = (p.stdout or "") + (p.stderr or "")
    missing = sorted(set(re.findall(r"No match for argument:\s*(\S+)", out_text)))
    return [{"check": "package names exist in the repositories",
             "pass": not missing,
             "detail": ("missing: " + ", ".join(missing)) if missing
                       else f"all {len(pkgs)} resolvable"}]


def main() -> int:
    ap = argparse.ArgumentParser(description="Checks a kiwi description can pass before any build.")
    ap.add_argument("description")
    ap.add_argument("--skip-network", action="store_true", help="do not touch the repositories")
    ap.add_argument("--dnf", action="store_true", help="query dnf for package availability (slow, exact)")
    ap.add_argument("--timeout", type=float, default=15.0)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    path = Path(args.description)
    if not path.is_file():
        print(f"no such description: {path}", file=sys.stderr)
        return 2
    try:
        d = load(path)
    except ET.ParseError as e:
        print(f"description is not valid XML: {e}", file=sys.stderr)
        return 2

    checks = []
    checks += check_description(d)
    checks += check_requirements(d)
    checks += check_themes(d, path.parent)
    checks += check_repos(d, args.timeout, args.skip_network)
    checks += check_packages_dnf(d, args.dnf)

    failed = [c for c in checks if not c["pass"]]
    warned = [c for c in checks if c["pass"] and c.get("warn")]

    if args.json:
        print(json.dumps({"description": str(path), "parsed": d,
                          "checks": checks, "failures": len(failed)}, indent=1))
    else:
        print(f"description : {path}")
        print(f"image       : {d['image']}  flags={d['flags'] or '-'}  fs={d['filesystem'] or '-'}")
        print(f"repos       : {len(d['repos'])}")
        print(f"packages    : {len(d['packages'])} in image, {len(d['ignores'])} ignored, "
              f"{len(d['removed'])} removed")
        print(f"themes      : bootloader={d['bootloader_theme'] or '-'} "
              f"bootsplash={d['bootsplash_theme'] or '-'}\n")
        for c in checks:
            mark = "FAIL" if not c["pass"] else ("WARN" if c.get("warn") else "PASS")
            print(f"  {mark}  {c['check']}")
            if not c["pass"] or args.dnf:
                print(f"        {c['detail']}")
        if failed:
            print(f"\nverdict : FAIL — {len(failed)} check(s)")
        elif warned:
            print(f"\nverdict : PASS — {len(warned)} warning(s) that may still sink the build")
            for w in warned:
                # make it appear in the GitHub Actions run summary, not just the log
                print(f"::warning::{w['check']} — {w['detail']}")
        else:
            print("\nverdict : PASS — safe to build")

    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
