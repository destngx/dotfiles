{ pkgs, ... }:
{
  home.packages = with pkgs; [
    awscli2
    aerospace
    bat
    chafa
    delta
    eza
    fd
    findutils
    fzf
    git-lfs
    gnused
    gnupg
    imagemagick
    lazygit
    mosh
    mise
    neovim
    opentofu
    peco
    ripgrep
    sqlite
    tailscale
    yq-go
  ];
}
