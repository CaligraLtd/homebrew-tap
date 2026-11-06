cask "pycharm-linux" do
  arch arm: "-aarch64"
  os linux: "linux"

  version "2026.3,263.7307.206"
  sha256 arm64_linux:  "113b773179905bd5413a437cda1e489cfb2794edfe9245381fd2df65fa76a213",
         x86_64_linux: "70d448ee1aa2a60234a6135b7ef9af6403fb691c26446113d587ccee06f6b813"

  url "https://download.jetbrains.com/python/pycharm-#{version.csv.first}#{arch}.tar.gz"
  name "PyCharm"
  desc "IDE for professional Python development"
  homepage "https://www.jetbrains.com/pycharm/"

  livecheck do
    url "https://data.services.jetbrains.com/products/releases?code=PCP&latest=true&type=release"
    strategy :json do |json|
      json["PCP"]&.map do |release|
        version = release["version"]
        build = release["build"]
        next if version.blank? || build.blank?

        "#{version},#{build}"
      end
    end
  end

  auto_updates false
  conflicts_with cask: "jetbrains-toolbox-linux"

  pycharm_dir = "pycharm-#{version.csv.first}"

  binary "#{pycharm_dir}/bin/pycharm"
  artifact "jetbrains-pycharm.desktop",
           target: "#{Dir.home}/.local/share/applications/jetbrains-pycharm.desktop"
  artifact "#{pycharm_dir}/bin/pycharm.svg",
           target: "#{Dir.home}/.local/share/icons/hicolor/scalable/apps/pycharm.svg"

  # Workbench 0.10.32 and older share a root-owned `/home/linuxbrew` prefix.
  # Homebrew chmods `$HOMEBREW_PREFIX/bin` after every `*_steps` block, which
  # fails there, so those machines keep the Ruby blocks.
  shared_prefix = !File.owned?("#{HOMEBREW_PREFIX}/bin")

  if shared_prefix
    preflight do
      # Prevent PyCharm's built-in updater from conflicting with Homebrew
      # TODO: enable server-side window decorations once JBR supports it properly
      #   https://youtrack.jetbrains.com/issue/JBR-6187
      File.write("#{staged_path}/pycharm-#{version.csv.first}/bin/pycharm64.vmoptions",
                 "-Dide.no.platform.update=true\n", mode: "a+")
      FileUtils.mkdir_p("#{Dir.home}/.local/share/applications")
      FileUtils.mkdir_p("#{Dir.home}/.local/share/icons/hicolor/scalable/apps")
      File.write("#{staged_path}/jetbrains-pycharm.desktop", <<~EOS)
        [Desktop Entry]
        Version=1.0
        Name=PyCharm
        Comment=The Only Python IDE you need
        Exec=#{HOMEBREW_PREFIX}/bin/pycharm %F
        Icon=pycharm
        Type=Application
        Categories=Development;IDE;
        Keywords=jetbrains;ide;python;
        Terminal=false
        StartupWMClass=jetbrains-pycharm
        StartupNotify=true
      EOS
    end
  else
    preflight_steps do
      # Prevent PyCharm's built-in updater from conflicting with Homebrew
      # TODO: enable server-side window decorations once JBR supports it properly
      #   https://youtrack.jetbrains.com/issue/JBR-6187
      inreplace "#{pycharm_dir}/bin/pycharm64.vmoptions", /\n?\z/, "\n-Dide.no.platform.update=true\n", global: false
      mkdir_p ".local/share/applications", base: :home
      mkdir_p ".local/share/icons/hicolor/scalable/apps", base: :home
      write_file "jetbrains-pycharm.desktop", <<~EOS
        [Desktop Entry]
        Version=1.0
        Name=PyCharm
        Comment=The Only Python IDE you need
        Exec={{HOMEBREW_PREFIX}}/bin/pycharm %F
        Icon=pycharm
        Type=Application
        Categories=Development;IDE;
        Keywords=jetbrains;ide;python;
        Terminal=false
        StartupWMClass=jetbrains-pycharm
        StartupNotify=true
      EOS
    end
  end

  if shared_prefix
    postflight do
      system "/usr/bin/xdg-icon-resource", "forceupdate"
    end
  else
    postflight_steps do
      run "/usr/bin/xdg-icon-resource", args: ["forceupdate"], must_succeed: false
    end
  end

  zap trash: [
    "#{Dir.home}/.cache/JetBrains/PyCharm#{version.major_minor}",
    "#{Dir.home}/.config/JetBrains/PyCharm#{version.major_minor}",
    "#{Dir.home}/.local/share/JetBrains/PyCharm#{version.major_minor}",
  ]
end
