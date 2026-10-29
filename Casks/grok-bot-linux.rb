cask "grok-bot-linux" do
  arch arm: "arm64", intel: "amd64"
  os linux: "linux"

  version "0.78.1"
  sha256 arm64_linux:  "ed9f29cc1fa147267d9171916caa7b44ecbfc36d766c8d7f2ce089bddc2da94d",
         x86_64_linux: "55d2a34cfff762342251ffa9b1321a70f08b603f227f886e18b2c1c5e73ded1d"

  # The .deb, not the AppImage: run as an AppImage, Grok Bot rewrites its
  # .desktop file on every launch and turns its own updater back on.
  url "https://downloads.cursor.com/aptrepo/pool/grok-bot/g/gr/grok-bot_#{version}_#{arch}.deb"
  name "Grok Bot"
  desc "Always-on AI teammates from xAI"
  homepage "https://x.ai/bot"

  livecheck do
    url "https://downloads.cursor.com/aptrepo/dists/grok-bot/main/binary-amd64/Packages"
    regex(/^Package: grok-bot\n(?:.+\n)*?Version: (\d+(?:\.\d+)+)$/)
  end

  deb = "grok-bot_#{version}_#{arch}.deb"
  icon = "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/grok-bot.png"
  extract = "ar x #{deb} && tar -xf data.tar.*"

  binary "#{staged_path}/opt/Grok Bot/grok-bot", target: "grok-bot"
  artifact "grok-bot.desktop",
           target: "#{Dir.home}/.local/share/applications/grok-bot.desktop"
  artifact "usr/share/icons/hicolor/512x512/apps/grok-bot.png",
           target: icon

  # Workbench 0.10.32 and older share a root-owned `/home/linuxbrew` prefix.
  # Homebrew chmods `$HOMEBREW_PREFIX/bin` after every `*_steps` block, which
  # fails there, so those machines keep the Ruby blocks.
  shared_prefix = !File.owned?("#{HOMEBREW_PREFIX}/bin")

  if shared_prefix
    preflight do
      system_command "/bin/sh", args: ["-c", extract], chdir: staged_path, must_succeed: true

      FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
      FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/512x512/apps"

      # Keep the `-- %U` after Exec: the login comes back as a grokbot:// link.
      text = File.read("#{staged_path}/usr/share/applications/grok-bot.desktop")
      text.sub!(/^Exec=.*$/, "Exec=#{HOMEBREW_PREFIX}/bin/grok-bot -- %U")
      text.sub!(/^Icon=.*$/, "Icon=#{icon}")
      File.write("#{staged_path}/grok-bot.desktop", text)
    end
  else
    preflight_steps do
      run "/bin/sh", args: ["-c", extract], chdir: "."

      mkdir_p ".local/share/applications", base: :home
      mkdir_p ".local/share/icons/hicolor/512x512/apps", base: :home

      # Keep the `-- %U` after Exec: the login comes back as a grokbot:// link.
      copy "usr/share/applications/grok-bot.desktop", "grok-bot.desktop"
      inreplace "grok-bot.desktop", /^Exec=.*$/, "Exec={{HOMEBREW_PREFIX}}/bin/grok-bot -- %U", global: false
      inreplace "grok-bot.desktop", /^Icon=.*$/, "Icon=#{icon}", global: false
    end
  end

  # GIO reads mimeinfo.cache, not the desktop files, so grokbot:// links do not
  # reach Grok Bot until the cache is regenerated.
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
    "~/.config/Grok Bot",
    "~/.grokbot",
  ]
end
