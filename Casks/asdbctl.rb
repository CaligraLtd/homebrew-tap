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

  postflight_steps do
    run "install", args: ["-Dm0644", "{{HOMEBREW_PREFIX}}/share/asdbctl/20-asd-backlight.rules",
                          "/etc/udev/rules.d/20-asd-backlight.rules"], sudo: true, must_succeed: false
    run "udevadm", args: ["control", "--reload-rules"], sudo: true, must_succeed: false
    run "udevadm", args: ["trigger"], sudo: true, must_succeed: false
  end

  caveats <<~EOS
    Non-root brightness control needs a udev rule. If the install could not
    run sudo, install it by hand:
      sudo install -Dm0644 #{HOMEBREW_PREFIX}/share/asdbctl/20-asd-backlight.rules /etc/udev/rules.d/20-asd-backlight.rules
      sudo udevadm control --reload-rules && sudo udevadm trigger
  EOS

  uninstall_preflight_steps do
    if_path_exists "/etc/udev/rules.d/20-asd-backlight.rules" do
      run "rm", args: ["-f", "/etc/udev/rules.d/20-asd-backlight.rules"], sudo: true, must_succeed: false
      run "udevadm", args: ["control", "--reload-rules"], sudo: true, must_succeed: false
      run "udevadm", args: ["trigger"], sudo: true, must_succeed: false
    end
  end
end
