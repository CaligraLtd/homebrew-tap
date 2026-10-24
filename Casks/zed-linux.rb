cask "zed-linux" do
  arch arm: "aarch64", intel: "x86_64"

  version "1.25.3"
  sha256 arm64_linux:  "776b3a5e39f1218eacabe1e9fa3859b7a6dda2653522d8a3992a9ab0f2184058",
         x86_64_linux: "35f9115acd8b4c3bea6ed20f7c9b6ec8f1d2c2dd5a1cc438d552167b5ed4b342"

  url "https://github.com/zed-industries/zed/releases/download/v#{version}/zed-linux-#{arch}.tar.gz"
  name "Zed"
  desc "High-performance, multiplayer code editor"
  homepage "https://zed.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  binary "zed.app/bin/zed"
  artifact "dev.zed.Zed.desktop",
           target: "#{Dir.home}/.local/share/applications/dev.zed.Zed.desktop"
  # Zed's self-updater rsyncs each release over `zed.app` with `--delete`, so
  # nothing Homebrew moves may come from inside it.
  artifact "zed-512.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/zed.png"
  artifact "zed-1024.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/1024x1024/apps/zed.png"

  # Installs from before the change above can't be upgraded once Zed has
  # updated itself: the rsync replaced the icon symlinks Homebrew left in
  # `zed.app` with files, and an upgrade that trips over them aborts after
  # moving the `.desktop` file back into the Caskroom, without rolling back.
  # Homebrew takes the old version's artifacts from the install receipt, so no
  # flight block runs before that; repair the Caskroom when the cask loads.
  # Each moved artifact's source must be a symlink to an existing target.
  begin
    receipt_path = caskroom_path/".metadata/INSTALL_RECEIPT.json"
    if receipt_path.exist?
      require "json"
      receipt = JSON.parse(receipt_path.read)
      installed_path = caskroom_path/receipt.dig("source", "version").to_s
      if installed_path.directory? && installed_path != caskroom_path
        receipt.fetch("uninstall_artifacts", []).each do |entry|
          source, options = entry["artifact"]
          next if !source.is_a?(String) || !options.is_a?(Hash) || !options["target"].is_a?(String)

          source = installed_path/source
          target = Pathname(options["target"])
          next if source.symlink? && source.readlink == target && target.exist?

          target.dirname.mkpath
          if source.symlink? || !source.exist?
            source.unlink if source.symlink?
            FileUtils.touch(target) unless target.exist?
          elsif target.exist?
            FileUtils.rm_r(source)
          else
            FileUtils.mv(source, target)
          end
          source.dirname.mkpath
          source.make_symlink(target)
        end
      end
    end
  rescue => e
    opoo "Could not repair the zed-linux Caskroom: #{e.message}"
  end

  # Workbench 0.10.32 and older share a root-owned `/home/linuxbrew` prefix.
  # Homebrew chmods `$HOMEBREW_PREFIX/bin` after every `*_steps` block, which
  # fails there, so those machines keep the Ruby blocks.
  shared_prefix = !File.owned?("#{HOMEBREW_PREFIX}/bin")

  if shared_prefix
    preflight do
      FileUtils.mkdir_p("#{Dir.home}/.local/share/applications")
      FileUtils.mkdir_p("#{Dir.home}/.local/share/icons/hicolor/512x512/apps")
      FileUtils.mkdir_p("#{Dir.home}/.local/share/icons/hicolor/1024x1024/apps")

      FileUtils.cp("#{staged_path}/zed.app/share/icons/hicolor/512x512/apps/zed.png", "#{staged_path}/zed-512.png")
      FileUtils.cp("#{staged_path}/zed.app/share/icons/hicolor/1024x1024/apps/zed.png", "#{staged_path}/zed-1024.png")

      File.write("#{staged_path}/dev.zed.Zed.desktop", <<~EOS)
        [Desktop Entry]
        Version=1.0
        Type=Application
        Name=Zed
        GenericName=Text Editor
        Comment=A high-performance, multiplayer code editor.
        TryExec=#{HOMEBREW_PREFIX}/bin/zed
        StartupNotify=true
        Exec=#{HOMEBREW_PREFIX}/bin/zed %U
        Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/zed.png
        Categories=Utility;TextEditor;Development;IDE;
        Keywords=zed;
        MimeType=text/plain;application/x-zerosize;x-scheme-handler/zed;
        Actions=NewWorkspace;

        [Desktop Action NewWorkspace]
        Exec=#{HOMEBREW_PREFIX}/bin/zed --new %U
        Name=Open a new workspace
      EOS
    end
  else
    preflight_steps do
      mkdir_p ".local/share/applications", base: :home
      mkdir_p ".local/share/icons/hicolor/512x512/apps", base: :home
      mkdir_p ".local/share/icons/hicolor/1024x1024/apps", base: :home

      copy "zed.app/share/icons/hicolor/512x512/apps/zed.png", "zed-512.png"
      copy "zed.app/share/icons/hicolor/1024x1024/apps/zed.png", "zed-1024.png"

      write_file "dev.zed.Zed.desktop", <<~EOS
        [Desktop Entry]
        Version=1.0
        Type=Application
        Name=Zed
        GenericName=Text Editor
        Comment=A high-performance, multiplayer code editor.
        TryExec={{HOMEBREW_PREFIX}}/bin/zed
        StartupNotify=true
        Exec={{HOMEBREW_PREFIX}}/bin/zed %U
        Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/zed.png
        Categories=Utility;TextEditor;Development;IDE;
        Keywords=zed;
        MimeType=text/plain;application/x-zerosize;x-scheme-handler/zed;
        Actions=NewWorkspace;

        [Desktop Action NewWorkspace]
        Exec={{HOMEBREW_PREFIX}}/bin/zed --new %U
        Name=Open a new workspace
      EOS
    end
  end

  if shared_prefix
    postflight do
      # Seed default settings only on first install so user edits survive upgrades.
      settings_path = "#{Dir.home}/.config/zed/settings.json"
      unless File.exist?(settings_path)
        FileUtils.mkdir_p(File.dirname(settings_path))
        require "json"
        File.write(settings_path, JSON.pretty_generate({
          "ui_font_family"       => "Söhne",
          "buffer_font_family"   => "Söhne Mono",
          "ui_font_features"     => { "zero" => true, "ss02" => true },
          "buffer_font_features" => { "zero" => true, "ss02" => true },
          "ui_font_size"         => 16,
          "buffer_font_size"     => 15,
          "theme"                => { "mode" => "system", "light" => "One Light", "dark" => "One Dark" },
          "window_decorations"   => "server",
          "auto_update"          => false,
        }))
      end

      apps_dir = "#{Dir.home}/.local/share/applications"
      system_command "/bin/sh",
                     args:         ["-c",
                                    "command -v update-desktop-database >/dev/null && " \
                                    "update-desktop-database #{apps_dir.shellescape}"],
                     must_succeed: false
    end
  else
    postflight_steps do
      # Seed default settings only on first install so user edits survive upgrades.
      unless_path_exists ".config/zed/settings.json", base: :home do
        write_file ".config/zed/settings.json", <<~JSON, base: :home
          {
            "ui_font_family": "Söhne",
            "buffer_font_family": "Söhne Mono",
            "ui_font_features": {
              "zero": true,
              "ss02": true
            },
            "buffer_font_features": {
              "zero": true,
              "ss02": true
            },
            "ui_font_size": 16,
            "buffer_font_size": 15,
            "theme": {
              "mode": "system",
              "light": "One Light",
              "dark": "One Dark"
            },
            "window_decorations": "server",
            "auto_update": false
          }
        JSON
      end

      run "/bin/sh",
          args:           ["-c", "command -v update-desktop-database >/dev/null && " \
                                 "update-desktop-database #{Dir.home}/.local/share/applications"],
          writable_paths: [".local/share/applications"], writable_base: :home,
          must_succeed:   false
    end
  end

  zap trash: [
    "~/.config/zed",
    "~/.local/share/zed",
  ]
end
