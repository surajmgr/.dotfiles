source /usr/share/cachyos-fish-config/cachyos-config.fish
source ~/.config/fish/functions/custom_alias.fish

# overwrite greeting
# potentially disabling fastfetch
function fish_greeting
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
