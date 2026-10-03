# Destnguyxn Personal Dotfiles

A place where I keep my configuration and dotfiles.

Check out to get the font at `355dcc691cab1ccf649593cb9a6167f1ee4dca4a`.

## Nix workstation configuration

The root `flake.nix` configures nix-darwin, Home Manager, and nix-homebrew for the Apple Silicon host `destngx-macbook-air` and user `destnguyxn`. Nix modules are kept under `nix/`; shell, Git, and tmux configuration remains in their existing repository directories.

### Install Nix

This workstation was checked for an existing `/nix` store, Nix daemon launch daemon, and Nix commands; none were found. The selected installer is Determinate Systems' installer. Its command installs Determinate Nix and may prompt for administrator authorization while making system-level changes. Review the installer documentation before proceeding.

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate
```

Open a new terminal after installation, then verify:

```sh
nix --version
nix flake --help
```

### Check and evaluate the configuration

The Nix toolchain has since been installed on this workstation. Initial `nix flake check` evaluation succeeded, with the Darwin system build intentionally skipped by the check. Follow-up evaluation exposed stale Homebrew options; these were updated to `homebrew.prefix = "/opt/homebrew"` and `homebrew.onActivation.autoUpdate = false`. The full Darwin and Home Manager derivation paths now evaluate. Re-run the checks below after pulling or changing configuration:

```sh
nix flake check --show-trace
nix eval --show-trace .#darwinConfigurations.destngx-macbook-air.system.build.toplevel.drvPath
nix eval --show-trace .#darwinConfigurations.destngx-macbook-air.config.home-manager.users.destnguyxn.home.activationPackage.drvPath
```

These commands evaluate derivations; they do not switch the system. Review evaluation output and Homebrew migration behavior before activation. `nix-homebrew.autoMigrate` is enabled, but migration has not been run. Homebrew cleanup, upgrades, and automatic updates are disabled. Do not run `darwin-rebuild switch` until you have reviewed the configuration and explicitly decided to activate it.

Machine-local Git include files are intentionally kept outside the repository. Do not put credentials or secret values in tracked files or Nix expressions.

Installer command and macOS installation guidance: Determinate Systems' official installer documentation.
