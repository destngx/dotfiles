{ config, machine, lib, pkgs, ... }:
let
  antidotePlugins = [
    # Not deferred: it only extends fpath, which must happen before compinit.
    "zsh-users/zsh-completions"
    "agkozak/zsh-z kind:defer"
    "Aloxaf/fzf-tab kind:defer"
    "joshskidmore/zsh-fzf-history-search kind:defer"
    "grigorii-zander/zsh-npm-scripts-autocomplete kind:defer"
    "ohmyzsh/ohmyzsh path:plugins/aws kind:defer"
  ];
  antidoteBundleText = lib.concatLines antidotePlugins;
  antidoteBundle = pkgs.writeText "antidote-plugins.txt" antidoteBundleText;
  # home-manager's antidote module keeps the static file in /tmp, which macOS wipes on reboot,
  # forcing a regeneration on the next shell. Keep it in the cache dir, keyed by bundle content.
  antidoteCacheDir = "${config.xdg.cacheHome}/antidote";
  # `starship init zsh` only depends on the starship binary, so generate it at build time instead
  # of spawning starship on every shell start. It embeds the binary's store path, so it stays pinned.
  starshipInit = pkgs.runCommand "starship-init.zsh" { } ''
    HOME=$TMPDIR ${lib.getExe config.programs.starship.package} init zsh > $out
  '';
  antidoteStatic = "${antidoteCacheDir}/plugins-${builtins.substring 0 16 (builtins.hashString "sha256" antidoteBundleText)}.zsh";
