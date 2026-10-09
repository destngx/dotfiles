{ config, lib, machine, ... }:
{
  home.file.".config/mise".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/mise";

  programs.zsh.initContent = lib.mkOrder 1200 ''
    eval "$(mise activate zsh)"
  '';
}
