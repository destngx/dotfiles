{ ... }:
{
  programs.tmux.enable = false;

  home.file = {
    ".tmux.conf".source = ../../../../tmux/.tmux.conf;
    ".tmux.conf.local".source = ../../../../tmux/.tmux.conf.local;
  };

  programs.zsh.shellAliases = {
    t = "tmux";
    ta = "tmux a -t";
    tls = "tmux ls";
    tn = "tmux new -t";
  };
}
