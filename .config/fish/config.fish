# source /usr/share/cachyos-fish-config/cachyos-config.fish
source ~/.config/fish/functions/custom_alias.fish

# overwrite prompt
function fish_prompt
    echo (set_color $fish_color_cwd) (prompt_pwd) (set_color normal) '> '
end

# overwrite greeting
# potentially disabling fastfetch
function fish_greeting
  return
    set_color cyan
    for i in (seq (random 3 10))   # random number of fish between 3 and 10
        for j in (seq (random 1 40))   # random spacing before fish
            echo -n " "
        end
        echo "🐟"
    end
    set_color normal
end
nvm use 22.19.0 > /dev/null 2>&1

set -gx PATH $PATH ~/.local/share/gem/ruby/3.4.0/bin

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish

zoxide init fish --cmd cd | source
