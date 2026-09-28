cask "microsoft-core-fonts-linux" do
  os linux: "linux"

  version "2.6"
  sha256 "55d7f3a86533225634ff3ea2384b4356d9665a29cc7eeacff16602a1714afbb4"

  url "https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-#{version}-1.noarch.rpm"
  name "Microsoft Core Fonts"
  desc "Microsoft TrueType core fonts for the Web"
  homepage "https://mscorefonts2.sourceforge.net/"

  depends_on formula: "cabextract"

  stage_only true

  # Workbench 0.10.32 and older share a root-owned `/home/linuxbrew` prefix.
  # Homebrew chmods `$HOMEBREW_PREFIX/bin` after every `*_steps` block, which
  # fails there, so those machines keep the Ruby blocks.
  shared_prefix = !File.owned?("#{HOMEBREW_PREFIX}/bin")

  if shared_prefix
    preflight do
      system "sh", "-c", "cd #{staged_path} && rpm2cpio msttcore-fonts-installer-#{version}-1.noarch.rpm | cpio -idmv 2>/dev/null"
    end
  else
    preflight_steps do
      run "/bin/sh",
          args:  ["-c", "rpm2cpio msttcore-fonts-installer-{{version}}-1.noarch.rpm | cpio -idm --quiet"],
          chdir: "."
    end
  end

  if shared_prefix
    postflight do
      font_dir = "#{Dir.home}/.local/share/fonts/msttcore"
      FileUtils.mkdir_p(font_dir)

      # Brew installs cask deps before formula deps, so `cabextract` is not yet on
      # PATH when this postflight runs as a transitive dep of another cask. Install
      # it now if missing; a redundant call is a fast no-op.
      cabextract = "#{HOMEBREW_PREFIX}/bin/cabextract"
      system "#{HOMEBREW_PREFIX}/bin/brew", "install", "cabextract" unless File.executable?(cabextract)

      script = "#{staged_path}/usr/lib/msttcore-fonts-installer/refresh-msttcore-fonts.sh"
      raise "refresh-msttcore-fonts.sh not found in RPM" unless File.exist?(script)

      FileUtils.chmod(0755, script)
      system "sh", "-c", "PATH=#{HOMEBREW_PREFIX}/bin:$PATH #{script} -F #{font_dir}"
      system "fc-cache", "-f"

      %w[arial.ttf times.ttf verdana.ttf].each do |font|
        unless File.exist?("#{font_dir}/#{font}")
          raise "Font installation failed: #{font} not found in #{font_dir}. " \
                "SourceForge may be unreachable. Try again with: brew reinstall microsoft-core-fonts-linux"
        end
      end
    end
  else
    postflight_steps do
      # As a dependency of another cask this installs before its formulae, so
      # `cabextract` may be missing, and Homebrew refuses a nested `brew install`
      # inside a step. Stand in for the `cabextract` calls
      # refresh-msttcore-fonts.sh makes with 7z, which the base image ships.
      mkdir_p "bin"
      write_file "bin/cabextract", <<~SH
        #!/bin/sh
        list=
        pattern='*'
        dir=.
        while [ $# -gt 1 ]; do
          case $1 in
            -l) list=1 ;;
            -F) shift; pattern=$1 ;;
            --directory=*) dir=${1#--directory=} ;;
          esac
          shift
        done
        if [ -n "$list" ]; then
          7z l -ba -ssc- "$1" "$pattern" | awk '{ print "  " $4 " | " $1 " " $2 " | " tolower($NF) }'
          exit
        fi
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        7z e -y -ssc- -o"$tmp" "$1" "$pattern" >/dev/null || exit
        for f in "$tmp"/*; do
          [ -e "$f" ] || continue
          mv -f "$f" "$dir/$(basename "$f" | tr '[:upper:]' '[:lower:]')"
        done
      SH
      set_permissions "bin/cabextract", "0755"

      write_file "caligra-msttcore-install.sh", <<~SH
        #!/bin/sh
        set -e
        font_dir="#{Dir.home}/.local/share/fonts/msttcore"
        script="{{staged_path}}/usr/lib/msttcore-fonts-installer/refresh-msttcore-fonts.sh"
        mkdir -p "$font_dir"
        chmod 0755 "$script"
        PATH="{{staged_path}}/bin:$PATH" "$script" -F "$font_dir" || true
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
  end

  if shared_prefix
    uninstall_preflight do
      font_dir = "#{Dir.home}/.local/share/fonts/msttcore"
      FileUtils.rm_r(font_dir) if Dir.exist?(font_dir)
      system "fc-cache", "-f"
    end
  else
    uninstall_preflight_steps do
      remove ".local/share/fonts/msttcore", base: :home, recursive: true
      run "fc-cache", args:           ["-f"],
                      env:            { "XDG_CACHE_HOME" => "#{Dir.home}/.cache" },
                      writable_paths: [".cache/fontconfig"], writable_base: :home,
                      must_succeed:   false
    end
  end

  zap trash: "~/.local/share/fonts/msttcore"
end
