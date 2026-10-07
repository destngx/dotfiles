{ config, machine, ... }:
{
  home.file.".config/peco/config.json".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/peco/config.json";
}
