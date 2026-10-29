#!/usr/bin/env bash
# ci-prefetch-payload.sh — hand anaconda a local repo instead of the network.
#
# Why: anaconda's payload download dies partway through ("Failed to download the
# following packages") on this pipeline — ~800-900 MiB into a 1.45 GiB set, every
# attempt, with healthy metadata (dnf makecache succeeds), 107 GB free, and no
# timeout or mirror error logged. Retries, cache clears and single-stream
# downloads all failed the same way, so the fix is to stop using anaconda's
# downloader for the bulk of it.
#
# What it does:
#   1. read the package set out of the kickstart's %packages section;
#   2. download it with `dnf install --downloadonly`, which retries and resumes
#      properly, into a directory;
#   3. createrepo_c that directory so it is a valid repo;
#   4. write a copy of the kickstart whose only repo is that directory.
#
# Safety: if the download yields nothing, the original kickstart is passed
# through unchanged, so the build behaves exactly as it does today rather than
# failing in a new way.
#
# Usage: ci-prefetch-payload.sh <kickstart> [destdir] [output-ks] [--dry-run]
set -uo pipefail

KS="${1:?usage: ci-prefetch-payload.sh <kickstart> [destdir] [output-ks]}"
DEST="${2:-/opt/rpms}"
OUT="${3:-/tmp/build.ks}"
DRY_RUN=0
for arg in "$@"; do [ "$arg" = "--dry-run" ] && DRY_RUN=1; done

if [ ! -f "$KS" ]; then
  echo "::error::kickstart not found: $KS"
  exit 1
fi

# ---- 1. package list ------------------------------------------------------
# Keep groups (@core). Drop the header, %end, comments, blank lines, the
# exclusion syntax (-sendmail) and any option lines (--excludedocs).
LIST=/tmp/kaal-pkgs.txt
awk '
  /^%packages/ { inpkgs=1; next }
  inpkgs && /^%end/ { exit }
  inpkgs { print }
' "$KS" \
  | sed 's/#.*//' \
  | tr -d '\r' \
  | awk 'NF' \
  | grep -vE '^-' \
  | grep -vE '^--' \
  > "$LIST"

COUNT=$(wc -l < "$LIST")
echo "package set from $(basename "$KS"): ${COUNT} entries"

if [ "$COUNT" -eq 0 ]; then
  echo "::warning::no %packages entries found — passing the kickstart through unchanged"
  cp "$KS" "$OUT"
  echo "KICKSTART=$OUT"
  exit 0
fi

# ---- 2. download ----------------------------------------------------------
mkdir -p "$DEST"
[ "$DRY_RUN" = "1" ] && : > "$DEST/dry-run.rpm"   # stand-in so the rewrite is exercised
if [ "$DRY_RUN" = "0" ]; then
  FETCHED=0
  for attempt in 1 2 3; do
    echo "=== pre-fetch attempt ${attempt} ==="
    # --exclude-weakdeps matches '%packages --exclude-weakdeps' in the kickstart,
    # so the set we fetch is the set anaconda would install.
    # dnf5 accepts --downloadonly on `install` but NOT --destdir (that belongs to
    # download/reposync/upgrade), so let it fill its own cache and harvest the
    # RPMs out of there. Doing it this way keeps @group entries working, which
    # `dnf download` cannot resolve.
    OK=0
    if dnf install --downloadonly -y --setopt=install_weak_deps=False \
         $(tr '\n' ' ' < "$LIST"); then
      find /var/cache/libdnf5 /var/cache/dnf -type f -name '*.rpm' \
        -exec cp -n {} "$DEST"/ \; 2>/dev/null
      OK=1
    fi
    if [ "$OK" = "1" ]; then
      FETCHED=1
      break
    fi
    echo "pre-fetch attempt ${attempt} failed; clearing metadata and retrying in 30s"
    dnf clean all >/dev/null 2>&1 || true
    rm -rf /var/cache/dnf/* /var/cache/libdnf5/* 2>/dev/null || true
    sleep 30
  done
  if [ "$FETCHED" != "1" ]; then
    echo "::warning::pre-fetch failed after 3 attempts — falling back to network repos"
    cp "$KS" "$OUT"
    echo "KICKSTART=$OUT"
    exit 0
  fi
fi

RPM_COUNT=$(find "$DEST" -maxdepth 1 -name '*.rpm' | wc -l)
SIZE=$(du -sh "$DEST" 2>/dev/null | cut -f1)
echo "fetched ${RPM_COUNT} RPMs (${SIZE}) into ${DEST}"

if [ "$RPM_COUNT" -eq 0 ]; then
  echo "::warning::no RPMs downloaded — passing the kickstart through unchanged"
  cp "$KS" "$OUT"
  echo "KICKSTART=$OUT"
  exit 0
fi

# ---- 3. make it a repo ----------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
  echo "(dry run: skipping createrepo_c)"
elif ! command -v createrepo_c >/dev/null 2>&1; then
  dnf install -y createrepo_c >/dev/null 2>&1 || true
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "(dry run: repo metadata not generated)"
elif command -v createrepo_c >/dev/null 2>&1; then
  createrepo_c "$DEST" >/dev/null
  echo "local repo metadata written"
else
  echo "::warning::createrepo_c unavailable — cannot serve ${DEST} as a repo"
  cp "$KS" "$OUT"
  echo "KICKSTART=$OUT"
  exit 0
fi

# ---- 4. kickstart: local repo preferred, network kept as a fallback --------
# The fetched set is NOT the full closure. `dnf install --downloadonly` skips
# packages the container already has — glibc, bash, NetworkManager — so a
# local-only kickstart dies with "nothing provides /bin/sh". Rather than chase
# a perfect closure, make the local repo win on cost and leave the network
# repos in place: the bulk comes from disk, and only the handful of base
# packages anaconda still needs travel over the wire.
awk -v repo="repo --name=kaal-local --baseurl=file://${DEST} --cost=1" '
  # Demote every existing repo so the local one is preferred for anything it
  # carries. 999 vs 1 is unambiguous; equal costs leave the choice to dnf.
  /^repo[ \t]/ {
    line = $0
    sub(/--cost=[0-9]+/, "", line)
    sub(/[ \t]+$/, "", line)
    print line " --cost=999"
    next
  }
  /^%packages/ && !done { print repo; done=1 }
  { print }
' "$KS" > "$OUT"

if ! grep -q '^repo --name=kaal-local' "$OUT"; then
  echo "::warning::could not insert the local repo (no %packages section?) — using the original"
  cp -f "$KS" "$OUT"
fi

echo "kickstart for the build: ${OUT}"
echo "  repos in it: $(grep -cE '^(url|repo)[ \t]' "$OUT" || true) line(s)"
echo "KICKSTART=$OUT"