in
{
  programs.starship = {
    enable = true;
    # Sourced from the build-time init script below instead.
    enableZshIntegration = false;
    # Replace default emoji symbols with Nerd Font glyphs (bundled in Ghostty), so the prompt
    # never pulls in the Apple Color Emoji font.
    presets = [ "nerd-font-symbols" ];
    settings = {
      git_status.ignore_submodules = true;
      # Default detect_files includes `project.json`, which every Nx project has.
      dotnet.detect_files = [
        "global.json"
        "Directory.Build.props"
        "Directory.Build.targets"
        "Packages.props"
      ];
    };
  };

  # Override per machine in nix/hosts/<host>/.env.
  secrets.fallbacks.OPENAI_ENV_BASE_URL = "http://localhost:8080/v1";

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = "${machine.repositoryDirectory}/zsh";
    sessionVariables = {
      XDG_CONFIG_HOME = "${machine.homeDirectory}/.config";
    };
    autosuggestion.enable = true;
    syntaxHighlighting = {
      enable = true;
      highlighters = [ "main" "brackets" ];
    };
    # A full compinit audits and rescans every fpath dir (~1s with a fresh dump, ~60ms otherwise).
    # Do that only when fpath changed (nix rebuild) or a completion dir gained entries (brew);
    # otherwise trust the dump. Activation below pre-warms it so rebuilds don't slow the next shell.
    # The dump is per zsh version: compinit discards a dump written by another version, so shells
    # of different versions (e.g. macOS /bin/zsh spawned by a long-running app) would keep
    # rebuilding a shared one.
    completionInit = ''
      autoload -U compinit
      () {
        local dump=$ZDOTDIR/.zcompdump-$ZSH_VERSION stamp=$ZDOTDIR/.zcompdump-$ZSH_VERSION.fpath dir fresh=0
        if [[ -s $dump && -r $stamp && "$(<$stamp)" == "$fpath" ]]; then
          fresh=1
          for dir in $fpath; do [[ $dir -nt $dump ]] && { fresh=0; break; }; done
        fi
        if (( fresh )); then
          compinit -C -d $dump
        else
          compinit -d $dump
          print -r -- "$fpath" >| $stamp
          zcompile $dump
        fi
      }
    '';
    autocd = true;
    defaultKeymap = "emacs";
    history = {
      size = 20000;
      path = "${machine.repositoryDirectory}/zsh/.zsh_history";
      ignoreAllDups = true;
    };
    historySubstringSearch.enable = true;
    shellAliases = {
      "nix-clean" = "nix-collect-garbage -d && nix-store --optimise";
      "..." = "cd ../../";
      "...." = "cd ../../../";
      redo = "sudo !!";
    };

    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        source ${pkgs.antidote}/share/antidote/antidote.zsh
        zstyle ':antidote:bundle' file ${antidoteBundle}
        zstyle ':antidote:static' file ${antidoteStatic}
        [[ -d ${antidoteCacheDir} ]] || mkdir -p ${antidoteCacheDir}
        antidote load ${antidoteBundle} ${antidoteStatic}
      '')

      ''
        if [[ $TERM != "dumb" ]]; then source ${starshipInit}; fi
      ''

      (lib.mkOrder 1200 ''
        bindkey -e
        WORDCHARS=''${WORDCHARS//[\/]}

        ls-port() { echo "User processes:"; lsof -nP -iTCP -sTCP:LISTEN; echo "System processes require sudo permission:"; sudo lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null || { echo "Error: Unable to list ports. Make sure you have permission."; return 1; } }
        is-port-available() { local port="$1"; if [[ -z "$port" ]]; then echo "Usage: is-port-open <port_number>"; return 1; fi; local result=$(lsof -nP -i:"$port" 2>/dev/null); if [[ -n "$result" ]]; then echo "Port $port is in use by:"; echo "$result" | awk 'NR>1 {print "- " $1 " (PID: " $2 ")"}'; else echo "Port $port is available for use"; fi }
        lich-am() { curl -s lich.day }
        lich-duong() { local today=$(date +%Y%m%d); curl -s lich.day/$today }
        confirm() { echo -n "$1 [y/N] -> "; read REPLY; case $REPLY in [Yy]) return 0 ;; *) return 1 ;; esac }
        rm() { if confirm "⚠️  DELETE: $*"; then /bin/rm "$@"; echo "✅ Deleted: $*"; else echo "❌ Aborted"; return 1; fi }
        pubkey() {
          local ssh_dir="$HOME/.ssh" selected_key
          if ! command -v fzf >/dev/null 2>&1; then echo "Error: fzf is not installed. Please install fzf for key selection."; return 1; fi
          if command -v fd >/dev/null 2>&1; then selected_key=$(fd -e pub . "$ssh_dir" --type f | fzf --prompt="Select SSH public key: " --height=40% --border); else selected_key=$(find "$ssh_dir" -maxdepth 1 -name "*.pub" -type f | fzf --prompt="Select SSH public key: " --height=40% --border); fi
          if [[ -z "$selected_key" ]]; then echo "No key selected."; return 1; fi
          if cat "$selected_key" | pbcopy; then echo "=> Public key '$(basename "$selected_key")' copied to pasteboard."; else echo "Error: Failed to copy key to clipboard."; return 1; fi
        }
      '')
    ];
  };

  home.packages = [ pkgs.antidote ];

  # Pay cache rebuilds (compdump, antidote static file) during activation instead of in the first
  # shell after a rebuild: drop stale caches, then start one clean interactive shell.
  home.activation.warmZshCaches = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # Unversioned dump from before compdumps were keyed by zsh version.
    run rm -f ${config.programs.zsh.dotDir}/.zcompdump ${config.programs.zsh.dotDir}/.zcompdump.zwc ${config.programs.zsh.dotDir}/.zcompdump.fpath
    for f in ${antidoteCacheDir}/plugins-*.zsh; do
      if [[ -e $f && $f != ${antidoteStatic} ]]; then run rm -f "$f"; fi
    done
    run env -i HOME="$HOME" USER="$USER" TERM=dumb PATH=/usr/bin:/bin \
      ${config.programs.zsh.package}/bin/zsh -ic exit </dev/null >/dev/null \
      || warnEcho "Failed to pre-warm zsh caches; the next shell will rebuild them."
  '';

  home.sessionPath = [
    "/usr/local/bin"
    "${machine.homeDirectory}/.local/bin"
    "${machine.homeDirectory}/.antigravity/antigravity/bin"
    "/Applications/Obsidian.app/Contents/MacOS"
  ];
}
