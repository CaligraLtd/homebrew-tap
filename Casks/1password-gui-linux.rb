# Originally from https://github.com/ublue-os/homebrew-tap/blob/main/Casks/1password-gui-linux.rb
require "etc"
require "shellwords"

cask "1password-gui-linux" do
  arch intel: "x86_64", arm: "aarch64"
  os linux: "linux"

  version "8.12.34"
  sha256 arm64_linux:  "ea5102363d6cf3442b96a7abd6743da8c1d261f56a628e1a3c183d84fa65fdcb",
         x86_64_linux: "297784aa66770b645607a7f04c9ba2c4aebed4f46d21202487f521ba572b7b13"

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
  artifact "1password-#{version}.#{arch_suffix}/resources/1password.desktop",
           target: "#{Dir.home}/.local/share/applications/1password.desktop"
  artifact "1password-#{version}.#{arch_suffix}/resources/icons/hicolor/256x256/apps/1password.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/256x256/apps/1password.png"

  preflight do
    desktop_file = "#{staged_path}/1password-#{version}.#{arch_suffix}/resources/1password.desktop"
    File.write(desktop_file,
               File.read(desktop_file)
                   .gsub("Exec=/opt/1Password/1password", "Exec=#{HOMEBREW_PREFIX}/bin/1password")
                   .sub(/^Icon=.*$/, "Icon=#{Dir.home}/.local/share/icons/hicolor/256x256/apps/1password.png"))
  end

  postflight do
    app_dir = "#{HOMEBREW_PREFIX}/Caskroom/1password-gui-linux/#{version}/1password-#{version}.#{arch_suffix}"
    browser_support_path = "#{app_dir}/1Password-BrowserSupport"
    policy_template = "#{staged_path}/1password-#{version}.#{arch_suffix}/com.1password.1Password.policy.tpl"
    policy_target = "/etc/polkit-1/actions/com.1password.1Password.policy"
    group_name = "onepassword"

    policy_rendered = "#{staged_path}/com.1password.1Password.policy"
    File.write(policy_rendered,
               File.read(policy_template)
                   .gsub(%r{^\s*<annotate key="org\.freedesktop\.policykit\.owner">[^<]*</annotate>\s*\n}, ""))

    chrome_cask_dir = "#{HOMEBREW_PREFIX}/Caskroom/google-chrome-linux"
    chrome_dirs =
      if Dir.exist?(chrome_cask_dir)
        Dir.children(chrome_cask_dir)
           .reject { |e| e.start_with?(".") }
           .map { |v| "#{chrome_cask_dir}/#{v}/opt/google/chrome" }
           .select { |d| Dir.exist?(d) }
      else
        []
      end

    chrome_lines = chrome_dirs.map { |d| "chown -R root:root #{d.shellescape}" }.join("\n")

    privileged_script = "#{staged_path}/caligra-1password-setup.sh"
    File.write(privileged_script, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail

      getent group #{group_name.shellescape} >/dev/null || groupadd --system #{group_name.shellescape}
      install -Dm0644 #{policy_rendered.shellescape} #{policy_target.shellescape}
      chown -R root:root #{app_dir.shellescape}
      chgrp #{group_name.shellescape} #{browser_support_path.shellescape}
      chmod 2755 #{browser_support_path.shellescape}
      #{chrome_lines}
    SH
    FileUtils.chmod(0755, privileged_script)

    ohai "Configuring 1Password polkit policy and browser integration (sudo required)"
    if system("sudo", "--", "bash", privileged_script)
      ohai "Browser integration configured. Restart your browsers to enable it."
    else
      opoo <<~MSG
        Could not configure 1Password polkit policy or browser integration.
        To finish setup manually:
          sudo bash #{privileged_script}
      MSG
    end
  end

  uninstall_preflight do
    app_dir = "#{HOMEBREW_PREFIX}/Caskroom/1password-gui-linux/#{version}/1password-#{version}.#{arch_suffix}"
    policy_target = "/etc/polkit-1/actions/com.1password.1Password.policy"

    needs_chown = Dir.exist?(app_dir) && File.stat(app_dir).uid.zero?
    needs_policy_removal = File.exist?(policy_target)

    next if !needs_chown && !needs_policy_removal

    current_user = Etc.getpwuid(Process.uid).name
    current_group = Etc.getgrgid(Process.gid).name
    owner = "#{current_user.shellescape}:#{current_group.shellescape}"

    chown_line = "chown -R #{owner} #{app_dir.shellescape}" if needs_chown
    rm_line = "rm -f -- #{policy_target.shellescape}" if needs_policy_removal

    privileged_script = "#{staged_path}/caligra-1password-teardown.sh"
    File.write(privileged_script, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      #{chown_line}
      #{rm_line}
    SH
    FileUtils.chmod(0755, privileged_script)

    ohai "Cleaning up 1Password privileged state (sudo required)"
    next if system("sudo", "--", "bash", privileged_script)

    fallback = []
    fallback << "  sudo chown -R #{current_user}:#{current_group} #{app_dir}" if needs_chown
    fallback << "  sudo rm -f -- #{policy_target}" if needs_policy_removal
    raise <<~MSG
      Failed to clean up 1Password privileged state.
      Run the following and retry the uninstall/upgrade:
      #{fallback.join("\n")}
    MSG
  end

  zap trash: [
    "~/.cache/1password",
    "~/.config/1Password",
    "~/.local/share/keyrings/1password.keyring",
  ]
end
