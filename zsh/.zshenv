# This file is sourced by zsh on every invocation. Keep it quiet and put only
# environment setup here.
export XDG_CONFIG_HOME="$HOME/.config"

export VOLTA_HOME="$HOME/.volta"
export PNPM_HOME="$HOME/.local/share/pnpm"

export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.lmstudio/bin:$HOME/.antigravity/antigravity/bin:$VOLTA_HOME/bin:$BUN_INSTALL/bin:$PNPM_HOME:$PATH"
export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"

if [[ -d /opt/homebrew/bin ]]; then
  export PATH="/opt/homebrew/bin:$PATH"
elif [[ -d /usr/local/bin ]]; then
  export PATH="/usr/local/bin:$PATH"
fi

if command -v brew >/dev/null 2>&1; then
  export DYLD_LIBRARY_PATH="$(brew --prefix)/lib:$DYLD_LIBRARY_PATH"
  export DYLD_FALLBACK_LIBRARY_PATH="$(brew --prefix)/lib:$DYLD_FALLBACK_LIBRARY_PATH"
fi

export EDITOR=nvim
export MANPATH="$HOME/tools/ripgrep/doc/man:$MANPATH"
export FPATH="$HOME/tools/ripgrep/complete:$FPATH"
export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
export FZF_DEFAULT_OPTS='-i --height=50%'
export ANTHROPIC_BASE_URL="http://ezmacmini:8080"
export OPENAI_ENV_BASE_URL="http://ezmacmini:8080/v1"
export COPILOT=true
export IS_WSL=false
