{
  hostName = "destngx-macbook-air";
  username = "destnguyxn";
  homeDirectory = "/Users/destnguyxn";
  repositoryDirectory = "/Users/destnguyxn/projects/dotfiles";
  system = "aarch64-darwin";
  unstablePackages = [
    "pi-coding-agent"
  ];
  packages = [
    "awscli2"
    "aerospace"
    "bat"
    "chafa"
    "delta"
    "eza"
    "fd"
    "findutils"
    "fzf"
    "ghostty-bin"
    "git-lfs"
    "gnused"
    "gnupg"
    "imagemagick"
    "lazygit"
    "mosh"
    "mise"
    "neovim"
    "opentofu"
    "peco"
    "ripgrep"
    "sqlite"
    "tailscale"
    "yq-go"
  ];
  homebrew = {
    taps = [ ];
    brews = [
      "gh"
      "terminal-notifier"
    ];
    casks = [
      "browserosaurus"
      "claude"
      "claude-code@latest"
      "codex"
      "gcc-arm-embedded"
      "maccy"
      "mos"
      "session-manager-plugin"
      "windows-app"
    ];
  };
}
