{ config, machine, ... }:
let
  configDir = "${machine.repositoryDirectory}/claude";
in
{
  home.sessionVariables.CLAUDE_CONFIG_DIR = configDir;
  programs.zsh.shellAliases = {
    c = "claude";
    cc = "claude -c";
    cr = "claude -r";
  };

  # claude-quota (monorepo apps/claude-quota) switches the Claude Code login
  # between saved accounts before the active one runs out of quota. launchd
  # never sees home.sessionVariables, so the agent sets CLAUDE_CONFIG_DIR from
  # the same value; claude-quota refuses to run when the two differ.
  launchd.agents.claude-quota = {
    enable = true;
    config = {
      ProgramArguments = [
        "${machine.homeDirectory}/.local/bin/claude-quota"
        "service"
      ];
      EnvironmentVariables.CLAUDE_CONFIG_DIR = configDir;
      RunAtLoad = true;
      KeepAlive.SuccessfulExit = false;
      ThrottleInterval = 60;
      ProcessType = "Background";
      StandardOutPath = "${config.xdg.stateHome}/claude-quota.log";
      StandardErrorPath = "${config.xdg.stateHome}/claude-quota.log";
    };
  };
}
