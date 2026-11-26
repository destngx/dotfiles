{ ... }:
{
  imports = [
    ./base.nix
    ./firewall.nix
    ./homebrew.nix
    ./nix-gc.nix
    ./tailscale.nix
  ];
}
