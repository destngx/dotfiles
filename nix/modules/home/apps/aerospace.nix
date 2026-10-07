{ config, machine, pkgs, ... }:
{
  home.activation.reloadAerospaceConfig = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    ${pkgs.aerospace}/bin/aerospace reload-config
  '';
  home.file.".config/aerospace".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/aerospace";
}
