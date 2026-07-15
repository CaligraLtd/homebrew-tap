# Originally from https://github.com/ublue-os/homebrew-tap/blob/main/Casks/1password-gui-linux.rb
require "etc"

cask "1password-gui-linux" do
  arch intel: "x86_64", arm: "aarch64"
  os linux: "linux"

  version "8.12.28"
  sha256 arm64_linux:  "95b8885dec9ec73e97a570fbff9ed4fd3fff2431010e2926f4768d475b7b729b",
         x86_64_linux: "2695d72e98c039f061fa8735608071a816616b4d88bb3725561411885dbd57a7"

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
           target: "#{Dir.home}/.local/share/icons/1password.png"
  artifact "1password-#{version}.#{arch_suffix}/com.1password.1Password.policy.tpl",
           target: "#{HOMEBREW_PREFIX}/etc/polkit-1/actions/com.1password.1Password.policy"

  preflight do
    desktop_file = "#{staged_path}/1password-#{version}.#{arch_suffix}/resources/1password.desktop"
    text = File.read(desktop_file)
    new_contents = text.gsub("Exec=/opt/1Password/1password", "Exec=#{HOMEBREW_PREFIX}/bin/1password")
    File.write(desktop_file, new_contents)
  end

  postflight do
    system "echo", "Installing polkit policy file to /etc/polkit-1/actions/, you may be prompted for your password."
    if !File.exist?("/etc/polkit-1/actions/com.1password.1Password.policy") ||
       !FileUtils.identical?("#{staged_path}/1password-#{version}.#{arch_suffix}/com.1password.1Password.policy.tpl",
                             "/etc/polkit-1/actions/com.1password.1Password.policy")

      # Get users from /etc/passwd and output first 10 human users (1000 >= UID <= 9999) to the policy file
      # format: `unix-user:username` space separated
      # This is used to allow these users to unlock 1Password via polkit.
      human_users = `awk -F: '$3 >= 1000 && $3 <= 9999 && $1 != "nobody" { print $1 }' /etc/passwd`
                    .split("\n").first(10)
      policy_owners = human_users.map { |user| "unix-user:#{user}" }.join(" ")
      policy_file = File.read("#{staged_path}/1password-#{version}.#{arch_suffix}/com.1password.1Password.policy.tpl")
      replaced_contents = policy_file.gsub("${POLICY_OWNERS}", policy_owners)
      File.write("#{staged_path}/1password-#{version}.#{arch_suffix}/com.1password.1Password.policy", replaced_contents)
      system "sudo", "install", "-Dm0644",
             "#{staged_path}/1password-#{version}.#{arch_suffix}/com.1password.1Password.policy",
             "/etc/polkit-1/actions/com.1password.1Password.policy"
      puts "Installed /etc/polkit-1/actions/com.1password.1Password.policy"
    else
      puts "Skipping installation of /etc/polkit-1/actions/com.1password.1Password.policy,
      as it already exists and is the same as the version to be installed."
    end

    # Setup browser integration - create onepassword group and set permissions
    # This requires sudo; if unavailable the install still succeeds but browser
    # integration must be configured manually.
    puts "Setting up browser integration..."
    group_name = "onepassword"
    install_path = "#{HOMEBREW_PREFIX}/Caskroom/1password-gui-linux/#{version}"
    app_dir = "#{install_path}/1password-#{version}.#{arch_suffix}"
    browser_support_path = "#{app_dir}/1Password-BrowserSupport"

    # Create onepassword group if it doesn't exist
    unless system("getent", "group", group_name, out: File::NULL, err: File::NULL)
      system "sudo", "groupadd", group_name
    end

    browser_integration_ok =
      system("sudo", "chown", "-R", "root:root", app_dir) &&
      system("sudo", "chgrp", group_name, browser_support_path) &&
      system("sudo", "chmod", "2755", browser_support_path)

    # Also set root ownership on any installed Chrome versions
    chrome_cask_dir = "#{HOMEBREW_PREFIX}/Caskroom/google-chrome-linux"
    chrome_dirs = []
    if Dir.exist?(chrome_cask_dir)
      Dir.children(chrome_cask_dir).reject { |e| e.start_with?(".") }.each do |chrome_version|
        chrome_dir = "#{chrome_cask_dir}/#{chrome_version}/opt/google/chrome"
        next unless Dir.exist?(chrome_dir)

        chrome_dirs << chrome_dir
        browser_integration_ok &&= system("sudo", "chown", "-R", "root:root", chrome_dir)
      end
    end

    if browser_integration_ok
      puts "Browser integration configured. Restart your browsers to enable 1Password integration."
    else
      puts ""
      puts "WARNING: Could not configure 1Password browser integration."
      puts "Browser integration requires the application directory to be root-owned"
      puts "and the BrowserSupport binary to have setgid permissions."
      puts ""
      puts "To set up manually, run:"
      puts "  sudo groupadd #{group_name}"
      puts "  sudo chown -R root:root #{app_dir}"
      puts "  sudo chgrp #{group_name} #{browser_support_path}"
      puts "  sudo chmod 2755 #{browser_support_path}"
      chrome_dirs.each { |dir| puts "  sudo chown -R root:root #{dir}" }
    end

    File.write("#{staged_path}/zpass.sh", <<~EOS)
      #!/bin/bash
      zenity --password --title="Homebrew Sudo Password Prompt"
    EOS

    File.write("#{staged_path}/1password-uninstall.sh", <<~EOS)
      #!/bin/bash
      set -e

      SUDO_ASKPASS=#{staged_path}/zpass.sh
      echo "Uninstalling polkit policy file from /etc/polkit-1/actions/com.1password.1Password.policy"
      if [ -f /etc/polkit-1/actions/com.1password.1Password.policy ]; then
        sudo rm -f /etc/polkit-1/actions/com.1password.1Password.policy
        echo "Removed /etc/polkit-1/actions/com.1password.1Password.policy"
      else
        echo "/etc/polkit-1/actions/com.1password.1Password.policy does not exist, skipping."
      fi
    EOS
  end

  uninstall_preflight do
    # Change ownership back to allow homebrew to clean up
    install_path = "#{HOMEBREW_PREFIX}/Caskroom/1password-gui-linux/#{version}"
    app_dir = "#{install_path}/1password-#{version}.#{arch_suffix}"
    if Dir.exist?(app_dir) && File.stat(app_dir).uid == 0
      current_user = Etc.getpwuid(Process.uid).name
      current_group = Etc.getgrgid(Process.gid).name
      unless system "sudo", "chown", "-R", "#{current_user}:#{current_group}", app_dir
        puts "WARNING: Could not restore ownership on #{app_dir}."
        puts "Homebrew uninstall/upgrade may fail. Run manually:"
        puts "  sudo chown -R #{current_user}:#{current_group} #{app_dir}"
      end
    end

    system "chmod", "+x", "#{staged_path}/1password-uninstall.sh"
    system "#{staged_path}/1password-uninstall.sh"
  end

  zap trash: [
    "~/.cache/1password",
    "~/.config/1Password",
    "~/.local/share/keyrings/1password.keyring",
  ]
end
