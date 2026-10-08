# Destnguyxn Personal Dotfiles

A place where I keep my configuration and dotfiles. This repository is powered by Nix: a flake defines the macOS workstation, Homebrew integration, user packages, and selected application and shell configuration. The repository remains the source of truth for managed files.

Check out to get the font at `355dcc691cab1ccf649593cb9a6167f1ee4dca4a`.

## Nix workstation setup

The `nix/` directory contains the host definitions and Nix modules. Review these activation considerations before applying the configuration:

- Homebrew's current inventory was captured from the workstation and may change. Compare it with `nix/modules/darwin/homebrew.nix` before activating.
- `nix-homebrew.autoMigrate` is enabled. Understand and review its effects before the first activation.
- Homebrew cleanup removes formulae and casks not declared in the configuration, upgrades declared packages during activation, and does not automatically update Homebrew.
- Machine-local Git include files remain outside this repository.
- Do not put credentials or secret values in tracked configuration files or Nix expressions.

The `hostName` value in each host's `machine.nix` is the flake configuration name; it does not have to match macOS's LocalHostName. Keep `repositoryDirectory` aligned with the actual checkout path because shell startup and application symlinks use it.

From the repository root, select a host directory when rebuilding, for example `bin/nix-rebuild nix/hosts/destngx-macbook-air switch`. To validate and evaluate without activating:

```sh
host_dir=nix/hosts/destngx-macbook-air
host=$(basename "$host_dir")
user=$(nix eval --impure --raw --expr '(import ./nix/hosts/'"$host"'/machine.nix).username')
nix flake show
nix flake check --show-trace
nix eval --show-trace ".#darwinConfigurations.$host.system.build.toplevel.drvPath"
nix eval --show-trace ".#darwinConfigurations.$host.config.home-manager.users.$user.home.activationPackage.drvPath"
```

`nix flake check` checks the flake outputs; to evaluate or build a specific host, use its host name as shown above. Evaluation and checks do not activate the configuration. Build it without switching:

```sh
nix build --no-link ".#darwinConfigurations.$host.system"
```

### 1. Install Nix

This workstation uses Determinate Nix. Installing Nix can make system-level changes and may prompt for administrator authorization. Review the installer and its documentation before proceeding:

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate
```

Open a new terminal after installation and verify the CLI is available:

```sh
nix --version
nix flake --help
```

### 2. Get the repository and inspect the flake

Before evaluating or activating, create a host directory under `nix/hosts/` with a `machine.nix` defining its hostname, macOS username, home directory, repository checkout directory, and Nix system architecture. The `hostName` value is the flake configuration name; it does not have to match macOS's LocalHostName. Keep `repositoryDirectory` aligned with the actual checkout path because shell startup and application symlinks use it.

From the repository root, set shell variables for the configured host and user, then inspect and validate the configuration without applying it:

```sh
host_dir=nix/hosts/destngx-macbook-air
host=$(basename "$host_dir")
user=$(nix eval --impure --raw --expr '(import ./nix/hosts/'"$host"'/machine.nix).username')
nix flake show
nix flake check --show-trace
nix eval --show-trace ".#darwinConfigurations.$host.system.build.toplevel.drvPath"
nix eval --show-trace ".#darwinConfigurations.$host.config.home-manager.users.$user.home.activationPackage.drvPath"
```

Evaluation and `nix flake check` do not activate the configuration. To build the system without switching to it:

```sh
nix build --no-link ".#darwinConfigurations.$host.system"
```

### 3. Activate when ready

On a fresh installation, `darwin-rebuild` may not yet be on your `PATH`. Bootstrap nix-darwin by running its rebuild command through `nix run`:

```sh
nix run 'nix-darwin#darwin-rebuild' -- switch \
  --flake ".#$host" \
  --sudo
```

After the first successful switch, `darwin-rebuild` should be available. For subsequent activations, use the repository CLI:

```sh
bin/nix-rebuild "$host_dir" switch
```

Activation applies system and user configuration. Review the Nix changes and their effects first, especially the nix-homebrew migration setting and any existing files that Home Manager will manage. Home Manager is configured to back up conflicting managed files with the `.hm-backup` extension. The Karabiner activation step restarts its user server after linking the config directory. During Homebrew activation, undeclared formulae and casks are removed, declared packages are upgraded, and automatic Homebrew updates are disabled.

After making configuration changes, repeat the check and evaluation commands above before activating again.

### 4. Helpful flake commands

```sh
# Update flake inputs and write the new revisions to flake.lock
nix flake update

# Update one input only
nix flake lock --update-input nixpkgs

host_dir=nix/hosts/destngx-macbook-air
host=$(basename "$host_dir")
user=$(nix eval --impure --raw --expr '(import ./nix/hosts/'"$host"'/machine.nix).username')
nix eval --raw ".#darwinConfigurations.$host.config.home-manager.users.$user.home.activationPackage.outPath"
```

Updating inputs changes `flake.lock`; review that diff before committing. A system switch applies the configuration and can also run configured Homebrew migration and activation actions.

Machine-local Git include files are intentionally kept outside the repository. Do not put credentials or secret values in tracked files or Nix expressions.

Installer command and macOS installation guidance: Determinate Systems' official installer documentation.
