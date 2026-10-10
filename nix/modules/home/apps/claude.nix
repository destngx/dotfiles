{ machine, ... }:
{
  home.sessionVariables.CLAUDE_CONFIG_DIR = "${machine.repositoryDirectory}/claude";
  programs.zsh.shellAliases = {
    c = "claude";
    cc = "claude -c";
    cr = "claude -r";
  };
}
