{ config, machine, pkgs, ... }:
{
  home.packages = [ pkgs.wezterm ];
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/wezterm";
}
