#!/usr/bin/env bash
# Self-check of bump.sh on a made-up app in a temporary folder.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts" "$tmp/apps/org.example.App"
cp "$here/bump.sh" "$tmp/scripts/"
cd "$tmp/apps/org.example.App"
manifest() { printf "%s\n" "  VERSION: '$2'" "  RELEASE_DATE: '2026-01-01'" "  url: x" "  sha256: y" >"$1"; }
channel() { echo "DefaultBranch=$1" >"$tmp/zimavi.flatpakrepo"; }

sha=$(printf 'a%.0s' {1..64})
url=https://github.com/zimavi/App/releases/download/v/app.tar.gz
bump() { bash "$tmp/scripts/bump.sh" org.example.App "$@" >/dev/null 2>&1; }
has() { grep -qF "VERSION: '$2'" "$1" || { echo "FAIL: $1 is not at $2" >&2; exit 1; }; }
refused() { if bump "$@"; then echo "FAIL: accepted $*" >&2; exit 1; fi; }

channel beta
manifest beta.yml 1.0.0-beta.3
RELEASE_DATE=2026-02-02 bump 1.0.0-beta.10 "$url" "$sha" # 10 is newer than 3
has beta.yml 1.0.0-beta.10
grep -qF "url: $url" beta.yml
grep -qF "sha256: $sha" beta.yml
grep -qF "RELEASE_DATE: '2026-02-02'" beta.yml
bump 1.0.0 "$url" "$sha" # beta also takes final releases
has beta.yml 1.0.0
bump 1.1.0-beta.1 "$url" "$sha"
bump 1.0.1 "$url" "$sha" # a patch release leaves a newer beta alone
has beta.yml 1.1.0-beta.1
refused 1.0.1-beta.1 "$url" "$sha" # downgrade
refused 'v2.0.0' "$url" "$sha"
refused 2.0.0 https://example.com/app.tar.gz "$sha"
refused 2.0.0 https://github.com/zimavi/../other/app.tar.gz "$sha"
refused 2.0.0 "$url" abc
refused 2.0.0 "$url" "$sha" stable # no extra arguments
has beta.yml 1.1.0-beta.1
[[ ! -e stable.yml ]]

channel stable
refused 2.0.0 "$url" "$sha" # no stable.yml: nothing is created
[[ ! -e stable.yml ]]
manifest stable.yml 1.0.0
bump 2.0.0-beta.1 "$url" "$sha" # a pre-release changes nothing
has stable.yml 1.0.0
bump 1.0.1 "$url" "$sha"
has stable.yml 1.0.1
has beta.yml 1.1.0-beta.1
refused 1.0.0 "$url" "$sha" # downgrade

sed -i '/sha256:/d' stable.yml
refused 2.0.0 "$url" "$sha" # bad manifest
has stable.yml 1.0.1

manifest stable.yml 1.0.0
channel nightly
refused 2.0.0 "$url" "$sha" # unknown channel
has stable.yml 1.0.0
echo "bump.sh: all checks passed"
