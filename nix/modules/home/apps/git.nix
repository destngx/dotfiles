{ ... }:
{
  programs.git.enable = false;
  home.file.".gitconfig".source = ../../../../git/.gitconfig;
}
