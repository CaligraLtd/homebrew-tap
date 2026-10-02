cask "warp-linux" do
  arch arm: "aarch64", intel: "x86_64"

  version "0.2026.09.30.08.29.stable_01"
  sha256 arm64_linux:  "2a2d5a6ea3ac9ba31fc16071199c535c9422756539e7e9f7bc33df70a4b41683",
         x86_64_linux: "cb750a5d87f18fb1a1a546eebe0e32c771f1507bf934c2916d3ff6e6b3e214ab"

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

  # Workbench 0.10.32 and older share a root-owned `/home/linuxbrew` prefix.
  # Homebrew chmods `$HOMEBREW_PREFIX/bin` after every `*_steps` block, which
  # fails there, so those machines keep the Ruby blocks.
  shared_prefix = !File.owned?("#{HOMEBREW_PREFIX}/bin")

  if shared_prefix
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
  else
    preflight_steps do
      run "/bin/sh", args: ["-c", "rpm2cpio #{rpm} | cpio -idm --quiet"], chdir: "."
      run "sed", args: ["-i",
                        "-e", "0,/^Exec=/s|^Exec=.*|Exec={{HOMEBREW_PREFIX}}/bin/warp-terminal %U|",
                        "-e", "0,/^Icon=/s|^Icon=.*|Icon=#{icon}|",
                        "usr/share/applications/dev.warp.Warp.desktop"], chdir: "."
    end
  end

  zap trash: [
    "~/.cache/warp-terminal",
    "~/.config/warp-terminal",
    "~/.local/share/warp-terminal",
  ]
end
