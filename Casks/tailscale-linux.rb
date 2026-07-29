cask "tailscale-linux" do
  arch arm: "arm64", intel: "amd64"

  version "1.98.10"
  sha256 arm64_linux:  "d74a84e07cb1948d9f09a23ae161417c6127e562949773705c95d0762be2809d",
         x86_64_linux: "52490ce0832b245857e2afef7426d6ae5a4b49fb391412833cc95729bd23f7de"

  url "https://pkgs.tailscale.com/stable/tailscale_#{version}_#{arch}.tgz"
  name "Tailscale"
  desc "Mesh VPN based on WireGuard"
  homepage "https://tailscale.com/"

  livecheck do
    url "https://github.com/tailscale/tailscale"
    strategy :github_latest
  end

  binary "tailscale_#{version}_#{arch}/tailscale"
  binary "tailscale_#{version}_#{arch}/tailscaled"

  preflight do
    FileUtils.mkdir_p("#{HOMEBREW_PREFIX}/share/tailscale")

    File.write("#{staged_path}/tailscale-enable", <<~SCRIPT)
      #!/bin/bash
      set -euo pipefail

      HOMEBREW_PREFIX="#{HOMEBREW_PREFIX}"
      SERVICE_TEMPLATE="${HOMEBREW_PREFIX}/share/tailscale/tailscaled.service.upstream"
      DEFAULTS_SOURCE="${HOMEBREW_PREFIX}/share/tailscale/tailscaled.defaults"

      if [ ! -f "$SERVICE_TEMPLATE" ]; then
        echo "Error: upstream service file not found at $SERVICE_TEMPLATE" >&2
        echo "Try reinstalling: brew reinstall --cask tailscale-linux" >&2
        exit 1
      fi

      # Prompt for sudo credentials upfront
      sudo -v

      # Copy binaries to /var/lib/tailscale/bin/ so systemd can execute them.
      # Homebrew lives under /home which has SELinux type user_home_t —
      # systemd (init_t) cannot traverse those directories.
      # /usr/ is read-only on bootc, so /var/lib/ is the writable alternative.
      sudo mkdir -p /var/lib/tailscale/bin
      sudo install -m 0755 "$(readlink -f "${HOMEBREW_PREFIX}/bin/tailscaled")" /var/lib/tailscale/bin/tailscaled
      sudo install -m 0755 "$(readlink -f "${HOMEBREW_PREFIX}/bin/tailscale")" /var/lib/tailscale/bin/tailscale
      sudo chcon -t bin_t /var/lib/tailscale/bin/tailscaled /var/lib/tailscale/bin/tailscale 2>/dev/null || true

      # Patch binary paths to use /var/lib/ copies
      sed "s|/usr/sbin/tailscaled|/var/lib/tailscale/bin/tailscaled|g" \\
        "$SERVICE_TEMPLATE" | sudo tee /etc/systemd/system/tailscaled.service >/dev/null

      # Install defaults file if not already present (preserves user customizations)
      if [ ! -f /etc/default/tailscaled ]; then
        sudo mkdir -p /etc/default
        sudo cp "$DEFAULTS_SOURCE" /etc/default/tailscaled
      fi

      sudo systemctl daemon-reload
      sudo systemctl enable --now tailscaled
      # Restart if already running (picks up new binaries after upgrade)
      if systemctl is-active --quiet tailscaled; then
        sudo systemctl restart tailscaled
      fi

      sleep 2
      if sudo /var/lib/tailscale/bin/tailscale set --operator="$USER" 2>/dev/null; then
        echo "Tailscale enabled. Operator set to $USER."
      else
        echo "Tailscale enabled."
        echo "Note: could not set operator automatically. Run 'sudo tailscale set --operator=$USER' manually."
      fi
      echo "Run 'tailscale up' to authenticate."
    SCRIPT
    FileUtils.chmod(0o755, "#{staged_path}/tailscale-enable")

    File.write("#{staged_path}/tailscale-disable", <<~SCRIPT)
      #!/bin/bash
      set -euo pipefail

      if ! systemctl is-enabled tailscaled &>/dev/null; then
        echo "Tailscale service is not enabled, nothing to do."
        exit 0
      fi

      sudo systemctl stop tailscaled
      sudo systemctl disable tailscaled
      sudo rm -f /etc/systemd/system/tailscaled.service
      sudo rm -rf /var/lib/tailscale/bin
      sudo systemctl daemon-reload

      echo "Tailscale service stopped and disabled."
      echo "Note: /var/lib/tailscale/ (node identity) and /etc/default/tailscaled (config) preserved."
    SCRIPT
    FileUtils.chmod(0o755, "#{staged_path}/tailscale-disable")
  end

  binary "tailscale-enable"
  binary "tailscale-disable"

  artifact "tailscale_#{version}_#{arch}/systemd/tailscaled.service",
           target: "#{HOMEBREW_PREFIX}/share/tailscale/tailscaled.service.upstream"
  artifact "tailscale_#{version}_#{arch}/systemd/tailscaled.defaults",
           target: "#{HOMEBREW_PREFIX}/share/tailscale/tailscaled.defaults"

  caveats <<~EOS
    To start Tailscale, enable the system service:
      tailscale-enable

    Then authenticate:
      tailscale up

    To stop and disable Tailscale:
      tailscale-disable

    After upgrading, re-run 'tailscale-enable' to install the new binaries.
  EOS

  uninstall_preflight do
    if system("systemctl", "is-enabled", "--quiet", "tailscaled")
      system "sudo", "systemctl", "stop", "tailscaled"
      system "sudo", "systemctl", "disable", "tailscaled"
    end
    system "sudo", "rm", "-f", "/etc/systemd/system/tailscaled.service"
    system "sudo", "rm", "-rf", "/var/lib/tailscale/bin"
    system "sudo", "systemctl", "daemon-reload"
  end
end
