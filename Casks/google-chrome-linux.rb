cask "google-chrome-linux" do
  version "153.0.8010.52"
  sha256 "da5ce705e0ee4cc41c7a6d985c532e6b90796a260644e90949eb64db7c6e1c5f"
  os linux: "linux"

  url "https://dl.google.com/linux/chrome/rpm/stable/x86_64/google-chrome-stable-#{version}-1.x86_64.rpm"
  name "Google Chrome"
  desc "Web browser from Google"
  homepage "https://www.google.com/chrome/"

  depends_on arch: :x86_64
  depends_on cask: "caligraltd/tap/microsoft-core-fonts-linux"
  depends_on cask: "font-noto-color-emoji"

  icon = "#{Dir.home}/.local/share/icons/hicolor/256x256/apps/google-chrome.png"

  binary "#{staged_path}/opt/google/chrome/google-chrome"
  binary "#{staged_path}/opt/google/chrome/google-chrome", target: "google-chrome-stable"
  artifact "google-chrome.desktop",
           target: "#{Dir.home}/.local/share/applications/google-chrome.desktop"
  artifact "google-chrome.png",
           target: icon

  preflight_steps do
    run "/bin/bash",
        args:  ["-o", "pipefail", "-c", "rpm2cpio google-chrome-stable-{{version}}-1.x86_64.rpm | cpio -idm"],
        chdir: "."

    copy "opt/google/chrome/product_logo_256.png", "google-chrome.png"

    copy "usr/share/applications/google-chrome.desktop", "google-chrome.desktop"
    run "sed", args: ["-i",
                      "-e", "s|/usr/bin/google-chrome-stable|{{HOMEBREW_PREFIX}}/bin/google-chrome|g",
                      "-e", "0,/^Icon=/s|^Icon=.*|Icon=#{icon}|",
                      "google-chrome.desktop"], chdir: "."

    # Initial preferences for Caligra Workbench
    write_file "initial_preferences", <<~JSON
      {
        "browser": {
          "custom_chrome_frame": false,
          "theme": {
            "is_grayscale": true
          },
          "window_placement": {
            "bottom": 940,
            "left": 0,
            "maximized": false,
            "right": 1219,
            "top": 100
          }
        },
        "first_run_tabs": [
          "https://caligra.com",
          "https://lobste.rs/"
        ]
      }
    JSON
    run "/bin/sh", args: ["-c", "if grep -q 'Caligra Workbench' /etc/os-release 2>/dev/null; " \
                                "then mv initial_preferences opt/google/chrome/initial_preferences; " \
                                "else rm -f initial_preferences; fi"], chdir: "."
  end

  postflight_steps do
    # Inject a hook into Chrome's own launcher to enforce window decorations
    # on all profiles. initial_preferences only covers the Default profile;
    # this catches additional profiles on every launch.
    inreplace "opt/google/chrome/google-chrome", 'exec -a "$0"', <<~BASH.chomp, global: false
      for prefs in "$HOME/.config/google-chrome"/*/Preferences; do
        [ -f "$prefs" ] || continue
        tmp="${prefs}.tmp"
        jq '.browser.custom_chrome_frame = false | .browser.theme.is_grayscale = true' "$prefs" > "$tmp" 2>/dev/null && mv "$tmp" "$prefs"
      done
      exec -a "$0"
    BASH

    # Make Chrome installation directory root-owned for 1Password browser integration.
    # Only runs when 1Password is installed; no reason to require sudo otherwise.
    if_path_exists "{{HOMEBREW_PREFIX}}/Caskroom/1password-gui-linux" do
      run "chown", args: ["-R", "root:root", "{{staged_path}}/opt/google/chrome"], sudo: true, must_succeed: false
    end
  end

  uninstall_preflight_steps do
    if_path_exists "{{HOMEBREW_PREFIX}}/Caskroom/1password-gui-linux" do
      run "/bin/sh",
          args: ["-c", "chown -R \"$SUDO_UID:$SUDO_GID\" \"$1\"", "sh", "{{staged_path}}/opt/google/chrome"],
          sudo: true
    end
  end

  zap trash: [
    "~/.cache/google-chrome",
    "~/.config/google-chrome",
  ]
end
