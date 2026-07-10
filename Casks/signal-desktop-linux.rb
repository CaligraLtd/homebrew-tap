cask "signal-desktop-linux" do
  os linux: "linux"

  version "8.18.0"
  sha256 "8ee4e5de58d55c1b84a525bda9b26308b2efed050f58cc6d5fd16367d4b50477"

  # Signal ships Linux only as an amd64 .deb from its apt repo.
  # The stable pool path is `pool/s/signal-desktop/`; beta lives
  # under `pool/main/s/signal-desktop-beta/`.
  url "https://updates.signal.org/desktop/apt/pool/s/signal-desktop/signal-desktop_#{version}_amd64.deb",
      verified: "updates.signal.org/"
  name "Signal"
  desc "Private messaging from your desktop"
  homepage "https://signal.org/"

  livecheck do
    url "https://updates.signal.org/desktop/apt/dists/xenial/main/binary-amd64/Packages"
    regex(/^Package: signal-desktop\nArchitecture: amd64\nVersion: (\S+)/m)
    strategy :page_match do |page, regex|
      # Filter out ~beta versions; only stable signal-desktop entries.
      page.scan(regex).flatten.reject { |v| v.include?("beta") }
    end
  end

  depends_on arch: :x86_64

  binary "#{staged_path}/opt/Signal/signal-desktop", target: "signal-desktop"
  artifact "signal-desktop.desktop",
           target: "#{Dir.home}/.local/share/applications/signal-desktop.desktop"
  artifact "usr/share/icons/hicolor/512x512/apps/signal-desktop.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/signal-desktop.png"

  preflight do
    # A .deb is an `ar` archive wrapping data.tar.xz. Homebrew leaves the package
    # file in place (no auto-unpack), so extract it ourselves into staged_path.
    deb = "#{staged_path}/signal-desktop_#{version}_amd64.deb"
    system_command "/bin/sh",
                   args:         ["-c", "ar x #{deb.shellescape} && tar -xf data.tar.xz"],
                   chdir:        staged_path,
                   must_succeed: true

    FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
    FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/512x512/apps"

    # Repoint Exec at the Homebrew shim and Icon at the installed absolute path.
    desktop_file = "#{staged_path}/usr/share/applications/signal-desktop.desktop"
    raise "Signal desktop file not found in package" unless File.exist?(desktop_file)

    text = File.read(desktop_file)
    text.sub!(/^Exec=.*$/, "Exec=#{HOMEBREW_PREFIX}/bin/signal-desktop %U")
    text.sub!(/^Icon=.*$/, "Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/signal-desktop.png")
    File.write("#{staged_path}/signal-desktop.desktop", text)
  end

  zap trash: [
    "~/.cache/Signal",
    "~/.config/Signal",
  ]
end
