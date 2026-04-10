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

  preflight do
    system "sh", "-c", "cd #{staged_path} && rpm2cpio msttcore-fonts-installer-#{version}-1.noarch.rpm | cpio -idmv 2>/dev/null"
  end

  postflight do
    font_dir = "#{Dir.home}/.local/share/fonts/msttcore"
    FileUtils.mkdir_p(font_dir)

    script = "#{staged_path}/usr/lib/msttcore-fonts-installer/refresh-msttcore-fonts.sh"
    raise "refresh-msttcore-fonts.sh not found in RPM" unless File.exist?(script)

    FileUtils.chmod(0o755, script)
    system "sh", "-c", "PATH=#{HOMEBREW_PREFIX}/bin:$PATH #{script} -F #{font_dir}"
    system "fc-cache", "-f"

    %w[arial.ttf times.ttf verdana.ttf].each do |font|
      unless File.exist?("#{font_dir}/#{font}")
        raise "Font installation failed: #{font} not found in #{font_dir}. " \
              "SourceForge may be unreachable. Try again with: brew reinstall microsoft-core-fonts-linux"
      end
    end
  end

  uninstall_preflight do
    font_dir = "#{Dir.home}/.local/share/fonts/msttcore"
    FileUtils.rm_rf(font_dir) if Dir.exist?(font_dir)
    system "fc-cache", "-f"
  end

  zap trash: [
    "~/.local/share/fonts/msttcore",
  ]
end
