{ lib, pkgs, config, ... }:
{
  programs.git.enable = false;
  home.file.".gitconfig".source = ../../../../git/.gitconfig;

  # `gwf` as an executable for agents and scripts, whose shells do not load the zsh function. Command
  # output goes to stderr; `create` prints the worktree path on stdout so callers can
  # `cd "$(gwf create <branch>)"`. Without a terminal, commands that would prompt fail with a hint
  # (`rm -y`, `gc -y` are the prompt-free forms) and untrusted .gwf/setup scripts are skipped.
  # Interactive shells keep using the function defined below.
  home.packages = [
    (pkgs.writeScriptBin "gwf" ''
      #!${config.programs.zsh.package}/bin/zsh
      ${builtins.readFile ../../../../git/worktree.zsh}
      gwf "$@" >&2 || exit
      [[ $1 == (create|c) ]] && print -r -- "$PWD"
      exit 0
    '')
  ];

  programs.zsh.shellAliases = {
    g = "git";
    gd = "git d";
    gst = "git st";
    gpl = "git pl";
    gps = "git pl && git ps";
    ghist = "git hist";
    gca = "git ca";
    gci = "git ci";
  };

  programs.zsh.initContent = lib.mkAfter ''
    git() { if [[ $# -gt 0 ]]; then command git "$@"; else command git status -sb; fi }

    ${builtins.readFile ../../../../git/worktree.zsh}
  '';
}
