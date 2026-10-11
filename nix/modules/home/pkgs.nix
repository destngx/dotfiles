{ pkgs, machine, ... }:
{
  home.packages =
    map (name: pkgs.${name}) machine.packages
    ++ map (name: pkgs.unstable.${name}) machine.unstablePackages;
}
