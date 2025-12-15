cask "google-chrome-linux" do
  version :latest
  sha256 :no_check

  url "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
  name "Google Chrome"
  desc "Web browser from Google"
  homepage "https://www.google.com/chrome/"

  depends_on arch: :x86_64

  binary "#{staged_path}/opt/google/chrome/google-chrome"
  binary "#{staged_path}/opt/google/chrome/google-chrome", target: "google-chrome-stable"
  artifact "google-chrome.desktop",
           target: "#{Dir.home}/.local/share/applications/google-chrome.desktop"
  artifact "google-chrome.png",
           target: "#{Dir.home}/.local/share/icons/google-chrome.png"

  preflight do
    FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
    FileUtils.mkdir_p "#{Dir.home}/.local/share/icons"

    # Check architecture
    if Hardware::CPU.arm?
      opoo "Google Chrome is not available for ARM architecture."
      opoo "Please use Chromium instead"
      raise "Unsupported architecture: ARM"
    end

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
    new_contents = new_contents.gsub(/Icon=.*/, "Icon=#{Dir.home}/.local/share/icons/google-chrome.png")
    File.write("#{staged_path}/google-chrome.desktop", new_contents)
  end

  zap trash: [
    "~/.cache/google-chrome",
    "~/.config/google-chrome",
  ]
end
