{ config, lib, ... }:
let
  cfg = config.firewall;
in
{
  options.firewall = {
    stealthMode = lib.mkEnableOption ''
      the application firewall in stealth mode, so the Mac ignores ICMP ping and does not answer
      connection attempts to closed ports
    '';
  };

  # Stealth mode only takes effect while the application firewall is on.
  config.networking.applicationFirewall = lib.mkIf cfg.stealthMode {
    enable = true;
    enableStealthMode = true;
  };
}
