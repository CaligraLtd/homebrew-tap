# Originally from https://github.com/ublue-os/homebrew-experimental-tap/blob/main/Casks/cursor-linux.rb
cask "cursor-linux" do
  arch arm: "arm64", intel: "x64"
  file_arch = on_arch_conditional arm: "aarch64", intel: "x86_64"

  version "3.24.7,db556148f14ddd5adf2ce3850cb53ff2a54b4e1b"
  sha256 arm64_linux:  "0087513ef033f60508293865d511a36e5cd2277bece15ecc8163fcc588a9baa0",
         x86_64_linux: "8ec6f20592f84787a5b708d1f8c99d6447c15f2aa4c1241456e8b563b4cc4047"

  url "https://downloads.cursor.com/production/#{version.csv.second}/linux/#{arch}/Cursor-#{version.csv.first}-#{file_arch}.AppImage"
  name "Cursor"
  desc "Write, edit, and chat about your code with AI"
  homepage "https://www.cursor.com/"

  livecheck do
    url "https://api2.cursor.sh/updates/api/update/linux-x64/cursor/0.0.0/stable"
    regex(%r{/production/(\h+)/linux/x64/Cursor[._-]([0-9.]+)[._-]x86_64\.AppImage}i)
    strategy :json do |json, regex|
      match = json["url"]&.match(regex)
      next if match.blank?

      "#{json["version"]},#{match[1]}"
    end
  end

  appimage = "Cursor-#{version.csv.first}-#{file_arch}.AppImage"

  binary appimage, target: "cursor"
  bash_completion "#{staged_path}/squashfs-root/usr/share/cursor/resources/completions/bash/cursor"
  zsh_completion  "#{staged_path}/squashfs-root/usr/share/cursor/resources/completions/zsh/_cursor"
  artifact "cursor.desktop",
           target: "#{Dir.home}/.local/share/applications/cursor.desktop"
  artifact "cursor.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/cursor.png"

  # Workbench 0.10.32 and older share a root-owned `/home/linuxbrew` prefix.
  # Homebrew chmods `$HOMEBREW_PREFIX/bin` after every `*_steps` block, which
  # fails there, so those machines keep the Ruby blocks.
  shared_prefix = !File.owned?("#{HOMEBREW_PREFIX}/bin")

  if shared_prefix
    preflight do
      FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
      FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/512x512/apps"

      # Make AppImage executable
      appimage_name = "Cursor-#{version.csv.first}-#{file_arch}.AppImage"
      FileUtils.chmod "+x", "#{staged_path}/#{appimage_name}"

      # Extract AppImage contents to get resources (icon, completions, etc.)
      system "#{staged_path}/#{appimage_name}", "--appimage-extract", chdir: staged_path

      # Copy icon from extracted AppImage
      icon_source = "#{staged_path}/squashfs-root/usr/share/icons/hicolor/512x512/apps/cursor.png"
      FileUtils.cp icon_source, "#{staged_path}/cursor.png" if File.exist?(icon_source)

      File.write("#{staged_path}/cursor.desktop", <<~EOS)
        [Desktop Entry]
        Name=Cursor
        Comment=AI-first coding environment
        GenericName=Text Editor
        Exec=#{HOMEBREW_PREFIX}/bin/cursor %F
        Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/cursor.png
        Type=Application
        StartupNotify=false
        StartupWMClass=Cursor
        Categories=TextEditor;Development;IDE;
        MimeType=text/plain;inode/directory;application/x-code-workspace;
        Actions=new-empty-window;
        Keywords=cursor;code;editor;

        [Desktop Action new-empty-window]
        Name=New Empty Window
        Exec=#{HOMEBREW_PREFIX}/bin/cursor --new-window %F
        Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/cursor.png
      EOS

      # Create a placeholder icon if extraction fails
      FileUtils.touch "#{staged_path}/cursor.png" unless File.exist?("#{staged_path}/cursor.png")
    end
  else
    preflight_steps do
      mkdir_p ".local/share/applications", base: :home
      mkdir_p ".local/share/icons/hicolor/512x512/apps", base: :home

      set_permissions appimage, "0755"
      run "{{staged_path}}/#{appimage}", args: ["--appimage-extract"], chdir: "."

      if_path_exists "squashfs-root/usr/share/icons/hicolor/512x512/apps/cursor.png" do
        copy "squashfs-root/usr/share/icons/hicolor/512x512/apps/cursor.png", "cursor.png"
      end

      write_file "cursor.desktop", <<~EOS
        [Desktop Entry]
        Name=Cursor
        Comment=AI-first coding environment
        GenericName=Text Editor
        Exec={{HOMEBREW_PREFIX}}/bin/cursor %F
        Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/cursor.png
        Type=Application
        StartupNotify=false
        StartupWMClass=Cursor
        Categories=TextEditor;Development;IDE;
        MimeType=text/plain;inode/directory;application/x-code-workspace;
        Actions=new-empty-window;
        Keywords=cursor;code;editor;

        [Desktop Action new-empty-window]
        Name=New Empty Window
        Exec={{HOMEBREW_PREFIX}}/bin/cursor --new-window %F
        Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/cursor.png
      EOS

      # Create a placeholder icon if extraction fails
      unless_path_exists "cursor.png" do
        touch "cursor.png"
      end
    end
  end

  zap trash: [
    "~/.config/Cursor",
    "~/.cursor",
  ]
end
