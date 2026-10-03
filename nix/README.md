# macOS workstation Nix configuration

This repository contains a nix-darwin and Home Manager configuration for the host and user defined in [`machine.nix`](machine.nix). To set up another Mac, update the hostname, username, home directory, repository checkout path, and system architecture there. The `hostName` value is the flake attribute name and does not have to match macOS's LocalHostName. The flake entrypoint is `../flake.nix`; Darwin and Home Manager modules are in this directory.

## Review before activation

- Homebrew's current inventory was captured from the workstation and may change. Compare it with `darwin/homebrew.nix` before activating.
- `nix-homebrew.autoMigrate` is enabled. Understand and review its effects before the first activation.
- Homebrew cleanup, upgrades, and automatic updates are disabled in the configuration.
- Machine-local Git include files remain outside this repository.
- Do not put credentials or secret values in tracked configuration files or Nix expressions.

## Check, build, and activate

From the repository root, read the host and username configured in `nix/machine.nix`, then validate and evaluate without activating:

```sh
host=$(nix eval --raw --expr '(import ./nix/machine.nix).hostName')
user=$(nix eval --raw --expr '(import ./nix/machine.nix).username')
nix flake show
nix flake check --show-trace
nix eval --show-trace ".#darwinConfigurations.$host.system.build.toplevel.drvPath"
nix eval --show-trace ".#darwinConfigurations.$host.config.home-manager.users.$user.home.activationPackage.drvPath"
```

Evaluation and checks do not activate the configuration. Build it without switching:

```sh
nix build --no-link ".#darwinConfigurations.$host.system"
```

When ready to apply the configuration, review the changes and effects first, especially the nix-homebrew migration and files Home Manager will manage. Home Manager backs up conflicting managed files using the `.hm-backup` extension. The Karabiner activation step restarts its user server after linking the config directory. Activate explicitly with:

```sh
sudo nix run nix-darwin -- switch --flake ".#$host"
```

Updating inputs changes `flake.lock`; review that diff before committing:

```sh
nix flake update
nix flake lock --update-input nixpkgs
nix flake metadata
```
