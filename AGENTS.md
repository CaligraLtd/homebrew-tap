# AGENTS.md

Guidance for coding agents. Untracked local guidance may exist next to
this file (`AGENTS.override.md`, `CLAUDE.local.md`); read it when present.

## What this is

The Homebrew tap Workbench users install Linux GUI apps from
(`brew install <name>-linux`, tapped as `caligraltd/tap`). Casks only, in
Ruby, one per file in `Casks/`. Each cask unpacks an upstream tarball,
`.rpm` or `.deb` into the user's Homebrew prefix and puts its `.desktop`
file and icon under `~/.local/share` so the launcher and the portal can
find it.

## Status

Customers install from `main` directly: a merged cask reaches every
Workbench machine on its next `brew update`, with no release step and no
rollback. Bump PRs from the `auto/<name>` workflows are approved and
merged by CI with no human review, so `scripts/test-install` is the only
gate between an upstream release and users. Product context:
`../workbench/AGENTS.md`.

## Commands

```bash
scripts/test-install <cask>...   # install in fedora:43 via podman; what CI runs
scripts/test-install --all       # every cask
```

Adding or bumping a cask is the `/adding-casks` skill
(`.agents/skills/adding-casks/SKILL.md`); read it before touching a cask.

## Architecture

- Every cask that has flight blocks has them twice, selected by
  `shared_prefix`: Ruby `preflight`/`postflight` for Workbench 0.10.32 and
  older (root-owned `/home/linuxbrew`), `*_steps` blocks for the per-user
  `~/.b` prefix. A behaviour change lands in both branches.
- In `*_steps` blocks, edit files with `inreplace`, not `sed -i`.
- `scripts/fetch-<name>-version`, `scripts/bump-<name>-cask` and
  `.github/workflows/bump-<name>.yml` are the auto-bump trio for each
  cask.

## Pitfalls

- A `.desktop` file with a `MimeType=` line handles nothing until
  `update-desktop-database` rebuilds `~/.local/share/applications/mimeinfo.cache`.
  1Password shipped without it, and its browser sign-in offered only the
  browsers (workbench#1645). `scripts/test-install` fails a cask whose
  declared types `gio mime` cannot resolve. The rules for desktop files,
  icons and URL schemes are in `.agents/DESKTOP-INTEGRATION.md`.
- User-editable config files are never `artifact` targets; the second
  install fails on the existing file. Write them from `postflight`.
