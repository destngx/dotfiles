# macOS workstation Nix configuration

This repository contains a nix-darwin and Home Manager configuration for the Apple Silicon host `destngx-macbook-air` and user `destnguyxn`.

The flake entrypoint is `flake.nix`; its Darwin and Home Manager modules are under `nix/`. Existing zsh, Git, and tmux configurations remain in their repository folders and are referenced by Home Manager.

## Review before activation

- Homebrew's current inventory was captured from the workstation and may change. Compare it with `nix/darwin/homebrew.nix` before activating.
- `nix-homebrew.autoMigrate` is enabled. Its migration has not been run; understand and review its effects before the first activation.
- Homebrew cleanup, upgrades, and automatic updates are disabled in the configuration.
- Machine-local Git include files remain outside this repository.
- Do not put credentials or secret values in tracked configuration files or Nix expressions.

## Validation and activation

Nix is not installed on the workstation at the time of this configuration pass, so `nix flake check` and Darwin evaluation have not been run. Install Nix only after deciding to proceed. Then, from the repository root, review the flake and evaluate/check it before any system switch. Do not run `darwin-rebuild switch` until you have reviewed the generated changes and explicitly decided to activate.
