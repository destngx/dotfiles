{ config, lib, machine, pkgs, ... }:
let
  # Unstable: pnpm 12 global installs (npm.package_manager = "pnpm") need mise >= 2026.9.2.
  mise = pkgs.unstable.mise;
in
{
  home.packages = [ mise ];

  home.file.".config/mise".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/mise";

  # Install the tools pinned in the global mise config, so a rebuild provisions them. Run from $HOME
  # so no project config is in scope. Already-installed versions are skipped.
  home.activation.installMiseTools = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    (cd "$HOME" && run ${mise}/bin/mise install --yes) \
      || warnEcho "Failed to install mise tools; run 'mise install' from ~ to retry."
  '';

  programs.zsh.initContent = lib.mkOrder 1200 ''
    eval "$(mise activate zsh)"
  '';
}
