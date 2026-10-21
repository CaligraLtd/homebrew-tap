cask "signal-desktop-linux" do
  os linux: "linux"

  version "8.32.0"
  sha256 "5cbca1616cac7273fd1f06b62d3e0e6a23088252dd11bbcdb4b6a3eb28d7c8de"

  # Signal ships Linux only as an amd64 .deb from its apt repo.
  # The stable pool path is `pool/s/signal-desktop/`; beta lives
  # under `pool/main/s/signal-desktop-beta/`.
  url "https://updates.signal.org/desktop/apt/pool/s/signal-desktop/signal-desktop_#{version}_amd64.deb"
  name "Signal"
  desc "Private messaging from your desktop"
  homepage "https://signal.org/"

  livecheck do
    url "https://updates.signal.org/desktop/apt/dists/xenial/main/binary-amd64/Packages"
    regex(/^Package: signal-desktop\n(?:.+\n)*?Version: (\S+)/)
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

  # Workbench 0.10.32 and older share a root-owned `/home/linuxbrew` prefix.
  # Homebrew chmods `$HOMEBREW_PREFIX/bin` after every `*_steps` block, which
  # fails there, so those machines keep the Ruby blocks.
  shared_prefix = !File.owned?("#{HOMEBREW_PREFIX}/bin")

  if shared_prefix
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
  else
    preflight_steps do
      # A .deb is an `ar` archive wrapping data.tar.xz. Homebrew leaves the package
      # file in place (no auto-unpack), so extract it ourselves into staged_path.
      run "/bin/sh", args: ["-c", "ar x signal-desktop_{{version}}_amd64.deb && tar -xf data.tar.xz"], chdir: "."

      mkdir_p ".local/share/applications", base: :home
      mkdir_p ".local/share/icons/hicolor/512x512/apps", base: :home

      copy "usr/share/applications/signal-desktop.desktop", "signal-desktop.desktop"
      inreplace "signal-desktop.desktop", /^Exec=.*$/, "Exec={{HOMEBREW_PREFIX}}/bin/signal-desktop %U", global: false
      inreplace "signal-desktop.desktop", /^Icon=.*$/, "Icon=#{icon}", global: false
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
    "~/.cache/Signal",
    "~/.config/Signal",
  ]
end
