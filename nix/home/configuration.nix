{ config, inputs, machine, pkgs, ... }:
let
  unstable-pkgs = import inputs.nixpkgs-unstable { system = pkgs.system; };
in
{
  home.username = machine.username;
  home.homeDirectory = machine.homeDirectory;
  home.stateVersion = "26.05";

  xdg.enable = true;

  home.packages = with pkgs; [
    awscli2
    bat
    chafa
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
    tmux
    uv
    yq-go
    zsh
    unstable-pkgs.pi-coding-agent
  ];

  home.activation.restartKarabiner = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    /bin/launchctl kickstart -k gui/$(/usr/bin/id -u)/org.pqrs.service.agent.Karabiner-Console-User-Server
  '';

  # These Home Manager modules stay disabled because the configs are provided via home.file below.
  # The zsh entry sources the repository's .zshenv; tmux and Git files are linked directly.
  programs.zsh.enable = false;

  home.file.".zshenv".text = ''
    export ZDOTDIR="${machine.repositoryDirectory}/zsh"
    source "$ZDOTDIR/.zshenv"
  '';

  programs.tmux = {
    enable = false;
  };

  programs.git.enable = false;

  home.file = {
    ".config/aerospace".source = config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/aerospace";
    ".config/karabiner".source = config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/karabiner";
    ".config/wezterm".source = config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/wezterm";
    ".gitconfig".source = ../../git/.gitconfig;
    ".tmux.conf".source = ../../tmux/.tmux.conf;
    ".tmux.conf.local".source = ../../tmux/.tmux.conf.local;
  };
}
