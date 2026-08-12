---
name: adding-casks
description: Adds a Homebrew cask to this tap for Linux software mainline Homebrew does not package, covering upstream artifact research, cask conventions, the auto-bump trio (fetch script, bump script, GitHub Actions workflow), and local verification. Use when the user asks to add, package, or bump a cask, mentions casks, formulas, brew packaging, livecheck, rpm2cpio or deb extraction, `.desktop` file handling, or asks why an existing cask or bump workflow behaves the way it does.
---

# Adding a cask to the tap

Every auto-updating cask in this tap is four files plus a README line:

- `Casks/<name>-linux.rb`
- `scripts/fetch-<name>-version` (version + SHA256 from upstream)
- `scripts/bump-<name>-cask` (writes them into the cask)
- `.github/workflows/bump-<name>.yml` (daily cron, PR, auto-merge)

Read two or three existing casks first. `signal-desktop-linux` (single arch,
`.deb`), `warp-linux` (dual arch, `.rpm`), and `google-chrome-linux` (extra
install-time behaviour) cover most shapes.

`brew bump --tap <tap> --cask` can drive updates from each cask's `livecheck`
block instead of the trio, which would make the scripts redundant. The tap does
not use it, so match the existing pattern rather than introducing a second one.

## Work in a worktree

Work in a git worktree (`git worktree add`, or whatever your agent harness
provides); a new cask is several new files plus a README edit, and the
verification ladder runs installs against the tree.

The worktree changes two things. `scripts/test-install` bind-mounts the tree it
is run from, so it tests the worktree copy, which is what you want.

The tap-clone copy in §5 is the trap. It goes stale on every edit, so re-copy
before each `brew livecheck` or `brew install` run. Copying an older revision
over a newer one is easy to do and easy to miss.

## 1. Probe upstream before writing anything

The answers decide the whole cask. Do this in a temp directory, not in the repo.

Find a version endpoint. JSON or repository metadata beats scraping a download
page:

```bash
curl -s "https://vendor.example/api/version" | jq .
```

Probe which arches exist rather than assuming:

```bash
for a in x86_64 aarch64 arm64; do
  printf "%-8s " "$a"
  curl -sIL -o /dev/null -w "%{http_code} %{url_effective}\n" \
    "https://vendor.example/latest/app_${a}.rpm"
done
```

A `latest` URL that redirects to a versioned CDN path gives you both the URL
template and the current version.

Look for a published checksum before defaulting to download-and-hash. A daily
bump that pulls hundreds of MB per arch is slow and times out more often than a
metadata request. In rough order of likelihood:

- rpm repodata: `repomd.xml` names `primary.xml`, whose `<checksum>` per package
  is the SHA256 (`google-chrome-linux`, `warp-linux`).
- apt `Packages` metadata, which carries `Version` and `SHA256` per record
  (`signal-desktop-linux`).
- A `.sha256` sidecar next to the artifact (`tailscale-linux`). It doubles as an
  existence check for that version.
- A vendor update API with a hash field (`visual-studio-code-linux`), or a
  GitHub release asset's `digest` (`zed-linux`, `framework-tool`).

Some vendors publish nothing at all (Zoom, 1Password, Cursor); those fetch
scripts download the artifact and pipe it through `sha256sum`.

If the artifact is a signed RPM, verify it in the fetch script and pin the
fingerprint (§4). Check with:

```bash
rpm -qpi app.rpm | grep -i signature
```

Extract the payload and look at what is in it:

```bash
rpm2cpio app.rpm | cpio -idm --quiet      # rpm
ar x app.deb && tar -xf data.tar.xz       # deb
```

Find the real entry point (`/usr/bin/foo` is often a symlink into `/opt`), the
`.desktop` file, and the icon plus its pixel size (`file icon.png`).

The Workbench image is not Fedora Workstation, so check what the binary needs
and does not bundle:

```bash
LD_LIBRARY_PATH=. ldd opt/app/app | grep 'not found' | sort -u
```

