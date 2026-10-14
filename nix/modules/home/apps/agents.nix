{ config, machine, ... }:
{
  home.file.".agents".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/agents";
}
