{ lib, machine, osConfig, ... }:
let
  prefix = osConfig.homebrew.prefix;
in
{
  # Static equivalent of `brew shellenv`, so shells don't spawn brew on startup.
  home.sessionVariables = {
    HOMEBREW_PREFIX = prefix;
    HOMEBREW_CELLAR = "${prefix}/Cellar";
  };
  home.sessionPath = [
    "${prefix}/bin"
    "${prefix}/sbin"
  ];
  home.sessionSearchVariables.INFOPATH = [ "${prefix}/share/info" ];

  # Must precede compinit (order 570) so brew-installed completions get registered.
  programs.zsh.initContent = lib.mkMerge [
    (lib.mkOrder 560 ''
      fpath=(${prefix}/share/zsh/site-functions $fpath)
    '')

    # Homebrew is declared in nix/hosts/<host>/machine.nix and applied by nix-darwin, which calls
    # brew by absolute path, so this wrapper only guards interactive use. Bypass: `command brew ...`.
    ''
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
    ''
  ];
}
