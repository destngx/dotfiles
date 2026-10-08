{ config, machine, ... }:
{
  home.file.".config/peco".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/peco";
}
