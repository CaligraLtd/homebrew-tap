cask "zed-linux" do
  arch arm: "aarch64", intel: "x86_64"

  version "0.231.1"
  sha256 arm64_linux:  "f27751e991d16aa53851f17a7e97b87b660b06b83beeec23e43c91133e29e9b4",
         x86_64_linux: "aa844dc6d3e47e8a1c030beb98af90c995deac293260f340b2e2e8cc20c7a942"

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
  artifact "settings.json",
           target: "#{Dir.home}/.config/zed/settings.json"

  preflight do
    FileUtils.mkdir_p("#{Dir.home}/.local/share/applications")
    FileUtils.mkdir_p("#{Dir.home}/.local/share/icons/hicolor/512x512/apps")
    FileUtils.mkdir_p("#{Dir.home}/.local/share/icons/hicolor/1024x1024/apps")
    FileUtils.mkdir_p("#{Dir.home}/.config/zed")

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

    require "json"
    File.write("#{staged_path}/settings.json", JSON.pretty_generate({
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

  zap trash: [
    "~/.config/zed",
    "~/.local/share/zed",
  ]
end
