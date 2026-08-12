cask "zoom-linux" do
  os linux: "linux"

  version "7.1.5.4332"
  sha256 "92f82ac8f83c675bddfe5ea4a563c773b1d6bc95519c27f432c5557fec630b28"

  url "https://cdn.zoom.us/prod/#{version}/zoom_x86_64.rpm",
      verified: "cdn.zoom.us/prod/"
  name "Zoom Workplace"
  desc "Video communication and virtual meeting platform"
  homepage "https://zoom.us/"

  livecheck do
    url "https://zoom.us/rest/download?os=linux"
    strategy :json do |json|
      json.dig("result", "downloadVO", "zoom", "version")
    end
  end

  depends_on arch: :x86_64
  # Workbench doesn't ship xcb-util-keysyms; see the preflight below.
  depends_on formula: "xcb-util-keysyms"

  binary "#{staged_path}/opt/zoom/ZoomLauncher", target: "zoom"
  artifact "Zoom.desktop",
           target: "#{Dir.home}/.local/share/applications/Zoom.desktop"
  artifact "usr/share/pixmaps/Zoom.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/256x256/apps/Zoom.png"

  preflight do
    system_command "/bin/sh",
                   args:         ["-c", "rpm2cpio zoom_x86_64.rpm | cpio -idm --quiet"],
                   chdir:        staged_path,
                   must_succeed: true

    # `zoom` needs `libxcb-keysyms.so.1`, which it doesn't bundle. Setting
    # LD_LIBRARY_PATH doesn't help: ZoomLauncher overwrites it before exec'ing
    # `zoom`, with its own install dir plus `Qt/lib`.
    keysyms = [
      "#{HOMEBREW_PREFIX}/opt/xcb-util-keysyms/lib/libxcb-keysyms.so.1",
      "#{HOMEBREW_PREFIX}/lib/libxcb-keysyms.so.1",
    ].find { |path| File.exist?(path) }
    raise "libxcb-keysyms.so.1 not found under #{HOMEBREW_PREFIX}" if keysyms.nil?

    FileUtils.ln_sf keysyms, "#{staged_path}/opt/zoom/Qt/lib/libxcb-keysyms.so.1"

    FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
    FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/256x256/apps"

    desktop_file = "#{staged_path}/usr/share/applications/Zoom.desktop"
    raise "Zoom desktop file not found in package" unless File.exist?(desktop_file)

    text = File.read(desktop_file)
    text.sub!(/^Exec=.*$/, "Exec=#{HOMEBREW_PREFIX}/bin/zoom %U")
    text.sub!(/^Icon=.*$/, "Icon=#{Dir.home}/.local/share/icons/hicolor/256x256/apps/Zoom.png")
    File.write("#{staged_path}/Zoom.desktop", text)
  end

  postflight do
    # Use Workbench's window decorations
    conf = "#{Dir.home}/.config/zoomus.conf"
    text = File.exist?(conf) ? File.read(conf) : "[General]\n"

    text = if text.match?(/^showSystemTitlebar=/)
      text.sub(/^showSystemTitlebar=.*$/, "showSystemTitlebar=true")
    elsif text.match?(/^\[General\]$/)
      text.sub(/^\[General\]$/, "[General]\nshowSystemTitlebar=true")
    else
      "#{text.chomp}\n\n[General]\nshowSystemTitlebar=true\n"
    end

    FileUtils.mkdir_p File.dirname(conf)
    File.write(conf, text)

    # Meetings open through a zoommtg:// link in the browser.
    apps_dir = "#{Dir.home}/.local/share/applications"
    system_command "/bin/sh",
                   args:         ["-c",
                                  "command -v update-desktop-database >/dev/null && " \
                                  "update-desktop-database #{apps_dir.shellescape}"],
                   must_succeed: false
  end

  zap trash: [
    "~/.cache/zoom",
    "~/.config/zoomus.conf",
    "~/.zoom",
  ]
end
