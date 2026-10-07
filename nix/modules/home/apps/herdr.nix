{ config, inputs, machine, pkgs, ... }:
{
  home.packages = [ inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  home.activation.reloadHerdrConfig = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    ${inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/herdr config check && ${inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/herdr server reload-config
  '';

  home.file.".config/herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/herdr/config.toml";
}
