cask "google-chrome-linux" do
  version :latest
  sha256 :no_check
  os linux: "linux"

  url "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
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
    system "sh", "-c", "cd #{staged_path} && rpm2cpio google-chrome-stable_current_x86_64.rpm | cpio -idmv 2>/dev/null"

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
  end

  postflight do
    # Make Chrome installation directory root-owned for 1Password browser integration
    # 1Password's security verification requires browser binaries to be in tamper-proof locations
    chrome_dir = "#{HOMEBREW_PREFIX}/Caskroom/google-chrome-linux/latest/opt/google/chrome"
    system "sudo", "chown", "-R", "root:root", chrome_dir
    puts "Set Chrome directory to root ownership for 1Password integration"
  end

  uninstall_preflight do
    # Change ownership back to allow homebrew to clean up
    chrome_dir = "#{HOMEBREW_PREFIX}/Caskroom/google-chrome-linux/latest/opt/google/chrome"
    current_user = ENV["USER"]
    system "sudo", "chown", "-R", "#{current_user}:#{current_user}", chrome_dir
  end

  zap trash: [
    "~/.cache/google-chrome",
    "~/.config/google-chrome",
  ]
end
