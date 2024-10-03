# -----------------
# User configuration
# -----------------


DYLD_LIBRARY_PATH="$(brew --prefix)/lib" 
export DYLD_LIBRARY_PATH="$(brew --prefix)/lib:$DYLD_LIBRARY_PATH"


[ -f $XDG_CONFIG_HOME/zsh/.zshrc ] && source $XDG_CONFIG_HOME/zsh/.zshrc
