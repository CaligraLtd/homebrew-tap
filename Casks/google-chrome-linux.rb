cask "google-chrome-linux" do
  version "147.0.7727.55"
  sha256 "8f9b7e8a06da401a62ff23c86b3957161978279966b9c7414e554cd4a213c964"
  os linux: "linux"

  url "https://dl.google.com/linux/chrome/rpm/stable/x86_64/google-chrome-stable-#{version}-1.x86_64.rpm"
  name "Google Chrome"
  desc "Web browser from Google"
  homepage "https://www.google.com/chrome/"

  depends_on arch: :x86_64

  binary "#{staged_path}/opt/google/chrome/google-chrome"
  binary "#{staged_path}/opt/google/chrome/google-chrome", target: "google-chrome-stable"
  artifact "google-chrome.desktop",
           target: "#{HOMEBREW_PREFIX}/share/applications/google-chrome.desktop"
  artifact "google-chrome.png",
           target: "#{HOMEBREW_PREFIX}/share/pixmaps/google-chrome.png"

  preflight do
    # Extract RPM package
    system "sh", "-c", "cd #{staged_path} && rpm2cpio google-chrome-stable-#{version}-1.x86_64.rpm | cpio -idmv 2>/dev/null"

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
    new_contents = new_contents.gsub(/Icon=.*/, "Icon=#{HOMEBREW_PREFIX}/share/pixmaps/google-chrome.png")
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

  zap trash: [
    "~/.cache/google-chrome",
    "~/.config/google-chrome",
  ]
end
