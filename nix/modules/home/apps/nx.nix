{ lib, ... }:
{
  # `nx` runs the workspace's pinned Nx; its completion reads the project graph Nx caches.
  programs.zsh.initContent = lib.mkAfter ''
    ${builtins.readFile ../../../../nx/nx.zsh}
  '';
}
