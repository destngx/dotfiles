{ lib, ... }:
{
  home.sessionVariables = {
    FZF_DEFAULT_COMMAND = "rg --files --hidden --glob '!.git'";
    FZF_DEFAULT_OPTS = "-i --height=50%";
  };

  programs.zsh.initContent = lib.mkAfter ''
    if command -v fzf >/dev/null 2>&1; then
      alias vf='nvim $(fzf)'
      alias cf='cd $(fd . --type d | fzf)'
    fi
  '';
}
