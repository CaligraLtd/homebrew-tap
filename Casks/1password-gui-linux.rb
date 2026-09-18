# Originally from https://github.com/ublue-os/homebrew-tap/blob/main/Casks/1password-gui-linux.rb
cask "1password-gui-linux" do
  arch intel: "x86_64", arm: "aarch64"
  os linux: "linux"

  version "8.12.36"
  sha256 arm64_linux:  "4b58851b3bf52a7bbc79243fc6b9cba9591cabe8b7eb2d0e271593bad2192af9",
         x86_64_linux: "393c93c8025fee5dda76a4d0f1e478e98526cc946e58a22efe26f540ea2b5729"

  arch_suffix =
    case arch
    when "aarch64" then "arm64"
    when "x86_64" then "x64"
    end

  url "https://downloads.1password.com/#{os}/tar/stable/#{arch}/1password-#{version}.#{arch_suffix}.tar.gz"
  name "1Password"
  desc "Password manager that keeps all passwords secure behind one password"
  homepage "https://1password.com/"

  livecheck do
    url "https://releases.1password.com/linux/stable/index.xml"
    regex(/v?(\d+(?:\.\d+)+)/i)
    strategy :xml do |xml, regex|
      xml.get_elements("rss//channel//item//link").map { |item| item.text[regex, 1] }
    end
  end

  binary "1password-#{version}.#{arch_suffix}/1password", target: "1password"
  binary "1password-#{version}.#{arch_suffix}/op-ssh-sign", target: "op-ssh-sign"
  binary "1password-#{version}.#{arch_suffix}/1Password-BrowserSupport", target: "1Password-BrowserSupport"
  binary "1password-#{version}.#{arch_suffix}/1Password-Crash-Handler", target: "1Password-Crash-Handler"
  binary "1password-#{version}.#{arch_suffix}/1Password-LastPass-Exporter", target: "1Password-LastPass-Exporter"
  artifact "1password-#{version}.#{arch_suffix}/resources/com.onepassword.OnePassword.desktop",
           target: "#{Dir.home}/.local/share/applications/com.onepassword.OnePassword.desktop"
  artifact "1password-#{version}.#{arch_suffix}/resources/icons/hicolor/256x256/apps/1password.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/256x256/apps/1password.png"

  preflight_steps do
    inreplace "1password-{{version}}.#{arch_suffix}/resources/com.onepassword.OnePassword.desktop",
              "Exec=/opt/1Password/1password", "Exec={{HOMEBREW_PREFIX}}/bin/1password"
    inreplace "1password-{{version}}.#{arch_suffix}/resources/com.onepassword.OnePassword.desktop", /^Icon=.*$/,
              "Icon=#{Dir.home}/.local/share/icons/hicolor/256x256/apps/1password.png", global: false
  end

  postflight_steps do
    run "sed", args: ["/<annotate key=\"org.freedesktop.policykit.owner\">/d",
                      "1password-{{version}}.#{arch_suffix}/com.1password.1Password.policy.tpl"],
               stdout_path: "com.1password.1Password.policy", chdir: "."

    write_file "caligra-1password-setup.sh", <<~SH
      #!/usr/bin/env bash
      set -euo pipefail

      app_dir="{{staged_path}}/1password-{{version}}.#{arch_suffix}"
      getent group onepassword >/dev/null || groupadd --system onepassword
      install -Dm0644 "{{staged_path}}/com.1password.1Password.policy" /etc/polkit-1/actions/com.1password.1Password.policy
      chown -R root:root "$app_dir"
      chgrp onepassword "$app_dir/1Password-BrowserSupport"
      chmod 2755 "$app_dir/1Password-BrowserSupport"
      for chrome_dir in "{{HOMEBREW_PREFIX}}"/Caskroom/google-chrome-linux/*/opt/google/chrome; do
        [ -d "$chrome_dir" ] || continue
        chown -R root:root "$chrome_dir"
      done
      echo "Browser integration configured. Restart your browsers to enable it."
    SH
    run "/bin/bash", args: ["{{staged_path}}/caligra-1password-setup.sh"], sudo: true, must_succeed: false,
                     print_stdout: true
  end

  uninstall_preflight_steps do
    write_file "caligra-1password-teardown.sh", <<~SH
      #!/usr/bin/env bash
      set -euo pipefail

      app_dir="{{staged_path}}/1password-{{version}}.#{arch_suffix}"
      owner="$SUDO_UID:$SUDO_GID"
      if [ -d "$app_dir" ]; then
        chown -R "$owner" "$app_dir"
      fi
      rm -f -- /etc/polkit-1/actions/com.1password.1Password.policy
      for chrome_dir in "{{HOMEBREW_PREFIX}}"/Caskroom/google-chrome-linux/*/opt/google/chrome; do
        [ -d "$chrome_dir" ] || continue
        chown -R "$owner" "$chrome_dir"
      done
    SH
    run "/bin/bash", args: ["{{staged_path}}/caligra-1password-teardown.sh"], sudo: true
  end

  zap trash: [
    "~/.cache/1password",
    "~/.config/1Password",
    "~/.local/share/keyrings/1password.keyring",
  ]
end
