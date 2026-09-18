# Originally from https://github.com/ublue-os/homebrew-tap/blob/main/Casks/visual-studio-code-linux.rb
cask "visual-studio-code-linux" do
  arch arm: "arm64", intel: "x64"
  os linux: "linux"

  version "1.138.0"
  sha256 arm64_linux:  "bf01adb1919abf5a556b49e5d528440440cc9a875fb7b4bf7a5efcab9e1a87b8",
         x86_64_linux: "59fb0f88eab2fe2e3a053ac020e18fcb2b5c113d255e41c82d26302b675d580c"

  url "https://update.code.visualstudio.com/#{version}/#{os}-#{arch}/stable"
  name "Microsoft Visual Studio Code"
  name "VS Code"
  desc "Open-source code editor"
  homepage "https://code.visualstudio.com/"

  livecheck do
    url "https://update.code.visualstudio.com/api/update/#{os}-#{arch}/stable/latest"
    strategy :json do |json|
      json["productVersion"]
    end
  end

  vscode_dir = "VSCode-linux-#{arch}"

  binary "#{vscode_dir}/bin/code"
  binary "#{vscode_dir}/bin/code-tunnel"
  bash_completion "#{staged_path}/#{vscode_dir}/resources/completions/bash/code"
  zsh_completion  "#{staged_path}/#{vscode_dir}/resources/completions/zsh/_code"
  artifact "#{vscode_dir}/code.desktop",
           target: "#{Dir.home}/.local/share/applications/code.desktop"
  artifact "#{vscode_dir}/code-url-handler.desktop",
           target: "#{Dir.home}/.local/share/applications/code-url-handler.desktop"
  artifact "#{vscode_dir}/resources/app/resources/linux/code.png",
           target: "#{Dir.home}/.local/share/icons/vscode.png"

  preflight_steps do
    mkdir_p ".local/share/applications", base: :home
    write_file "#{vscode_dir}/code.desktop", <<~EOS
      [Desktop Entry]
      Name=Visual Studio Code
      Comment=Code Editing. Redefined.
      GenericName=Text Editor
      Exec={{HOMEBREW_PREFIX}}/bin/code %F
      Icon=#{Dir.home}/.local/share/icons/vscode.png
      Type=Application
      StartupNotify=false
      StartupWMClass=Code
      Categories=TextEditor;Development;IDE;
      MimeType=application/x-code-workspace;
      Actions=new-empty-window;
      Keywords=vscode;

      [Desktop Action new-empty-window]
      Name=New Empty Window
      Name[cs]=Nové prázdné okno
      Name[de]=Neues leeres Fenster
      Name[es]=Nueva ventana vacía
      Name[fr]=Nouvelle fenêtre vide
      Name[it]=Nuova finestra vuota
      Name[ja]=新しい空のウィンドウ
      Name[ko]=새 빈 창
      Name[ru]=Новое пустое окно
      Name[zh_CN]=新建空窗口
      Name[zh_TW]=開新空視窗
      Exec={{HOMEBREW_PREFIX}}/bin/code --new-window %F
      Icon=#{Dir.home}/.local/share/icons/vscode.png
    EOS
    write_file "#{vscode_dir}/code-url-handler.desktop", <<~EOS
      [Desktop Entry]
      Name=Visual Studio Code - URL Handler
      Comment=Code Editing. Redefined.
      GenericName=Text Editor
      Exec={{HOMEBREW_PREFIX}}/bin/code --open-url %U
      Icon=#{Dir.home}/.local/share/icons/vscode.png
      Type=Application
      NoDisplay=true
      StartupNotify=true
      Categories=Utility;TextEditor;Development;IDE;
      MimeType=x-scheme-handler/vscode;
      Keywords=vscode;
    EOS
  end

  postflight_steps do
    # Seed default settings only on first install so user edits survive upgrades.
    unless_path_exists ".config/Code/User/settings.json", base: :home do
      write_file ".config/Code/User/settings.json", <<~JSON, base: :home
        {
          "window.titleBarStyle": "native"
        }
      JSON
    end
  end

  zap trash: [
    "~/.config/Code",
    "~/.vscode",
  ]
end
