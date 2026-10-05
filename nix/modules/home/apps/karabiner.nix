{ config, machine, ... }:
{
  home.activation.restartKarabiner = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    /bin/launchctl kickstart -k gui/$(/usr/bin/id -u)/org.pqrs.service.agent.Karabiner-Console-User-Server
  '';

  home.file.".config/karabiner".source =
    config.lib.file.mkOutOfStoreSymlink "${machine.repositoryDirectory}/karabiner";
}
