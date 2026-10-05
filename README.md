# Destnguyxn Personal Dotfiles

A place where I keep my configuration and dotfiles. This repository is powered by Nix: a flake defines the macOS workstation, Homebrew integration, user packages, and selected application and shell configuration. The repository remains the source of truth for managed files.

Check out to get the font at `355dcc691cab1ccf649593cb9a6167f1ee4dca4a`.

## Nix workstation setup

The root `flake.nix` configures nix-darwin, Home Manager, and nix-homebrew for the host and user defined in [`nix/hosts/destngx-macbook-air/machine.nix`](nix/hosts/destngx-macbook-air/machine.nix). The host entrypoint selects the Darwin system modules and Home Manager modules explicitly. To configure another Mac, add a host directory under `nix/hosts/` and wire its output in the flake. Application modules live under `nix/modules/`; macOS-specific modules are isolated under `darwin/`, while Home Manager modules are organized by application under `home/`. Other application configurations remain in their existing directories and are linked or referenced from those modules. For example, Home Manager links the entire `karabiner/` and `aerospace/` directories into `~/.config`; Karabiner's config is linked as a directory so it can monitor configuration changes.

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

Before evaluating or activating on a different Mac, edit `nix/hosts/destngx-macbook-air/machine.nix` to set its hostname, macOS username, home directory, repository checkout directory, and Nix system architecture. The `hostName` value is the flake configuration name; it does not have to match macOS's LocalHostName. Keep `repositoryDirectory` aligned with the actual checkout path because shell startup and application symlinks use it.

From the repository root, set shell variables for the configured host and user, then inspect and validate the configuration without applying it:

```sh
host=$(nix eval --impure --raw --expr '(import ./nix/hosts/destngx-macbook-air/machine.nix).hostName')
user=$(nix eval --impure --raw --expr '(import ./nix/hosts/destngx-macbook-air/machine.nix).username')
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

Activation applies system and user configuration. Review the Nix changes and their effects first, especially the nix-homebrew migration setting and any existing files that Home Manager will manage. Home Manager is configured to back up conflicting managed files with the `.hm-backup` extension. The Karabiner activation step restarts its user server after linking the config directory. During Homebrew activation, undeclared formulae and casks are removed, declared packages are upgraded, and automatic Homebrew updates are disabled.

When you have reviewed the configuration and are ready to apply it:

```sh
sudo nix run nix-darwin -- switch --flake ".#$host"
```

After making configuration changes, repeat the check and evaluation commands above before activating again.

### Helpful flake commands

```sh
# Update flake inputs and write the new revisions to flake.lock
nix flake update

# Update one input only
nix flake lock --update-input nixpkgs

# Evaluate the Home Manager activation package path
host=$(nix eval --impure --raw --expr '(import ./nix/hosts/destngx-macbook-air/machine.nix).hostName')
user=$(nix eval --impure --raw --expr '(import ./nix/hosts/destngx-macbook-air/machine.nix).username')
nix eval --raw ".#darwinConfigurations.$host.config.home-manager.users.$user.home.activationPackage.outPath"
```

Updating inputs changes `flake.lock`; review that diff before committing. A system switch applies the configuration and can also run configured Homebrew migration and activation actions.

Machine-local Git include files are intentionally kept outside the repository. Do not put credentials or secret values in tracked files or Nix expressions.

Installer command and macOS installation guidance: Determinate Systems' official installer documentation.
