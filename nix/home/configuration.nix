{ pkgs, ... }:
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

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    completionInit = "";
    plugins = [
      {
        name = "forgit";
        src = pkgs.zsh-forgit;
      }
    ];
    envExtra = ''
      source ${../../zsh/.zshenv}
    '';
    initContent = ''
      source ${../../zsh/.zshrc}
    '';
  };

  programs.tmux = {
    enable = false;
  };

  programs.git.enable = false;

  home.file = {
    ".config/zsh/.zimrc".source = ../../zsh/.zimrc;
    ".config/zsh/.zsh_aliases".source = ../../zsh/.zsh_aliases;
    ".config/zsh/.zsh_functions".source = ../../zsh/.zsh_functions;
    ".config/zsh/.zsh_completions".source = ../../zsh/.zsh_completions;

    ".gitconfig".source = ../../git/.gitconfig;
    ".tmux.conf".source = ../../tmux/.tmux.conf;
    ".tmux.conf.local".source = ../../tmux/.tmux.conf.local;
  };
}
