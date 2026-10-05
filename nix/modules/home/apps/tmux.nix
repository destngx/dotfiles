{ ... }:
{
  programs.tmux.enable = false;

  home.file = {
    ".tmux.conf".source = ../../../../tmux/.tmux.conf;
    ".tmux.conf.local".source = ../../../../tmux/.tmux.conf.local;
  };
}
