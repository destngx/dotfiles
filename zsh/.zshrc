# -----------------
# This is local zshrc file
# User configuration
# -----------------

if [[ -n "$(command -v brew)" ]]; then
  DYLD_LIBRARY_PATH="$(brew --prefix)/lib" 
  export DYLD_LIBRARY_PATH="$(brew --prefix)/lib:$DYLD_LIBRARY_PATH"
fi



# look for all .zsh files and source them
for file in "$ZDOTDIR/.zsh_functions" "$ZDOTDIR/.zsh_aliases" "$ZDOTDIR/.zsh_completions"; do
    if [ -f $file ]; then
        source $file
    fi
done


# Add this line to your ~/.zshrc file
# [ -f $XDG_CONFIG_HOME/zsh/.zshrc ] && source $XDG_CONFIG_HOME/zsh/.zshrc
