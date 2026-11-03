{ ... }:
{
  # The sous engine itself is built and loaded from the monorepo checkout (`nx run sous:load-agent`),
  # so this module only installs its machine config. The file is copied into the Nix store, so it is
  # read-only and changes only with a rebuild (SO-OPS-1: agents never edit it).
  home.file.".config/sous/config.toml".source = ../../../../sous/config.toml;
}
