cask "zed-linux" do
  arch arm: "aarch64", intel: "x86_64"

  version "1.23.2"
  sha256 arm64_linux:  "882dc2dc0ba316cd5efbdf566eb91a473bd462da3a8c284f3a5bcc96b1e9a7cc",
         x86_64_linux: "cabddd5af2b26a19633ea39f5dde070e2aad204bb815bfa74cb65073ffd5ff39"

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
    end
  end

  zap trash: [
    "~/.config/zed",
    "~/.local/share/zed",
  ]
end
