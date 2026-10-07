{ config, inputs, lib, machine, pkgs, ... }:
let
  unstable-pkgs = import inputs.nixpkgs-unstable { system = pkgs.stdenv.hostPlatform.system; };
in
{
  config = {
    # TODO: Remove this once the stable version of home-manager has the pi-coding-agent package, which > 26.05
    home.sessionVariables.PI_CODING_AGENT_DIR = "${machine.repositoryDirectory}/pi/agent";

    # TODO: activate the pi-coding-agent once it is available in the stable version of home-manager, which > 26.05
    # programs.pi-coding-agent = {
    #   enable = true;
    #   configDir = "${machine.repositoryDirectory}/pi/agent";
    # };
    home.packages = [ unstable-pkgs.pi-coding-agent ];
  };
}
