cask "warp-linux" do
  arch arm: "aarch64", intel: "x86_64"

  version "0.2026.08.26.17.59.stable_01"
  sha256 arm64_linux:  "ce9d4f3f43d2f379c06b01d994266be0c3f4555e9df57a18ef6f93a72b0b29e6",
         x86_64_linux: "c1bfcb1893daf10516d151f0ff37122eb2b7bcd8ee8bf05208b776e853c92460"

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
