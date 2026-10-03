{ config, pkgs, ... }:
{
  home.username = "destnguyxn";
  home.homeDirectory = "/Users/destnguyxn";
  home.stateVersion = "26.05";

  xdg.enable = true;

  home.packages = with pkgs; [
    awscli2
    bat
    chafa
    checkov
    delta
    eza
    fd
    findutils
    git-lfs
    go
    gnused
    ghostscript
    kubernetes-helm
    imagemagick
    lazygit
    llvm
    lua-language-server
    luajit
    minikube
    mosh
    mtr
    neovim
    onefetch
    opentofu
    peco
    pngpaste
    qemu
    ripgrep
    rustup
    tailscale
    terminal-notifier
    tmux
    uv
    yq-go
    zsh
    pi-coding-agent
  ];

  home.activation.restartKarabiner = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    /bin/launchctl kickstart -k gui/$(/usr/bin/id -u)/org.pqrs.service.agent.Karabiner-Console-User-Server
  '';

  programs.zsh.enable = false;

  home.file.".zshenv".text = ''
    export ZDOTDIR="$HOME/projects/dotfiles/zsh"
    source "$ZDOTDIR/.zshenv"
  '';

  programs.tmux = {
    enable = false;
  };

  programs.git.enable = false;

  home.file = {
    ".config/aerospace".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/projects/dotfiles/aerospace";
    ".config/karabiner".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/projects/dotfiles/karabiner";
    ".gitconfig".source = ../../git/.gitconfig;
    ".tmux.conf".source = ../../tmux/.tmux.conf;
    ".tmux.conf.local".source = ../../tmux/.tmux.conf.local;
  };
}
