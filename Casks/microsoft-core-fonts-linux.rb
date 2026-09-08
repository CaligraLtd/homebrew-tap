cask "microsoft-core-fonts-linux" do
  version "2.6"
  sha256 "55d7f3a86533225634ff3ea2384b4356d9665a29cc7eeacff16602a1714afbb4"
  os linux: "linux"

  url "https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-#{version}-1.noarch.rpm"
  name "Microsoft Core Fonts"
  desc "Microsoft TrueType core fonts for the Web"
  homepage "https://mscorefonts2.sourceforge.net/"

  depends_on formula: "cabextract"

  stage_only true

  preflight_steps do
    run "/bin/sh",
        args:  ["-c", "rpm2cpio msttcore-fonts-installer-{{version}}-1.noarch.rpm | cpio -idm --quiet"],
        chdir: "."
  end

  postflight_steps do
    # Brew installs cask deps before formula deps, so `cabextract` is not yet on
    # PATH when this postflight runs as a transitive dep of another cask. Install
    # it now if missing.
    unless_path_exists "{{HOMEBREW_PREFIX}}/bin/cabextract" do
      run "{{HOMEBREW_BREW_FILE}}", args:           ["install", "cabextract"],
                                    env:            { "HOMEBREW_NO_AUTO_UPDATE" => "1" },
                                    writable_paths: ["{{HOMEBREW_CELLAR}}", "{{HOMEBREW_PREFIX}}/opt"],
                                    network_access: true
    end

    write_file "caligra-msttcore-install.sh", <<~SH
      #!/bin/sh
      set -e
      font_dir="#{Dir.home}/.local/share/fonts/msttcore"
      script="{{staged_path}}/usr/lib/msttcore-fonts-installer/refresh-msttcore-fonts.sh"
      mkdir -p "$font_dir"
      chmod 0755 "$script"
      PATH="{{HOMEBREW_PREFIX}}/bin:$PATH" "$script" -F "$font_dir" || true
      XDG_CACHE_HOME="#{Dir.home}/.cache" fc-cache -f || true
      for font in arial.ttf times.ttf verdana.ttf; do
        if [ ! -f "$font_dir/$font" ]; then
          echo "Font installation failed: $font not found in $font_dir. SourceForge may be unreachable. Try again with: brew reinstall microsoft-core-fonts-linux" >&2
          exit 1
        fi
      done
    SH
    run "/bin/sh", args:           ["{{staged_path}}/caligra-msttcore-install.sh"],
                   print_stdout:   true,
                   network_access: true,
                   writable_paths: [".local/share/fonts", ".cache/fontconfig"], writable_base: :home
  end

  uninstall_preflight_steps do
    remove ".local/share/fonts/msttcore", base: :home, recursive: true
    run "fc-cache", args:           ["-f"],
                    env:            { "XDG_CACHE_HOME" => "#{Dir.home}/.cache" },
                    writable_paths: [".cache/fontconfig"], writable_base: :home,
                    must_succeed:   false
  end

  zap trash: [
    "~/.local/share/fonts/msttcore",
  ]
end
