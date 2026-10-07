{ machine, pkgs, lib, ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = "${machine.repositoryDirectory}/zsh";
    envExtra = ''
      export FPATH="${machine.homeDirectory}/tools/ripgrep/complete:$FPATH"
      export MANPATH="${machine.homeDirectory}/tools/ripgrep/doc/man:$MANPATH"
    '';
    sessionVariables = {
      VOLTA_HOME = "${machine.homeDirectory}/.volta";
      PNPM_HOME = "${machine.homeDirectory}/.local/share/pnpm";
      XDG_CONFIG_HOME = "${machine.homeDirectory}/.config";
      EDITOR = "nvim";
      FZF_DEFAULT_COMMAND = "rg --files --hidden --glob '!.git'";
      FZF_DEFAULT_OPTS = "-i --height=50%";
      OPENAI_ENV_BASE_URL = "http://ezmacmini:8080/v1";
    };
    autosuggestion.enable = true;
    syntaxHighlighting = {
      enable = true;
      highlighters = [ "main" "brackets" ];
    };
    antidote = {
      enable = true;
      plugins = [
        "zsh-users/zsh-completions kind:defer"
        "agkozak/zsh-z kind:defer"
        "Aloxaf/fzf-tab kind:defer"
        "joshskidmore/zsh-fzf-history-search kind:defer"
        "grigorii-zander/zsh-npm-scripts-autocomplete kind:defer"
        "ohmyzsh/ohmyzsh path:plugins/aws kind:defer"
      ];
    };
    autocd = true;
    defaultKeymap = "emacs";
    history = {
      size = 20000;
      path = "${machine.repositoryDirectory}/zsh/.zsh_history";
      ignoreAllDups = true;
    };
    historySubstringSearch.enable = true;
    shellAliases = {
      v = "nvim";
      "nix-clean" = "nix-collect-garbage -d && nix-store --optimise";
      "nix-switch" = "sudo darwin-rebuild switch --flake '.#destngx-macbook-air'";
      p = "pi";
      pr = "pi -r";
      "..." = "cd ../../";
      "...." = "cd ../../../";
      redo = "sudo !!";
      herdr = "command herdr";
    };

    initContent = lib.mkOrder 1200 ''
      bindkey -e
      WORDCHARS=''${WORDCHARS//[\/]}

      if command -v fzf >/dev/null 2>&1; then
        alias vf='nvim $(fzf)'
        alias cf='cd $(fd . --type d | fzf)'
      fi

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

      if command -v herdr >/dev/null 2>&1; then source <(herdr completion zsh); fi
    '';
  };

  home.sessionPath = [
    "/opt/homebrew/bin"
    "/usr/local/bin"
    "${machine.homeDirectory}/.local/share/nvim/mason/bin"
    "${machine.homeDirectory}/.local/bin"
    "${machine.homeDirectory}/.lmstudio/bin"
    "${machine.homeDirectory}/.antigravity/antigravity/bin"
    "${machine.homeDirectory}/.volta/bin"
    "${machine.homeDirectory}/.local/share/pnpm"
    "/Applications/Obsidian.app/Contents/MacOS"
  ];
}
