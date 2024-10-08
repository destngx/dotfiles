# .zshenv is sourced on all invocations of the shell, unless the -f option is set.
# It should contain commands to set the command search path, plus other important environment variables.
# .zshenv' should not contain commands that produce output or assume the shell is attached to a tty.
export XDG_CONFIG_HOME="$HOME/.config"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Manage Node version and toolchain using Volta
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# Bun for JavaScript
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Install nvim using bob is recommend
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"

# User recommend bin folder
export PATH="$HOME/.local/bin:$PATH"

# MacOS PATH
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/Applications/IntelliJ IDEA.app/Contents/MacOS:$PATH"

# pnpm
export PNPM_HOME="/Users/destnguyxn/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

#
fpath=(
    $DOTFILES/config/zsh/functions
    /usr/local/share/zsh/site-functions
    $fpath
)

typeset -aU path


## User Environment Variables

export EDITOR=nvim
export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
export FZF_DEFAULT_OPTS='-i --height=50%'

export MANPATH=$HOME/tools/ripgrep/doc/man:$MANPATH
export FPATH=$HOME/tools/ripgrep/complete:$FPATH

export OPENAI_API_KEY=
export ANTHROPIC_API_KEY=
export COPILOT=true

export IS_WSL=false
