# Desktop integration for casks

How a cask's app becomes visible to the launcher, the file manager and
the browser on Workbench, and what each step needs. The `/adding-casks`
skill covers the rest of a cask.

## Where the files go

- `.desktop` file: `artifact` to `#{Dir.home}/.local/share/applications/`.
  Keep upstream's file name; it is the desktop ID the portal, `wbopen`
  and `mimeapps.list` refer to.
- Icon: `artifact` to
  `#{Dir.home}/.local/share/icons/hicolor/<size>x<size>/apps/`, using the
  real pixel size (`file icon.png`).
- Rewrite `Exec=` to `#{HOMEBREW_PREFIX}/bin/<binary>` and `Icon=` to the
  absolute icon path before the artifact moves. Upstream files point at
  the paths their own packages install to (`/opt/1Password/1password`),
  and a cask installs nothing there.

## MimeType needs update-desktop-database

GIO (`glib2` 2.86 on Workbench 0.11.0) finds the handlers for a type in a
directory only through that directory's `mimeinfo.cache`. It reads the
`.desktop` file itself, so `Gio.DesktopAppInfo` returns the app with the
right `get_supported_types()`, but `Gio.AppInfo.get_all_for_type()` and
`gio mime <type>` return nothing until the cache exists. A cask that
installs a `.desktop` file with a `MimeType=` line must therefore run
`update-desktop-database` on `~/.local/share/applications` in
`postflight`, in both `shared_prefix` branches. Copy the block from
`zoom-linux.rb`:

```ruby
# shared_prefix: postflight do
system_command "/bin/sh",
               args:         ["-c",
                              "command -v update-desktop-database >/dev/null && " \
                              "update-desktop-database #{apps_dir.shellescape}"],
               must_succeed: false

# postflight_steps do
run "/bin/sh",
    args:           ["-c", "command -v update-desktop-database >/dev/null && " \
                           "update-desktop-database #{Dir.home}/.local/share/applications"],
    writable_paths: [".local/share/applications"], writable_base: :home,
    must_succeed:   false
```

Without it, a URL scheme reaches the portal with no candidates, and
`wbopen` falls back to listing the browsers. For 1Password that broke the
browser sign-in callback (`onepassword://`, workbench#1645). File types
are hit the same way: the app is missing from "Open With".

Once the cache lists an app as the only handler for a type, GIO also
reports it as that type's default. That is what makes a sign-in link open
the app. It is also why a browser must never be registered for a scheme it
does not own (`wbopen/backend/wbopen/choices.py` explains the `mailto`
case).

`postflight` runs on install and upgrade, so users who installed a cask
before its fix get the cache on their next `brew upgrade`.

## Checking it

`scripts/test-install` runs `gio mime` for every type each newly installed
`.desktop` file declares and fails the cask if the file is not listed. CI
runs it on every changed cask, including the bump PRs, so a new cask with
a scheme and no `update-desktop-database` fails before it merges.

On a host install:

```bash
grep -E '^(Exec|Icon|MimeType)=' ~/.local/share/applications/<id>.desktop
gio mime x-scheme-handler/<scheme>   # must list <id>.desktop
```
