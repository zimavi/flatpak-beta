#!/usr/bin/env bash
# Usage: bump.sh <app-id> <version> <url> <sha256>      (RELEASE_DATE=YYYY-MM-DD, default today)
# Updates apps/<app-id>/<branch>.yml, where <branch> is the DefaultBranch of zimavi.flatpakrepo. stable takes final
# releases only; beta takes pre-releases (1.0.0-beta.1) and final releases. A release that is not for this repository
# changes nothing and succeeds, so the same call works for both repositories.
set -euo pipefail
die() { echo "bump.sh: $*" >&2; exit 1; }
skip() { echo "bump.sh: $*, left alone"; exit 0; }

[[ $# == 4 ]] || die "usage: bump.sh <app-id> <version> <url> <sha256>"
app=$1 version=$2 url=$3 sha=$4
date=${RELEASE_DATE:-$(date -u +%F)}
[[ $app =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_-]+)+$ ]] || die "bad app id: $app"
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || die "bad version: $version"
[[ $url =~ ^https://github\.com/zimavi/[A-Za-z0-9._/-]+$ && $url != *..* ]] || die "bad url: $url"
[[ $sha =~ ^[0-9a-f]{64}$ ]] || die "bad sha256: $sha"
[[ $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "bad date: $date"

cd "$(dirname "$0")/.."
branch=$(sed -n 's/^DefaultBranch=//p' zimavi.flatpakrepo)
[[ $branch == stable || $branch == beta ]] || die "DefaultBranch in zimavi.flatpakrepo must be stable or beta"
file=apps/$app/$branch.yml
[[ -f $file ]] || die "no such manifest: $file"
[[ $branch != stable || $version != *-* ]] || skip "$version is a pre-release, not for stable"

for field in VERSION RELEASE_DATE url sha256; do
  [[ $(grep -c "^ *$field: " "$file") == 1 ]] || die "$file must have exactly one '$field:' line"
done
current=$(sed -n "s/^ *VERSION: *'\(.*\)'/\1/p" "$file")
[[ $current ]] || die "VERSION in $file must be in single quotes"

# True when $1 is an older version than $2. "~" makes sort -V put 1.0.0-beta before 1.0.0.
older() { [[ $1 != "$2" && $(printf '%s\n' "${1/-/\~}" "${2/-/\~}" | sort -V | head -n1) == "${1/-/\~}" ]]; }
if older "$version" "$current"; then
  # beta may already be ahead of a final release, such as a patch of an earlier version.
  [[ $branch == beta && $version != *-* ]] || die "$version is older than $current in $file"
  skip "$file is already newer"
fi

sed -i \
  -e "s|^\( *VERSION: \).*|\1'$version'|" \
  -e "s|^\( *RELEASE_DATE: \).*|\1'$date'|" \
  -e "s|^\( *url: \).*|\1$url|" \
  -e "s|^\( *sha256: \).*|\1$sha|" "$file"
echo "bump.sh: $file -> $version"
