{ config, lib, ... }:
let
  socketfilterfw = "/usr/libexec/ApplicationFirewall/socketfilterfw";
  # The tailscaled wrapper script execs this binary, so the firewall sees it as the listening app.
  tailscaled = "${config.services.tailscale.package}/bin/.tailscaled-wrapped";
in
{
  services.tailscale.enable = true;

  # The firewall only auto-allows binaries with a real signature, and nix binaries are ad-hoc
  # signed, so allow incoming WireGuard UDP to tailscaled. Without this, peers that try to reach
  # the Mac first fall back to a DERP relay. The store path changes with every tailscale update,
  # so drop entries for older builds.
  system.activationScripts.postActivation.text =
    lib.mkIf (config.networking.applicationFirewall.enable == true) ''
      ${socketfilterfw} --listapps | awk '/-tailscale-.*\/bin\/\.tailscaled-wrapped/ {print $3}' \
        | while read -r app; do
            [ "$app" != "${tailscaled}" ] && ${socketfilterfw} --remove "$app" >/dev/null
          done
      ${socketfilterfw} --add ${tailscaled} >/dev/null
      ${socketfilterfw} --unblockapp ${tailscaled} >/dev/null
    '';
}
