cask "asdbctl" do
  os linux: "linux"

  version "1.1.0"
  sha256 "cda42a62010fbcadff8be1d0ed25272c5339f096808e2efe9e45939f06c18af6"

  url "https://github.com/juliuszint/asdbctl/archive/refs/tags/v#{version}.tar.gz"
  name "asdbctl"
  desc "Control Apple Studio Display brightness"
  homepage "https://github.com/juliuszint/asdbctl"

  livecheck do
    url "https://github.com/juliuszint/asdbctl"
    strategy :github_latest
  end

  depends_on formula: "pkg-config"
  depends_on formula: "rust"

  binary "install/bin/asdbctl"
  artifact "asdbctl-#{version}/rules.d/20-asd-backlight.rules",
           target: "#{HOMEBREW_PREFIX}/share/asdbctl/20-asd-backlight.rules"

  # Workbench 0.10.32 and older share a root-owned `/home/linuxbrew` prefix.
  # Homebrew chmods `$HOMEBREW_PREFIX/bin` after every `*_steps` block, which
  # fails there, so those machines keep the Ruby blocks.
  shared_prefix = !File.owned?("#{HOMEBREW_PREFIX}/bin")

  if shared_prefix
    preflight do
      src_dir = "#{staged_path}/asdbctl-#{version}"
      Dir.chdir(src_dir) do
        ok = system({ "PATH"            => "#{HOMEBREW_PREFIX}/bin:#{ENV.fetch("PATH", nil)}",
                      "PKG_CONFIG_PATH" => "/usr/lib64/pkgconfig" },
                    "cargo", "install", "--path", ".",
                    "--root", "#{staged_path}/install", "--locked")
        raise "cargo install failed" unless ok
      end
      FileUtils.rm_r("#{src_dir}/target")
    end
  else
    preflight_steps do
      run "{{HOMEBREW_PREFIX}}/bin/cargo",
          args:           ["install", "--path", ".", "--root", "{{staged_path}}/install", "--locked"],
          chdir:          "asdbctl-{{version}}",
          env:            {
            "PATH"            => "{{HOMEBREW_PREFIX}}/bin:/usr/bin:/bin",
            "PKG_CONFIG_PATH" => "/usr/lib64/pkgconfig",
            "CARGO_HOME"      => "#{Dir.home}/.cargo",
          },
          writable_paths: [".cargo"], writable_base: :home,
          network_access: true
      remove "asdbctl-{{version}}/target", recursive: true
    end
  end

  if shared_prefix
    postflight do
      rule_src = "#{HOMEBREW_PREFIX}/share/asdbctl/20-asd-backlight.rules"
      rule_dst = "/etc/udev/rules.d/20-asd-backlight.rules"
      next if File.exist?(rule_dst) && FileUtils.identical?(rule_src, rule_dst)

      manual = <<~EOS.chomp
        Install the udev rule manually for non-root brightness control:
          sudo install -Dm0644 #{rule_src} #{rule_dst}
          sudo udevadm control --reload-rules && sudo udevadm trigger
      EOS

      unless $stdin.tty?
        opoo "Non-interactive install; skipping udev rule.\n#{manual}"
        next
      end

      ohai "Installing udev rule to #{rule_dst} (sudo)"
      ok = system("sudo", "install", "-Dm0644", rule_src, rule_dst) &&
           system("sudo", "udevadm", "control", "--reload-rules") &&
           system("sudo", "udevadm", "trigger")
      opoo "Could not install udev rule.\n#{manual}" unless ok
    end
  else
    postflight_steps do
      run "install", args: ["-Dm0644", "{{HOMEBREW_PREFIX}}/share/asdbctl/20-asd-backlight.rules",
                            "/etc/udev/rules.d/20-asd-backlight.rules"], sudo: true, must_succeed: false
      run "udevadm", args: ["control", "--reload-rules"], sudo: true, must_succeed: false
      run "udevadm", args: ["trigger"], sudo: true, must_succeed: false
    end
  end

  caveats <<~EOS
    Non-root brightness control needs a udev rule. If the install could not
    run sudo, install it by hand:
      sudo install -Dm0644 #{HOMEBREW_PREFIX}/share/asdbctl/20-asd-backlight.rules /etc/udev/rules.d/20-asd-backlight.rules
      sudo udevadm control --reload-rules && sudo udevadm trigger
  EOS

  if shared_prefix
    uninstall_preflight do
      rule_dst = "/etc/udev/rules.d/20-asd-backlight.rules"
      next unless File.exist?(rule_dst)

      ohai "Removing udev rule (sudo)"
      system "sudo", "rm", "-f", rule_dst
      system "sudo", "udevadm", "control", "--reload-rules"
      system "sudo", "udevadm", "trigger"
    end
  else
    uninstall_preflight_steps do
      if_path_exists "/etc/udev/rules.d/20-asd-backlight.rules" do
        run "rm", args: ["-f", "/etc/udev/rules.d/20-asd-backlight.rules"], sudo: true, must_succeed: false
        run "udevadm", args: ["control", "--reload-rules"], sudo: true, must_succeed: false
        run "udevadm", args: ["trigger"], sudo: true, must_succeed: false
      end
    end
  end
end
