cask "warp-linux" do
  arch arm: "aarch64", intel: "x86_64"

  version "0.2026.08.12.21.54.stable_00"
  sha256 arm64_linux:  "c67255eab636108aad20290194d672903efb8dc614733ca6047f22063beac29b",
         x86_64_linux: "d1f0b8e3c08c11ac7bf800fca12e5e89891a73355f723ff2daa8bde68ab9a835"

  url "https://releases.warp.dev/stable/v#{version}/warp-terminal-v#{version}-1.#{arch}.rpm",
      verified: "releases.warp.dev/"
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

  binary "opt/warpdotdev/warp-terminal/warp", target: "warp-terminal"
  artifact "usr/share/applications/dev.warp.Warp.desktop",
           target: "#{Dir.home}/.local/share/applications/dev.warp.Warp.desktop"
  artifact "usr/share/icons/hicolor/512x512/apps/dev.warp.Warp.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/dev.warp.Warp.png"

  preflight do
    rpm_path = "#{staged_path}/warp-terminal-v#{version}-1.#{arch}.rpm"
    system_command "/bin/sh",
                   args:  ["-c", "rpm2cpio #{rpm_path.shellescape} | cpio -idm --quiet"],
                   chdir: staged_path

    desktop_file = "#{staged_path}/usr/share/applications/dev.warp.Warp.desktop"
    content = File.read(desktop_file)
    content.sub!(/^Exec=.*$/, "Exec=#{HOMEBREW_PREFIX}/bin/warp-terminal %U")
    content.sub!(/^Icon=.*$/, "Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/dev.warp.Warp.png")
    File.write(desktop_file, content)
  end

  zap trash: [
    "~/.cache/warp-terminal",
    "~/.config/warp-terminal",
    "~/.local/share/warp-terminal",
  ]
end