Anything missing needs a `depends_on formula:` and, usually, a symlink into the
app's own library directory (Zoom's `ZoomLauncher` overwrites `LD_LIBRARY_PATH`
before exec'ing the real binary, so an exported path does not reach it).

Launchers vary. If one resolves its install directory through `/proc/self/exe`,
Homebrew's `binary` symlink works. Test that before relying on it: symlink the
launcher into a temp dir and run it.

## 2. Write the cask

Name it `<upstream>-linux`. Conventions that hold across the tap:

- `os linux: "linux"` on every cask.
- Single arch: `depends_on arch: :x86_64`. The `arch intel:/arm:` stanza is only
  for interpolating `#{arch}` into a URL, so a single-arch cask does not use it.
- Dual arch: `sha256 arm64_linux: "...", x86_64_linux: "..."`.
- `url` points at the versioned CDN path, never `latest`. Add
  `verified: "host/path/"` when the download host differs from the homepage.
- `livecheck` is mandatory. `strategy :json` for a version API, `:page_match`
  for apt/rpm metadata, `:github_latest` for GitHub releases. Verify it with
  `brew livecheck` (§5) before committing.
- Extract the payload in `preflight` with `system_command`, then rewrite the
  `.desktop` file's `Exec=` to `#{HOMEBREW_PREFIX}/bin/<binary>` and `Icon=` to
  the absolute installed icon path.
- `.desktop` files and icons go to `#{Dir.home}/.local/share/...` via `artifact`
  stanzas. (`google-chrome-linux` uses `HOMEBREW_PREFIX/share`; the newer casks
  do not.)
- `zap trash:` lists user-level paths only. Root-owned paths cannot be removed
  by a user-run `zap`.
- If the app registers a URL scheme, run `update-desktop-database` on
  `~/.local/share/applications` in `postflight`, or the handler does not
  resolve until something else refreshes the cache.

User-editable config files are never `artifact` targets. An `artifact` is
cask-owned: it moves the file in on install and back out on uninstall, and
errors when the target already exists (`It seems there is already a Generic
Artifact at ...`). Point one at `~/.config/<app>/settings.json` and the first
install works while every upgrade after it fails. Write those files from
`postflight` instead, either seeded once behind a `File.exist?` guard when the
user owns the value, or set on every install when Workbench needs it enforced
(Zoom's `showSystemTitlebar`, Chrome's `custom_chrome_frame`). `postflight` also
runs only after artifact placement succeeds, so a failed install leaves no
config behind.

### Window decorations

Workbench draws window decorations in the compositor, so an app should use the
system title bar rather than its own. Most apps that draw their own have a
setting for it, and every cask that needs one sets it: Zed's
`"window_decorations" => "server"`, VS Code's
`"window.titleBarStyle" => "native"`, Chrome's `custom_chrome_frame = false`,
Zoom's `showSystemTitlebar=true` in `~/.config/zoomus.conf`.

Find the setting the same way as any other config: launch the app, toggle the
option in its preferences, and diff its config file to see which key changed.
Then set that key from `postflight` following the rules above.

Check the result after installing. A decorated window has the Workbench title
bar and buttons; an undecorated one has the app's own. If the app has no such
setting, or the setting exists and the window still comes up undecorated, say so
plainly rather than shipping it quietly, and name what was tried.

## 3. Comments

Comment only what the code cannot show: an upstream quirk, a constraint that
rules out the obvious approach, where a pinned fingerprint came from. No comment
restating the line below it, no explaining why a signature check is a good idea,
and no claims about what a vendor does that you have not verified. Match the
comment density of the casks already in `Casks/`.

## 4. The bump trio

Copy the closest existing set and adjust. Rules:

- `jq` for JSON, never `python3`. `jq -er` exits non-zero on a null result, which
  gives the error path for free.
- Fetch script outputs `KEY=VALUE` lines only (`VERSION=`, `SHA256=`, or
  `SHA256_ARM64=`/`SHA256_X86_64=`) so the workflow can append to
  `$GITHUB_OUTPUT`.
