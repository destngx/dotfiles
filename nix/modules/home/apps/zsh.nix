{ machine, pkgs, ... }:
{
  home.packages = [ pkgs.zsh ];

  programs.zsh.enable = false;

  home.file.".zshenv".text = ''
    export ZDOTDIR="${machine.repositoryDirectory}/zsh"
    source "$ZDOTDIR/.zshenv"
  '';
}
