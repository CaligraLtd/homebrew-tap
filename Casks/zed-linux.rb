cask "zed-linux" do
  arch arm: "aarch64", intel: "x86_64"

  version "1.24.4"
  sha256 arm64_linux:  "2b2c436f197a2c1197f2f7fd73220ef6f5af89462d95de970ff043d49e8a4700",
         x86_64_linux: "ecf2a7969fc71f74a7392b5022c3037c526108f9fe4b6da60355e259cd0dd4d2"

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
  artifact "zed.app/share/icons/hicolor/512x512/apps/zed.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/zed.png"
  artifact "zed.app/share/icons/hicolor/1024x1024/apps/zed.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/1024x1024/apps/zed.png"

  # Workbench 0.10.32 and older share a root-owned `/home/linuxbrew` prefix.
  # Homebrew chmods `$HOMEBREW_PREFIX/bin` after every `*_steps` block, which
  # fails there, so those machines keep the Ruby blocks.
  shared_prefix = !File.owned?("#{HOMEBREW_PREFIX}/bin")

  if shared_prefix
    preflight do
      FileUtils.mkdir_p("#{Dir.home}/.local/share/applications")
      FileUtils.mkdir_p("#{Dir.home}/.local/share/icons/hicolor/512x512/apps")
      FileUtils.mkdir_p("#{Dir.home}/.local/share/icons/hicolor/1024x1024/apps")

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
            "window_decorations": "server"
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
