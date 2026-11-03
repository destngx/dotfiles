{ config, machine, ... }:
{
  # The sous engine itself is built and loaded from the monorepo checkout (`nx run sous:load-agent`),
  # so this module only links its machine config.
  home.file.".config/sous/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/sous/config.toml";
}
