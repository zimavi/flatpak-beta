#!/usr/bin/env bash
# Usage: build.sh <ostree repo> [gpg key id]
# Builds each apps/<app-id>/<branch>.yml whose files differ from what the repo already holds.
set -euo pipefail

repo=$(realpath -m "${1:?usage: build.sh <ostree repo> [gpg key id]}")
sign=${2:+--gpg-sign=$2}
cd "$(dirname "$0")/.."
shopt -s nullglob # no manifests, nothing to build

for manifest in apps/*/*.yml; do
  dir=$(dirname "$manifest")
  app=$(basename "$dir")
  branch=$(basename "$manifest" .yml)
  # The hash goes into the commit subject, so an unchanged app gets no new commit (no fake update for users)
  # and whatever a failed or cancelled publish left out is built by the next one.
  hash=$({ cat "$manifest"; find "$dir" -type f ! -name '*.yml' -print0 | LC_ALL=C sort -z | xargs -0 sha256sum; } |
    sha256sum | cut -d' ' -f1)
  if ostree --repo="$repo" show "app/$app/x86_64/$branch" 2>/dev/null | grep -F "manifest:$hash" >/dev/null; then
    echo "$app//$branch is up to date"
    continue
  fi
  flatpak-builder --force-clean --disable-rofiles-fuse --default-branch="$branch" --repo="$repo" \
    --subject="manifest:$hash" ${sign:+"$sign"} build "$manifest"
done
