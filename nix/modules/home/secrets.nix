{ config, lib, machine, ... }:
let
  cfg = config.secrets;
in
{
  options.secrets = {
    envFile = lib.mkOption {
      type = lib.types.str;
      default = "${machine.repositoryDirectory}/nix/hosts/${machine.hostName}/.env";
      description = ''
        Gitignored zsh file sourced (with `set -a`, so plain `KEY=value` lines are exported) from
        .zshenv at shell startup. Read at runtime, so its contents never land in the Nix store.
      '';
    };

    fallbacks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = { OPENAI_BASE_URL = "http://localhost:8080/v1"; };
      description = ''
        Non-secret defaults exported when a variable is still unset or empty after loading
        `envFile`. These end up in the Nix store, so never put real secrets here.
      '';
    };
  };

  config.programs.zsh.envExtra = ''
    if [[ -f ${lib.escapeShellArg cfg.envFile} ]]; then
      __secrets_file=${lib.escapeShellArg cfg.envFile}
      __secrets_open=($__secrets_file(NA,R))
      (( ''${#__secrets_open} )) && print -u2 "warning: $__secrets_file is readable by others; run: chmod 600 $__secrets_file"
      set -a
      source "$__secrets_file"
      set +a
      unset __secrets_file __secrets_open
    fi
  '' + lib.concatStrings (lib.mapAttrsToList (name: value: ''
    : ''${${name}:=${lib.escapeShellArg value}}; export ${name}
  '') cfg.fallbacks);
}
