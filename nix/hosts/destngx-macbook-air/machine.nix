{
  hostName = "destngx-macbook-air";
  username = "destnguyxn";
  homeDirectory = "/Users/destnguyxn";
  repositoryDirectory = "/Users/destnguyxn/projects/dotfiles";
  system = "aarch64-darwin";
  unstablePackages = [
    # Unstable: pnpm 12 global installs (npm.package_manager = "pnpm") need mise >= 2026.9.2.
    "mise"
    "pi-coding-agent"
    # Unstable: TS-2026-013 is fixed in tailscale >= 1.104.2, newer than the stable channel ships.
    "tailscale"
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
    "neovim"
    "opentofu"
    "peco"
    "ripgrep"
    "sqlite"
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
