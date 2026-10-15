{ config, pkgs, ... }:
let
  threshold = 30;

  # Alerts once per connected Bluetooth accessory whose battery is below the threshold. An alert
  # re-arms when the device charges back above the threshold or disconnects, so reconnecting a
  # low device alerts again.
  script = pkgs.writeShellScript "bt-battery-alert" ''
    set -euo pipefail

    state_dir="${config.xdg.stateHome}/bt-battery-alert"
    mkdir -p "$state_dir"

    declare -A connected=()
    while IFS=$'\t' read -r id pct name; do
      connected[$id]=1
      marker="$state_dir/$id"
      if (( pct < ${toString threshold} )); then
        [[ -e "$marker" ]] && continue
        /opt/homebrew/bin/terminal-notifier \
          -title "Low Bluetooth battery" \
          -message "$name: $pct%" \
          -group "bt-battery-alert-$id" \
          -sound default
        touch "$marker"
      else
        rm -f "$marker"
      fi
    done < <(/usr/bin/pmset -g accps | ${pkgs.gnused}/bin/sed -nE \
      '/^ -InternalBattery/d; s/^ -(.+) \(id=([0-9]+)\)[[:space:]]+([0-9]+)%.*/\2\t\3\t\1/p')

    for marker in "$state_dir"/*; do
      [[ -e "$marker" ]] || continue
      [[ -n "''${connected[''${marker##*/}]:-}" ]] || rm -f "$marker"
    done
  '';
in
{
  launchd.agents.bt-battery-alert = {
    enable = true;
    config = {
      ProgramArguments = [ "${script}" ];
      RunAtLoad = true;
      StartInterval = 1800;
      ProcessType = "Background";
      StandardErrorPath = "${config.xdg.stateHome}/bt-battery-alert.log";
    };
  };
}
