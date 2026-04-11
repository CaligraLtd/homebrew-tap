cask "tailscale-linux" do
  arch arm: "arm64", intel: "amd64"

  version "1.96.4"
  sha256 arm64_linux:  "a27249bc70d7b37a68f8be7f5c4507ea5f354e592dce43cb5d4f3e742b313c3c",
         x86_64_linux: "a1cba18826b1f91cb25ef7f5b8259b5258339b42db7867af9269e21829ea78cc"

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

      # Self-escalate to root (avoids sudo secure_path not including Homebrew bin)
      if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$(readlink -f "$0")" "$@"
      fi

      HOMEBREW_PREFIX="#{HOMEBREW_PREFIX}"
      SERVICE_TEMPLATE="${HOMEBREW_PREFIX}/share/tailscale/tailscaled.service.upstream"
      DEFAULTS_SOURCE="${HOMEBREW_PREFIX}/share/tailscale/tailscaled.defaults"
      TARGET_SERVICE="/etc/systemd/system/tailscaled.service"
      TARGET_DEFAULTS="/etc/default/tailscaled"

      if [ ! -f "$SERVICE_TEMPLATE" ]; then
        echo "Error: upstream service file not found at $SERVICE_TEMPLATE" >&2
        echo "Try reinstalling: brew reinstall --cask tailscale-linux" >&2
        exit 1
      fi

      # Copy binaries to /var/lib/tailscale/bin/ so systemd can execute them.
      # Homebrew lives under /home which has SELinux type user_home_t —
      # systemd (init_t) cannot traverse those directories.
      # /usr/ is read-only on bootc, so /var/lib/ is the writable alternative.
      mkdir -p /var/lib/tailscale/bin
      install -m 0755 "$(readlink -f "${HOMEBREW_PREFIX}/bin/tailscaled")" /var/lib/tailscale/bin/tailscaled
      install -m 0755 "$(readlink -f "${HOMEBREW_PREFIX}/bin/tailscale")" /var/lib/tailscale/bin/tailscale
      chcon -t bin_t /var/lib/tailscale/bin/tailscaled /var/lib/tailscale/bin/tailscale 2>/dev/null || true

      # Patch binary paths to use /var/lib/ copies
      sed "s|/usr/sbin/tailscaled|/var/lib/tailscale/bin/tailscaled|g" \\
        "$SERVICE_TEMPLATE" > "$TARGET_SERVICE"

      # Install defaults file if not already present (preserves user customizations)
      if [ ! -f "$TARGET_DEFAULTS" ]; then
        mkdir -p /etc/default
        cp "$DEFAULTS_SOURCE" "$TARGET_DEFAULTS"
      fi

      systemctl daemon-reload
      systemctl enable --now tailscaled
      # Restart if already running (picks up new binaries after upgrade)
      if systemctl is-active --quiet tailscaled; then
        systemctl restart tailscaled
      fi

      if [ -n "${SUDO_USER:-}" ]; then
        sleep 2
        if /var/lib/tailscale/bin/tailscale set --operator="$SUDO_USER" 2>/dev/null; then
          echo "Tailscale enabled. Operator set to $SUDO_USER."
        else
          echo "Tailscale enabled."
          echo "Note: could not set operator automatically. Run 'sudo tailscale set --operator=$SUDO_USER' manually."
        fi
      else
        echo "Tailscale enabled."
        echo "Warning: \\$SUDO_USER not set. Run 'sudo tailscale set --operator=YOUR_USER' manually."
      fi
      echo "Run 'tailscale up' to authenticate."
    SCRIPT
    FileUtils.chmod(0o755, "#{staged_path}/tailscale-enable")

    File.write("#{staged_path}/tailscale-disable", <<~SCRIPT)
      #!/bin/bash
      set -euo pipefail

      # Self-escalate to root (avoids sudo secure_path not including Homebrew bin)
      if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$(readlink -f "$0")" "$@"
      fi

      if ! systemctl is-enabled tailscaled &>/dev/null; then
        echo "Tailscale service is not enabled, nothing to do."
        exit 0
      fi

      systemctl stop tailscaled
      systemctl disable tailscaled
      rm -f /etc/systemd/system/tailscaled.service
      rm -rf /var/lib/tailscale/bin
      systemctl daemon-reload

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
    system "chmod", "+x", "#{staged_path}/tailscale-disable"
    system "sudo", "#{staged_path}/tailscale-disable"
  end
end
