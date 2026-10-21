cask "warp-linux" do
  arch arm: "aarch64", intel: "x86_64"

  version "0.2026.10.14.08.27.stable_02"
  sha256 arm64_linux:  "83a073f6fb3e452754b40cfc216c9e19ba1e5fa58c8426ae1a7e2cc8efb479a6",
         x86_64_linux: "507e862bf211c0bb5734546d86a5f5227fd4043191abe486e239b3bacb348baa"

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
      inreplace "usr/share/applications/dev.warp.Warp.desktop", /^Exec=.*$/,
                "Exec={{HOMEBREW_PREFIX}}/bin/warp-terminal %U", global: false
      inreplace "usr/share/applications/dev.warp.Warp.desktop", /^Icon=.*$/, "Icon=#{icon}", global: false
    end
  end

  if shared_prefix
    postflight do
      apps_dir = "#{Dir.home}/.local/share/applications"
      system_command "/bin/sh",
                     args:         ["-c",
                                    "command -v update-desktop-database >/dev/null && " \
                                    "update-desktop-database #{apps_dir.shellescape}"],
                     must_succeed: false
    end
  else
    postflight_steps do
      run "/bin/sh",
          args:           ["-c", "command -v update-desktop-database >/dev/null && " \
                                 "update-desktop-database #{Dir.home}/.local/share/applications"],
          writable_paths: [".local/share/applications"], writable_base: :home,
          must_succeed:   false
    end
  end

  zap trash: [
    "~/.cache/warp-terminal",
    "~/.config/warp-terminal",
    "~/.local/share/warp-terminal",
  ]
end
