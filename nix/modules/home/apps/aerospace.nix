{ config, machine, pkgs, ... }:
{
  home.packages = [ pkgs.aerospace ];
  home.file.".config/aerospace".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/aerospace";
}
