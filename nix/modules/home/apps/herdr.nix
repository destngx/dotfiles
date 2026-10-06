{ config, inputs, machine, pkgs, ... }:
{
  home.packages = [ inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  home.file.".config/herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/herdr/config.toml";
}
