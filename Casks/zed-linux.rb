cask "zed-linux" do
  arch arm: "aarch64", intel: "x86_64"

  version "1.4.4"
  sha256 arm64_linux:  "caaa316a4cc2bd6e723bf3a959fb346dc16689148d54a35dc166180f548e8b23",
         x86_64_linux: "e5c80658824c47f1cf28ed73441cf26a5d1d62807bafcc0385cf239298e39cf0"

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

  postflight do
    # Seed default settings only on first install so user edits survive upgrades.
    settings_path = "#{Dir.home}/.config/zed/settings.json"
    unless File.exist?(settings_path)
      FileUtils.mkdir_p(File.dirname(settings_path))
      require "json"
      File.write(settings_path, JSON.pretty_generate({
        "ui_font_family" => "Söhne",
        "buffer_font_family" => "Söhne Mono",
        "ui_font_features" => { "zero" => true, "ss02" => true },
        "buffer_font_features" => { "zero" => true, "ss02" => true },
        "ui_font_size" => 16,
        "buffer_font_size" => 15,
        "theme" => { "mode" => "system", "light" => "One Light", "dark" => "One Dark" },
        "window_decorations" => "server",
      }))
    end
  end

  zap trash: [
    "~/.config/zed",
    "~/.local/share/zed",
  ]
end
