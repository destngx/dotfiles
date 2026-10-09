{ machine, ... }:
{
  home.sessionVariables.EDITOR = "nvim";
  home.sessionPath = [ "${machine.homeDirectory}/.local/share/nvim/mason/bin" ];

  programs.zsh.shellAliases = {
    v = "nvim";
  };
}
