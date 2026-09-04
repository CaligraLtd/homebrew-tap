require "etc"

cask "google-chrome-linux" do
  version "152.0.7977.82"
  sha256 "22314c7d75648e12cfd94c6f5af3fa5e45d30a26de519f3086fca98ec0021a97"
  os linux: "linux"

  url "https://dl.google.com/linux/chrome/rpm/stable/x86_64/google-chrome-stable-#{version}-1.x86_64.rpm"
  name "Google Chrome"
  desc "Web browser from Google"
  homepage "https://www.google.com/chrome/"

  depends_on arch: :x86_64
  depends_on cask: "caligraltd/tap/microsoft-core-fonts-linux"
  depends_on cask: "font-noto-color-emoji"

  binary "#{staged_path}/opt/google/chrome/google-chrome"
  binary "#{staged_path}/opt/google/chrome/google-chrome", target: "google-chrome-stable"
  artifact "google-chrome.desktop",
           target: "#{Dir.home}/.local/share/applications/google-chrome.desktop"
  artifact "google-chrome.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/256x256/apps/google-chrome.png"

  preflight do
    system_command "bash",
                   args: ["-o", "pipefail", "-c",
                          "rpm2cpio google-chrome-stable-#{version}-1.x86_64.rpm | cpio -idm"],
                   chdir: staged_path,
                   must_succeed: true

    # Copy icon
    icon_source = "#{staged_path}/opt/google/chrome/product_logo_256.png"
    raise "Icon file not found in RPM package" unless File.exist?(icon_source)

    FileUtils.cp icon_source, "#{staged_path}/google-chrome.png"

    # Use the desktop file from the RPM and update Exec paths to point to Homebrew
    desktop_file = "#{staged_path}/usr/share/applications/google-chrome.desktop"
    raise "Desktop file not found in RPM package" unless File.exist?(desktop_file)

    text = File.read(desktop_file)
    # Replace /usr/bin/google-chrome-stable with Homebrew path
    new_contents = text.gsub(%r{/usr/bin/google-chrome-stable}, "#{HOMEBREW_PREFIX}/bin/google-chrome")
    # Update icon path to use the one we copied
    new_contents = new_contents.sub(/^Icon=.*$/,
                                    "Icon=#{Dir.home}/.local/share/icons/hicolor/256x256/apps/google-chrome.png")
    File.write("#{staged_path}/google-chrome.desktop", new_contents)

    # Set up initial preferences for Caligra Workbench
    if File.exist?("/etc/os-release")
      os_release = File.read("/etc/os-release")
      if os_release.include?("Caligra Workbench")
        preferences = {
          "browser" => {
            "custom_chrome_frame" => false,
            "theme" => {
              "is_grayscale" => true,
            },
            "window_placement" => {
              "bottom" => 940,
              "left" => 0,
              "maximized" => false,
              "right" => 1219,
              "top" => 100,
            },
          },
          "first_run_tabs" => [
            "https://caligra.com",
            "https://lobste.rs/",
          ],
        }

        require "json"
        initial_prefs_path = "#{staged_path}/opt/google/chrome/initial_preferences"
        File.write(initial_prefs_path, JSON.pretty_generate(preferences))
      end
    end

    # Inject a hook into Chrome's own launcher to enforce window decorations
    # on all profiles. initial_preferences only covers the Default profile;
    # this catches additional profiles on every launch.
    launcher = "#{staged_path}/opt/google/chrome/google-chrome"
    launcher_script = File.read(launcher)
    patch_block = <<~'BASH'
      for prefs in "$HOME/.config/google-chrome"/*/Preferences; do
        [ -f "$prefs" ] || continue
        tmp="${prefs}.tmp"
        jq '.browser.custom_chrome_frame = false | .browser.theme.is_grayscale = true' "$prefs" > "$tmp" 2>/dev/null && mv "$tmp" "$prefs"
      done
    BASH
    launcher_script.sub!('exec -a "$0"', "#{patch_block}exec -a \"$0\"")
    File.write(launcher, launcher_script)
  end

  postflight do
    # Make Chrome installation directory root-owned for 1Password browser integration.
    # Only runs when 1Password is installed — no reason to require sudo otherwise.
    if Dir.exist?("#{HOMEBREW_PREFIX}/Caskroom/1password-gui-linux")
      chrome_dir = "#{HOMEBREW_PREFIX}/Caskroom/google-chrome-linux/#{version}/opt/google/chrome"
      if system("sudo", "chown", "-R", "root:root", chrome_dir)
        puts "Set Chrome directory to root ownership for 1Password integration"
      else
        puts ""
        puts "WARNING: Could not set Chrome directory to root ownership."
        puts "1Password browser integration requires Chrome to be in a tamper-proof location."
        puts ""
        puts "To set up manually, run:"
        puts "  sudo chown -R root:root #{chrome_dir}"
      end
    end
  end

  uninstall_preflight do
    # Restore ownership if directory is root-owned (from 1Password integration setup)
    chrome_dir = "#{HOMEBREW_PREFIX}/Caskroom/google-chrome-linux/#{version}/opt/google/chrome"
    if File.exist?(chrome_dir) && File.stat(chrome_dir).uid == 0
      current_user = Etc.getpwuid(Process.uid).name
      current_group = Etc.getgrgid(Process.gid).name
      unless system "sudo", "chown", "-R", "#{current_user}:#{current_group}", chrome_dir
        raise "Could not restore ownership on #{chrome_dir}; leaving the installed version untouched. " \
              "Run `sudo chown -R #{current_user}:#{current_group} #{chrome_dir}` and retry."
      end
    end
  end

  zap trash: [
    "~/.cache/google-chrome",
    "~/.config/google-chrome",
  ]
end
