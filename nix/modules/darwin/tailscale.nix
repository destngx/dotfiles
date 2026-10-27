{ config, lib, machine, pkgs, ... }:
let
  socketfilterfw = "/usr/libexec/ApplicationFirewall/socketfilterfw";
  # The tailscaled wrapper script execs this binary, so the firewall sees it as the listening app.
  tailscaled = "${config.services.tailscale.package}/bin/.tailscaled-wrapped";
in
{
  services.tailscale.enable = true;
  # Run the daemon from the same channel as the CLI the host installs, so the two never mismatch.
  services.tailscale.package =
    if lib.elem "tailscale" machine.unstablePackages then pkgs.unstable.tailscale else pkgs.tailscale;

  # nix-darwin links /etc/resolver/ts.net into /etc/static. Since 1.104, tailscaled opens
  # /etc/resolver files without following links that leave the directory, so the link makes every
  # DNS update fail with "openat ts.net: path escapes from parent". Write a regular file instead.
  environment.etc."resolver/ts.net".enable = false;

  system.activationScripts.postActivation.text = lib.mkMerge [
    ''
      rm -f /etc/resolver/ts.net
      mkdir -p /etc/resolver
      echo "nameserver 100.100.100.100" > /etc/resolver/ts.net
    ''

    # The firewall only auto-allows binaries with a real signature, and nix binaries are ad-hoc
    # signed, so allow incoming WireGuard UDP to tailscaled. Without this, peers that try to reach
    # the Mac first fall back to a DERP relay. The store path changes with every tailscale update,
    # so drop entries for older builds.
    (lib.mkIf (config.networking.applicationFirewall.enable == true) ''
      ${socketfilterfw} --listapps | awk '/-tailscale-.*\/bin\/\.tailscaled-wrapped/ {print $3}' \
        | while read -r app; do
            [ "$app" != "${tailscaled}" ] && ${socketfilterfw} --remove "$app" >/dev/null
          done
      ${socketfilterfw} --add ${tailscaled} >/dev/null
      ${socketfilterfw} --unblockapp ${tailscaled} >/dev/null
    '')
  ];
}
