{
  hostName = "destngx-macbook-air";
  username = "destnguyxn";
  homeDirectory = "/Users/destnguyxn";
  repositoryDirectory = "/Users/destnguyxn/projects/dotfiles";
  system = "aarch64-darwin";
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
      "terminal-notifier"
    ];
    casks = [
      "browserosaurus"
      "claude"
      "claude-code"
      "codex"
      "gcc-arm-embedded"
      "session-manager-plugin"
      "windows-app"
    ];
  };
}
