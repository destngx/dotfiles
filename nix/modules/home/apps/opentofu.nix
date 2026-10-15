{ config, lib, machine, ... }:
{
  home.file.".tofurc".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/opentofu/.tofurc";

  # OpenTofu does not create the cache directory itself and skips caching when it is missing.
  home.activation.createTofuPluginCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.terraform.d/plugin-cache"
  '';
}
