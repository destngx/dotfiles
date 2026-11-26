{ ... }:
let
  # Determinate Nix owns the nix install (base.nix sets nix.enable = false), so nix-darwin's nix.gc
  # is unavailable and there is no nix package in the config to point at. Use the binary the
  # Determinate installer puts in root's default profile.
  nixCollectGarbage = "/nix/var/nix/profiles/default/bin/nix-collect-garbage";
in
{
  # The same job nix.gc would set up: every Sunday at 03:00, delete generations older than 14 days
  # and collect the garbage.
  launchd.daemons.nix-gc.serviceConfig = {
    ProgramArguments = [ nixCollectGarbage "--delete-older-than" "14d" ];
    EnvironmentVariables.NIX_REMOTE = "daemon";
    RunAtLoad = false;
    StartCalendarInterval = [ { Weekday = 0; Hour = 3; Minute = 0; } ];
    StandardOutPath = "/var/log/nix-gc.log";
    StandardErrorPath = "/var/log/nix-gc.log";
  };

  # Determinate Nix runs its own collector by default; turn it off so the job above is the only one.
  environment.etc."determinate/config.json".text = builtins.toJSON {
    garbageCollector.strategy = "disabled";
  };
}
