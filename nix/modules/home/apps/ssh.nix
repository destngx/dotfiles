{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."github.com" = {
      IdentityFile = "~/.ssh/id_rsa";
      AddKeysToAgent = "yes";
      UseKeychain = "yes";
    };
  };

  # The agent starts empty after every login; load the Keychain-stored keys into it.
  launchd.agents.ssh-add-keychain = {
    enable = true;
    config = {
      ProgramArguments = [ "/usr/bin/ssh-add" "--apple-load-keychain" ];
      RunAtLoad = true;
      ProcessType = "Background";
    };
  };
}
