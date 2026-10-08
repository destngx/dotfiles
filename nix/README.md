# macOS workstation Nix configuration

This repository contains a nix-darwin and Home Manager configuration for the hosts defined under [`hosts/`](hosts/). Each host has its own `machine.nix` and entrypoints; Nix modules live under `modules/`, organized by platform and application. The flake entrypoint is `../flake.nix`.

## Review before activation

- Homebrew's current inventory was captured from the workstation and may change. Compare it with `modules/darwin/homebrew.nix` before activating.
- `nix-homebrew.autoMigrate` is enabled. Understand and review its effects before the first activation.
- Homebrew cleanup removes formulae and casks not declared in the configuration, upgrades declared packages during activation, and does not automatically update Homebrew.
- Machine-local Git include files remain outside this repository.
- Do not put credentials or secret values in tracked configuration files or Nix expressions.

## Check, build, and activate

From the repository root, select a host directory when rebuilding, for example `bin/nix-rebuild nix/hosts/destngx-macbook-air switch`. To validate and evaluate without activating:

```sh
host_dir=nix/hosts/destngx-macbook-air
host=$(basename "$host_dir")
user=$(nix eval --raw --expr '(import ./nix/hosts/'"$host"'/machine.nix).username')
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
bin/nix-rebuild "$host_dir" switch
```

Updating inputs changes `flake.lock`; review that diff before committing:

```sh
nix flake update
nix flake lock --update-input nixpkgs
nix flake metadata
```
