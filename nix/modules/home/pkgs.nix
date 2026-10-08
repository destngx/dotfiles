{ pkgs, machine, ... }:
{
  home.packages = map (name: pkgs.${name}) machine.packages;
}
