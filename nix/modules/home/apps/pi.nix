{ machine, ... }:
{
  config = {
    # TODO: Remove this once the stable version of home-manager has the pi-coding-agent package, which > 26.05
    home.sessionVariables.PI_CODING_AGENT_DIR = "${machine.repositoryDirectory}/pi/agent";

    # TODO: activate the pi-coding-agent once it is available in the stable version of home-manager, which > 26.05
    # programs.pi-coding-agent = {
    #   enable = true;
    #   configDir = "${machine.repositoryDirectory}/pi/agent";
    # };

    programs.zsh.shellAliases = {
      p = "pi";
      pr = "pi -r";
    };
  };
}
