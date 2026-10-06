{ config, machine, pkgs, ... }:
{
  home.packages = [ pkgs.ghostty-bin ];
  home.file.".config/ghostty".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/ghostty";
}
