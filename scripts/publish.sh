#!/usr/bin/env bash
# Usage: publish.sh <rclone destination, such as r2:bucket> <gpg key id>
# Fetches the published repo, adds what changed, signs it and uploads it again.
set -euo pipefail

usage="usage: publish.sh <rclone destination> <gpg key id>"
dest=${1:?$usage}
key=${2:?$usage}
# "r2:" alone means an unset bucket name.
[[ $dest != *: ]] || { echo "publish.sh: no bucket in destination '$dest'" >&2; exit 1; }
dest=${dest%/}
cd "$(dirname "$0")/.."

public_key=$(gpg --export "$key" | base64 -w0)
[[ $public_key ]] || { echo "publish.sh: no GPG key '$key'" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
repo=$work/repo

# shortcut: downloads the whole repo on every run; move to flat-manager when it reaches a few GB
rclone copy "$dest/repo" "$repo"
if [[ ! -f $repo/config ]]; then
  [[ -z $(find "$repo" -type f -print -quit 2>/dev/null) ]] ||
    { echo "publish.sh: the remote repo has files but no config, not touching it" >&2; exit 1; }
  # Before the mkdir below: init takes a folder that has objects/ for an existing repo.
  ostree init --repo="$repo" --mode=archive-z2
fi
# R2 has no empty directories, ostree needs them.
mkdir -p "$repo"/{objects,tmp,state,extensions,refs/heads,refs/remotes,refs/mirrors}

# A removed manifest unpublishes its branch. Never all of them: no manifest at all means something is wrong.
compgen -G 'apps/*/*.yml' >/dev/null || { echo "publish.sh: no manifests, not publishing" >&2; exit 1; }
refs=$(ostree --repo="$repo" refs)
for ref in $refs; do
  IFS=/ read -r kind app _ branch <<<"$ref"
  [[ $kind == app || $kind == runtime ]] || continue
  # <app-id>.Locale and other extensions belong to the app's manifest.
  while [[ $app == *.* && ! -d apps/$app ]]; do app=${app%.*}; done
  [[ -f apps/$app/$branch.yml ]] || { echo "unpublishing $ref"; ostree --repo="$repo" refs --delete "$ref"; }
done

bash scripts/build.sh "$repo" "$key"
setting() { sed -n "s/^$1=//p" zimavi.flatpakrepo; }
flatpak build-update-repo --title="$(setting Title)" --default-branch="$(setting DefaultBranch)" --gpg-sign="$key" --generate-static-deltas --prune --prune-depth=3 "$repo"

# Order matters to clients: first the data, then what points at it, and deletions last.
skip=(--exclude '/tmp/**' --exclude '.lock')
rclone copy "$repo" "$dest/repo" --checksum \
  --filter '+ /objects/**' --filter '+ /deltas/**' --filter '+ /delta-indexes/**' --filter '- **'
rclone copy "$repo" "$dest/repo" --checksum "${skip[@]}"
rclone sync "$repo" "$dest/repo" --checksum --delete-after "${skip[@]}"

{ cat zimavi.flatpakrepo; echo "GPGKey=$public_key"; } >"$work/zimavi.flatpakrepo"
rclone copyto "$work/zimavi.flatpakrepo" "$dest/zimavi.flatpakrepo"
