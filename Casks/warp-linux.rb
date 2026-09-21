cask "warp-linux" do
  arch arm: "aarch64", intel: "x86_64"

  version "0.2026.09.16.08.27.stable_02"
  sha256 arm64_linux:  "de0a471eb09faea6e39966d689ec88b8db77999619994e41c78fdfc6dfc177f9",
         x86_64_linux: "b3c7010d8bbd2de555fc4a10b5fcbe17af64eea7827cc1da6cd999c3b5ed519d"

  url "https://releases.warp.dev/stable/v#{version}/warp-terminal-v#{version}-1.#{arch}.rpm"
  name "Warp"
  desc "Rust-based terminal for developers and teams"
  homepage "https://www.warp.dev/"

  livecheck do
    url "https://releases.warp.dev/linux/deb/dists/stable/main/binary-amd64/Packages"
    regex(/^Package: warp-terminal\nArchitecture: amd64\nVersion: (\S+)/m)
    strategy :page_match do |page, regex|
      page.scan(regex).map { |m| m.first.sub(/\.(\d+)\z/, '_\1') }
    end
  end

  rpm = "warp-terminal-v#{version}-1.#{arch}.rpm"
  icon = "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/dev.warp.Warp.png"

  binary "opt/warpdotdev/warp-terminal/warp", target: "warp-terminal"
  artifact "usr/share/applications/dev.warp.Warp.desktop",
           target: "#{Dir.home}/.local/share/applications/dev.warp.Warp.desktop"
  artifact "usr/share/icons/hicolor/512x512/apps/dev.warp.Warp.png",
           target: icon

  preflight_steps do
    run "/bin/sh", args: ["-c", "rpm2cpio #{rpm} | cpio -idm --quiet"], chdir: "."
    run "sed", args: ["-i",
                      "-e", "0,/^Exec=/s|^Exec=.*|Exec={{HOMEBREW_PREFIX}}/bin/warp-terminal %U|",
                      "-e", "0,/^Icon=/s|^Icon=.*|Icon=#{icon}|",
                      "usr/share/applications/dev.warp.Warp.desktop"], chdir: "."
  end

  zap trash: [
    "~/.cache/warp-terminal",
    "~/.config/warp-terminal",
    "~/.local/share/warp-terminal",
  ]
end
