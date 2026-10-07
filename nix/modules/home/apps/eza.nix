{ ... }:
{
  programs.zsh.shellAliases = {
    l = "eza --";
    ls = "eza --group-directories-first --icons=auto";
    ll = "eza -al --git --group-directories-first --icons=auto";
    la = "eza -la --icons=auto --";
    lt = "ls --tree --level=3 --";
    tree = "eza --tree --icons --git-ignore --";
  };
}
