{ config, inputs, machine, pkgs, ... }:
let
  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home.packages = [
    herdr
    # Install the completion into fpath at build time; compinit autoloads it on first use instead of
    # every shell spawning `herdr completion zsh`.
    (pkgs.runCommand "herdr-zsh-completion" { } ''
      mkdir -p $out/share/zsh/site-functions
      HOME=$TMPDIR ${herdr}/bin/herdr completion zsh > $out/share/zsh/site-functions/_herdr
    '')
  ];

  home.activation.reloadHerdrConfig = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    ${herdr}/bin/herdr config check && ${herdr}/bin/herdr server reload-config
  '';

  home.file.".config/herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/herdr/config.toml";

  programs.zsh.shellAliases.herdr = "command herdr";
}
