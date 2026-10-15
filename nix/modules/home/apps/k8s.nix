{ lib, pkgs, ... }:
let
  # kubectl itself comes from Docker Desktop (/usr/local/bin), which ships no zsh completion.
  # Generate it at build time; the output holds only the script, so nixpkgs' kubectl stays off PATH.
  # It lands in the profile's site-functions dir, which is already on fpath before compinit.
  kubectlZshCompletion = pkgs.runCommand "kubectl-zsh-completion" { } ''
    mkdir -p $out/share/zsh/site-functions
    HOME=$TMPDIR ${lib.getExe pkgs.kubectl} completion zsh > $out/share/zsh/site-functions/_kubectl
  '';
in
{
  home.packages = [ kubectlZshCompletion ];

  programs.zsh.shellAliases = {
    k = "kubectl";
  };
}
