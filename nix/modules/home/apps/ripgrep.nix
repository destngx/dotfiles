{ machine, ... }:
{
  # fpath stays unexported: an exported FPATH leaks the parent shell's fpath (other zsh versions,
  # deferred plugin dirs) into child shells, which changes fpath and invalidates the compdump.
  programs.zsh.envExtra = ''
    fpath=(${machine.homeDirectory}/tools/ripgrep/complete $fpath)
    export MANPATH="${machine.homeDirectory}/tools/ripgrep/doc/man:$MANPATH"
  '';
}
