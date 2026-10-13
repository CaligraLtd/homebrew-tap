cask "artcraft-launcher-linux" do
  arch arm: "aarch64", intel: "x86_64"
  os linux: "linux"

  version "0.3.2"
  sha256 arm64_linux:  "9a401952dfa65f66234ba22aae94f66d037f77eae72a17ec122fbbeaa16f631f",
         x86_64_linux: "7edc70da35bf214a2215287948b8fda620b3dfe55076aec56e8d76be1a68a8b5"

  # The AppImage, not the tarball: run as an AppImage, the launcher installs
  # suite apps as AppImages in ~/Applications. Run any other way, it picks the
  # .rpm and calls `pkexec dnf install`, which fails on Workbench.
  url "https://github.com/storytold/craft-launcher/releases/download/v#{version}/artcraft-launcher-#{version}-linux-#{arch}.AppImage"
  name "ArtCraft Launcher"
  desc "Installs, updates and launches the Craft App Suite"
  homepage "https://getartcraft.com/apps"

  livecheck do
    url :url
    strategy :github_latest
  end

  appimage = "artcraft-launcher-#{version}-linux-#{arch}.AppImage"
  desktop = "ai.storyteller.artcraft-launcher.desktop"
  png = "usr/share/icons/hicolor/512x512/apps/ai.storyteller.artcraft-launcher.png"
  icon = "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/ai.storyteller.artcraft-launcher.png"
  extract = "chmod +x #{appimage} && " \
            "./#{appimage} --appimage-extract usr/share/applications/#{desktop} >/dev/null && " \
            "./#{appimage} --appimage-extract #{png} >/dev/null"

  binary appimage, target: "artcraft-launcher"
  artifact desktop,
           target: "#{Dir.home}/.local/share/applications/#{desktop}"
  artifact "squashfs-root/#{png}",
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

      text = File.read("#{staged_path}/squashfs-root/usr/share/applications/#{desktop}")
      text.sub!(/^Exec=.*$/, "Exec=#{HOMEBREW_PREFIX}/bin/artcraft-launcher")
      text.sub!(/^TryExec=.*$/, "TryExec=#{HOMEBREW_PREFIX}/bin/artcraft-launcher")
      text.sub!(/^Icon=.*$/, "Icon=#{icon}")
      File.write("#{staged_path}/#{desktop}", text)
    end
  else
    preflight_steps do
      run "/bin/sh", args: ["-c", extract], chdir: "."

      mkdir_p ".local/share/applications", base: :home
      mkdir_p ".local/share/icons/hicolor/512x512/apps", base: :home

      copy "squashfs-root/usr/share/applications/#{desktop}", desktop
      run "sed", args: ["-i",
                        "-e", "s|^Exec=.*|Exec={{HOMEBREW_PREFIX}}/bin/artcraft-launcher|",
                        "-e", "s|^TryExec=.*|TryExec={{HOMEBREW_PREFIX}}/bin/artcraft-launcher|",
                        "-e", "s|^Icon=.*|Icon=#{icon}|",
                        desktop], chdir: "."
    end
  end

  zap trash: [
    "~/.cache/artcraft-launcher",
    "~/.config/autostart/ai.storyteller.artcraft-launcher.desktop",
    "~/.local/share/ai.storyteller.artcraft-launcher",
    "~/.local/share/artcraft-launcher",
  ]
end
