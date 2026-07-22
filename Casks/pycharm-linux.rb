cask "pycharm-linux" do
  arch intel: "",
       arm:   "-aarch64"
  os linux: "linux"

  version "2026.2,262.8665.309"
  sha256 arm64_linux:  "3b63d2f490c14c541c98afd851f218069a3c885ceaedd9bdb00e5a07285cf802",
         x86_64_linux: "ac36f7c0743465215bf8227079b77272945338c485c1da6b924e56468046bd5a"

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

  binary "pycharm-#{version.csv.first}/bin/pycharm"
  artifact "jetbrains-pycharm.desktop",
           target: "#{Dir.home}/.local/share/applications/jetbrains-pycharm.desktop"
  artifact "pycharm-#{version.csv.first}/bin/pycharm.svg",
           target: "#{Dir.home}/.local/share/icons/hicolor/scalable/apps/pycharm.svg"

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

  postflight do
    system "/usr/bin/xdg-icon-resource", "forceupdate"
  end

  zap trash: [
    "#{Dir.home}/.cache/JetBrains/PyCharm#{version.major_minor}",
    "#{Dir.home}/.config/JetBrains/PyCharm#{version.major_minor}",
    "#{Dir.home}/.local/share/JetBrains/PyCharm#{version.major_minor}",
  ]
end
