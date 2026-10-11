{ config, lib, machine, pkgs, ... }:
{
  home.file.".config/mise".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/mise";

  # Install the tools pinned in the global mise config, so a rebuild provisions them. Run from $HOME
  # so no project config is in scope. Already-installed versions are skipped. mise itself is
  # installed via machine.unstablePackages; this references the same store path.
  home.activation.installMiseTools = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    (cd "$HOME" && run ${pkgs.unstable.mise}/bin/mise install --yes) \
      || warnEcho "Failed to install mise tools; run 'mise install' from ~ to retry."
  '';

  programs.zsh.initContent = lib.mkOrder 1200 ''
    eval "$(mise activate zsh)"
  '';
}
