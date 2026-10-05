{ inputs, pkgs, ... }:
let
  unstable-pkgs = import inputs.nixpkgs-unstable { system = pkgs.system; };
in
{
  home.packages = [ unstable-pkgs.pi-coding-agent ];
}
