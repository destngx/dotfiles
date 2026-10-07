{ lib, ... }:
{
  programs.zsh.shellAliases = {
    pn = "pnpm";
    px = "pnpx";
  };

  programs.zsh.initContent = lib.mkAfter ''
    npm() {
      case "$1" in
        install|i) pnpm install "''${@:2}" ;;
        add) pnpm add "''${@:2}" ;;
        uninstall|remove|r) pnpm remove "''${@:2}" ;;
        uninstall-global|remove-global|r-global) pnpm remove --global "''${@:2}" ;;
        run) pnpm run "''${@:2}" ;;
        *) echo "npm $@ → pnpm equivalent may vary"; command pnpm "$@" ;;
      esac
    }
    yarn() { case "$1" in install|i) pnpm install "''${@:2}" ;; add) pnpm add "''${@:2}" ;; remove|r|uninstall) pnpm remove "''${@:2}" ;; run) pnpm run "''${@:2}" ;; exec|x) pnpm dlx "''${@:2}" ;; list|ls) pnpm list "''${@:2}" ;; update|up) pnpm update "''${@:2}" ;; *) pnpm "$@" ;; esac }
  '';
}
