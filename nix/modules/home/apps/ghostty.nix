{ config, machine, ... }:
{
  home.file.".config/ghostty".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/ghostty";
}
