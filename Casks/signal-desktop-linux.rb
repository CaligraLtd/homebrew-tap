cask "signal-desktop-linux" do
  os linux: "linux"

  version "8.28.0"
  sha256 "fc7bc0d7ef9f123a297063a5b9dbc0a685011990691e4b258e0d915b06c726f6"

  # Signal ships Linux only as an amd64 .deb from its apt repo.
  # The stable pool path is `pool/s/signal-desktop/`; beta lives
  # under `pool/main/s/signal-desktop-beta/`.
  url "https://updates.signal.org/desktop/apt/pool/s/signal-desktop/signal-desktop_#{version}_amd64.deb"
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

  icon = "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/signal-desktop.png"

  binary "#{staged_path}/opt/Signal/signal-desktop", target: "signal-desktop"
  artifact "signal-desktop.desktop",
           target: "#{Dir.home}/.local/share/applications/signal-desktop.desktop"
  artifact "usr/share/icons/hicolor/512x512/apps/signal-desktop.png",
           target: icon

  preflight_steps do
    # A .deb is an `ar` archive wrapping data.tar.xz. Homebrew leaves the package
    # file in place (no auto-unpack), so extract it ourselves into staged_path.
    run "/bin/sh", args: ["-c", "ar x signal-desktop_{{version}}_amd64.deb && tar -xf data.tar.xz"], chdir: "."

    mkdir_p ".local/share/applications", base: :home
    mkdir_p ".local/share/icons/hicolor/512x512/apps", base: :home

    copy "usr/share/applications/signal-desktop.desktop", "signal-desktop.desktop"
    run "sed", args: ["-i",
                      "-e", "0,/^Exec=/s|^Exec=.*|Exec={{HOMEBREW_PREFIX}}/bin/signal-desktop %U|",
                      "-e", "0,/^Icon=/s|^Icon=.*|Icon=#{icon}|",
                      "signal-desktop.desktop"], chdir: "."
  end

  zap trash: [
    "~/.cache/Signal",
    "~/.config/Signal",
  ]
end
