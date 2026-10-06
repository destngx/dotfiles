{ ... }:
{
  imports = [
    ../../modules/home/base.nix
    ../../modules/home/pkgs.nix

    ../../modules/home/apps/aerospace.nix
    ../../modules/home/apps/karabiner.nix
    ../../modules/home/apps/pngpaste.nix
    ../../modules/home/apps/herdr.nix
    ../../modules/home/apps/git.nix
    ../../modules/home/apps/zsh.nix
    ../../modules/home/apps/ghostty.nix
    ../../modules/home/apps/pi.nix
  ];
}
