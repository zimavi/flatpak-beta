# zimavi's beta Flatpak repository

Pre-releases, and final releases when no newer pre-release is published. For final releases only, use
[flatpak](https://github.com/zimavi/flatpak).

## Install

```sh
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo  # runtimes
flatpak remote-add --if-not-exists zimavi-beta https://flatpak-beta.zimavi.net.ua/zimavi.flatpakrepo
flatpak install zimavi-beta <app-id>//beta
```

x86_64 only.

## Applications

| App | Id | License notes |
|---|---|---|
| [Shirabe](https://github.com/zimavi/Shirabe.Client) | `ua.net.zimavi.Shirabe` | Bundles BASS, which is free for non-commercial use only |

`flatpak remote-ls zimavi-beta` lists what is currently published.

## How it works

Each `apps/<app-id>/<branch>.yml` is a Flatpak manifest that repackages a GitHub release; the file name is the branch,
so every `.yml` in an app folder is built. The other files of the folder are shared by its branches. Removing a manifest
unpublishes its branch.

1. The app's repository runs `scripts/bump.sh` on a checkout of this one and opens a pull request that merges itself.
2. `check` builds the pull request.
3. After the merge, `publish` builds what changed, signs it and uploads it to Cloudflare R2.

Run `publish` by hand (Actions tab) to retry a failed upload.

By hand:

```sh
RELEASE_DATE=<YYYY-MM-DD> scripts/bump.sh <app-id> <version> <url of the release file> <sha256>
scripts/build.sh /tmp/repo   # needs flatpak-builder and the SDKs the manifests name
```

`RELEASE_DATE` defaults to today. `bump.sh` updates the manifest of this repository's branch (the `DefaultBranch` of
`zimavi.flatpakrepo`) and refuses an older version. A final release older than the published pre-release changes
nothing.

flatpak and flatpak-beta have the same scripts and workflows: change them in both. Each has its own `apps/`, including
the desktop entry, metainfo and icon.

## Adding an app

Create `apps/<app-id>/` with:

- `beta.yml`, the manifest (`stable.yml` in flatpak).
- The files the manifest installs, such as the desktop entry, AppStream metainfo and icon.

For `bump.sh` to update a manifest:

- It must have exactly one line each starting with `VERSION:`, `RELEASE_DATE:`, `url:` and `sha256:`, with the first two
  quoted in single quotes.
- The release URL must be under `https://github.com/zimavi/`.

Then add the app to the [table above](#applications).

## Setup

Environment `publish` (limited to `main`):

| Name | Kind | Value |
|---|---|---|
| `R2_ACCESS_KEY_ID` | secret | R2 API token, *Object Read & Write*, this bucket only |
| `R2_SECRET_ACCESS_KEY` | secret | from the same token |
| `R2_ENDPOINT` | secret | `https://<account id>.r2.cloudflarestorage.com` |
| `GPG_PRIVATE_KEY` | secret | armored private signing key, without a passphrase |
| `R2_BUCKET` | variable | bucket name |

The bucket is served at `https://flatpak-beta.zimavi.net.ua`. Do not add a "cache everything" rule for it: clients need a
fresh `repo/summary`.

The repository also needs *Allow auto-merge*, and a rule on `main` that requires a pull request and the `check` status.

An app repository needs a secret `FLATPAK_TOKEN`: a fine-grained token for flatpak and flatpak-beta only, with
*Contents* and *Pull requests* read and write. **Whoever holds it can publish to every user.**

**Back up the signing key offline.** Without it, every user has to remove the remote and add it again.
