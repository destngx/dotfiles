{ ... }:
{
  imports = [
    ../../modules/home/base.nix
    ../../modules/home/tools.nix

    ../../modules/home/apps/aerospace.nix
    ../../modules/home/apps/karabiner.nix
    ../../modules/home/apps/pngpaste.nix
    ../../modules/home/apps/tmux.nix
    ../../modules/home/apps/git.nix
    ../../modules/home/apps/zsh.nix
    ../../modules/home/apps/wezterm.nix
    ../../modules/home/apps/pi.nix
  ];
}
