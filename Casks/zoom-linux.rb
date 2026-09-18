cask "zoom-linux" do
  os linux: "linux"

  version "7.1.5.4332"
  sha256 "92f82ac8f83c675bddfe5ea4a563c773b1d6bc95519c27f432c5557fec630b28"

  url "https://cdn.zoom.us/prod/#{version}/zoom_x86_64.rpm"
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

  preflight_steps do
    run "/bin/sh", args: ["-c", "rpm2cpio zoom_x86_64.rpm | cpio -idm --quiet"], chdir: "."

    # `zoom` needs `libxcb-keysyms.so.1`, which it doesn't bundle. Setting
    # LD_LIBRARY_PATH doesn't help: ZoomLauncher overwrites it before exec'ing
    # `zoom`, with its own install dir plus `Qt/lib`.
    symlink "{{HOMEBREW_PREFIX}}/opt/xcb-util-keysyms/lib/libxcb-keysyms.so.1",
            "opt/zoom/Qt/lib/libxcb-keysyms.so.1", overwrite: true

    mkdir_p ".local/share/applications", base: :home
    mkdir_p ".local/share/icons/hicolor/256x256/apps", base: :home

    copy "usr/share/applications/Zoom.desktop", "Zoom.desktop"
    run "sed", args: ["-i",
                      "-e", "0,/^Exec=/s|^Exec=.*|Exec={{HOMEBREW_PREFIX}}/bin/zoom %U|",
                      "-e", "0,/^Icon=/s|^Icon=.*|Icon=#{Dir.home}/.local/share/icons/hicolor/256x256/apps/Zoom.png|",
                      "Zoom.desktop"], chdir: "."
  end

  postflight_steps do
    # Use Workbench's window decorations
    write_file "caligra-zoom-titlebar.sh", <<~SH
      #!/bin/sh
      set -e
      conf="#{Dir.home}/.config/zoomus.conf"
      mkdir -p "$(dirname "$conf")"
      if [ ! -f "$conf" ]; then
        printf '[General]\\nshowSystemTitlebar=true\\n' > "$conf"
      elif grep -q '^showSystemTitlebar=' "$conf"; then
        sed -i 's/^showSystemTitlebar=.*/showSystemTitlebar=true/' "$conf"
      elif grep -q '^\\[General\\]$' "$conf"; then
        sed -i 's/^\\[General\\]$/[General]\\nshowSystemTitlebar=true/' "$conf"
      else
        printf '\\n[General]\\nshowSystemTitlebar=true\\n' >> "$conf"
      fi
    SH
    run "/bin/sh", args: ["{{staged_path}}/caligra-zoom-titlebar.sh"],
                   writable_paths: [".config"], writable_base: :home

    # Meetings open through a zoommtg:// link in the browser.
    run "/bin/sh",
        args:           ["-c", "command -v update-desktop-database >/dev/null && " \
                               "update-desktop-database #{Dir.home}/.local/share/applications"],
        writable_paths: [".local/share/applications"], writable_base: :home,
        must_succeed:   false
  end

  zap trash: [
    "~/.cache/zoom",
    "~/.config/zoomus.conf",
    "~/.zoom",
  ]
end
