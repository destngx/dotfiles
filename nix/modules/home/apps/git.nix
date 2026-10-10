{ lib, ... }:
{
  programs.git.enable = false;
  home.file.".gitconfig".source = ../../../../git/.gitconfig;

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