- Bump script exits 0 without changes when already at that version, verifies the
  artifact URL returns 200, `sed`s the cask, and echoes `CHANGED=true`.
- If the artifact is signed, verify before emitting the hash: import the vendor
  key into a throwaway `--dbpath`, require `rpmkeys --checksig` to exit 0 (digest
  coverage) and its output to name the pinned fingerprint (key coverage). Both
  checks are needed, because the header signature stays valid when the payload
  has been altered. `rpmkeys` is not on `ubuntu-latest`, so the workflow
  installs `rpm` first.
- Workflow: clone `bump-signal.yml`. Daily `0 8 * * *`, branch `auto/<name>`,
  commit and title `chore(<name>): bump to $VERSION`, `HOMEBREW_TAP_PAT` (the
  default token cannot trigger CI on its own PR), then `gh pr merge --auto`.

Run the fetch script in a container matching CI's tool set to prove it has no
undeclared dependency:

```bash
podman run --rm -v "$PWD:/tap:ro,z" fedora:43 bash -c \
  'dnf install -y -q rpm curl jq >/dev/null 2>&1; /tap/scripts/fetch-<name>-version'
```

## 5. Verification ladder

Run all of it before proposing a commit.

```bash
bash -n scripts/fetch-<name>-version
brew style Casks/<name>-linux.rb        # one frozen_string_literal offense is expected
scripts/test-install <name>-linux       # full install in fedora:43 via podman
```

`brew` refuses casks outside a tap, so `livecheck` and host installs need the
cask copied into the local tap clone:

```bash
TAP=$(brew --repository caligraltd/tap)
cp Casks/<name>-linux.rb "$TAP/Casks/"
HOMEBREW_NO_INSTALL_FROM_API=1 brew livecheck --cask caligraltd/tap/<name>-linux
HOMEBREW_NO_INSTALL_FROM_API=1 HOMEBREW_NO_AUTO_UPDATE=1 \
  brew install --cask caligraltd/tap/<name>-linux
```

Delete that copy once the change is merged, or `brew update` hits an
untracked-file conflict.

After a host install, check the artifacts rather than trusting the log:

```bash
ls -l "$(brew --prefix)/bin/<binary>"
grep -E '^(Exec|Icon)=' ~/.local/share/applications/<App>.desktop
gio mime x-scheme-handler/<scheme>
```

Do not launch a GUI app to "verify" it without asking; it puts a window on the
user's screen. Decorations are the one thing that cannot be checked any other
way, so ask the user to launch it, or ask permission to launch it yourself, and
report what the window looks like.

## 6. Land it

Add the `brew install --cask <name>-linux` line to the README. The log's
convention for a new cask is a subject and no body:

```
feat(<name>): add cask with auto-bump workflow
```

Push the branch, open the PR, and leave the worktree in place until it merges.
Then confirm the commits landed before removing anything:

```bash
git fetch origin && git log --oneline origin/main | head -5
```

Removing a worktree throws away anything still only on its branch, so do it
after that check, not before (`git worktree remove <path>` and
`git branch -d <branch>`). Delete the tap-clone copy from §5 at the same time.

## Formulas and source-only software

The tap is casks only. A formula is right when the software is a CLI built from
source and its dependencies are ordinary Homebrew formulae; in that case follow
Homebrew's own formula docs, and the same trio still applies for bumping.

For heavy source-only GUI apps (Qt/C++ media tools such as xstudio or OpenRV),
do not write a from-source formula. Nobody installing an app should have to wait
out a multi-hour dependency compile, and these projects vendor their own
dependency systems (vcpkg, a pinned Qt SDK) rather than using Homebrew
formulae. The path is build once in a container, host a relocatable blob, then
cask the blob.

Build on the toolchain upstream supports, which is usually older than what
Fedora ships: 2023-era dependency
sets fail on gcc 13+ (dropped transitive `<cstdint>`, C++98 sources, CPython
miscompiles), and an older glibc makes the artifact run forward onto Workbench
while the reverse does not hold. Persist the Qt install, dependency sources, and
any build cache on a bind mount so a failed run resumes in minutes.
