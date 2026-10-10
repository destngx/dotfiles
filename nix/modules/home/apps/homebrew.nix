{ machine, ... }:
{
  # Homebrew is declared in nix/hosts/<host>/machine.nix and applied by nix-darwin, which calls
  # brew by absolute path, so this wrapper only guards interactive use. Bypass: `command brew ...`.
  programs.zsh.initContent = ''
    brew() {
      case "$1" in
        install|reinstall|tap)
          if [[ "$1" != tap || $# -gt 1 ]]; then
            echo >&2 "brew $1 is disabled: Homebrew is managed by nix."
            echo >&2 "Add it to homebrew.{brews,casks,taps} in ${machine.repositoryDirectory}/nix/hosts/<host>/machine.nix and run darwin-rebuild."
            return 1
          fi
          ;;
      esac
      command brew "$@"
    }
  '';
}
