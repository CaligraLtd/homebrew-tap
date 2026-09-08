cask "warp-linux" do
  arch arm: "aarch64", intel: "x86_64"

  version "0.2026.09.09.08.26.stable_02"
  sha256 arm64_linux:  "b4640f9cbd1ccfdd4cc7a7ee6111447eb45ab347662c746e5009d4e8ac588d37",
         x86_64_linux: "774f585ca3d926275d2e26694c4ed625ae114ff12857771c7fbf58459cc398ed"

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
