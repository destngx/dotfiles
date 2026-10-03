{ inputs, pkgs, ... }:
{
  imports = [ ./homebrew.nix ];

  nix.enable = false;

  system.stateVersion = 6;
  system.primaryUser = "destnguyxn";

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;
  programs.zsh.enableGlobalCompInit = false;
  environment.shells = [ pkgs.zsh ];
  services.tailscale.enable = true;

  users.users.destnguyxn = {
    name = "destnguyxn";
    home = "/Users/destnguyxn";
    shell = pkgs.zsh;
  };

  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    user = "destnguyxn";
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-services" = inputs.homebrew-services;
      "nikitabobko/homebrew-tap" = inputs.aerospace-tap;
      "vjeantet/homebrew-tap" = inputs.vjeantet-tap;
    };
    trust.taps = [ "nikitabobko/tap" ];
  };
}
