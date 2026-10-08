{ config, machine, ... }:
{
  home.file.".config/mise".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/mise";
}
