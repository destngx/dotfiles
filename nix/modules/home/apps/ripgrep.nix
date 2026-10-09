{ machine, ... }:
{
  programs.zsh.envExtra = ''
    export FPATH="${machine.homeDirectory}/tools/ripgrep/complete:$FPATH"
    export MANPATH="${machine.homeDirectory}/tools/ripgrep/doc/man:$MANPATH"
  '';
}
