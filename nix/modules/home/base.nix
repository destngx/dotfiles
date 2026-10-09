{ machine, ... }:
{
  home.username = machine.username;
  home.homeDirectory = machine.homeDirectory;
  home.stateVersion = "26.05";

  xdg.enable = true;

  # The home-configuration.nix manpage builds options.json via nixpkgs make-options-doc, which
  # strips string context and makes newer Nix warn "derivation ... without a proper context".
  manual.manpages.enable = false;
}
