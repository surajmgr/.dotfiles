#!/bin/bash

# ------------------------
# Modifier mappings
# ------------------------
declare -A MOD_MAP=(
    ["Mod1"]="Alt"
    ["Mod4"]="Super"
    ["Shift"]="Shift"
    ["Control"]="Ctrl"
    ["LEFTALT"]="Alt"
    ["LEFTMETA"]="Super"
    ["LEFTSHIFT"]="Shift"
    ["LEFTCTRL"]="Ctrl"
)

# Pretty-print modifiers
pretty_keys() {
    local combo="$1"
    IFS='+' read -ra parts <<< "$combo"
    for i in "${!parts[@]}"; do
        [[ -n "${MOD_MAP[${parts[i]}]}" ]] && parts[i]=${MOD_MAP[${parts[i]}]}
    done
    echo "${parts[*]}" | sed 's/ /+/g'
}

# ------------------------
# Parse i3 bindsym
# ------------------------
parse_i3() {
    echo "<b>Keyboard Shortcuts (i3):</b>"
    declare -A seen
    grep -e '^[^#]*bindsym' ~/.config/i3/config | while read -r line; do
        key=$(echo "$line" | awk '{print $2}')
        action=$(echo "$line" | cut -d' ' -f3-)
        # Extract friendly name from comment
        name=$(echo "$line" | grep -oP '#\s*n:\s*\K.*')
        [[ -z "$name" ]] && name="$action"
        # Skip duplicates
        [[ -n "${seen[$key]}" ]] && continue
        seen[$key]=1
        echo "$(pretty_keys "$key"): $name"
    done
    echo ""
}

# ------------------------
# Parse Fusuma gestures
# ------------------------
parse_fusuma() {
    local file="$1"
    echo "<b>Touch Gestures (Fusuma):</b>"

    for fingers in 3 4; do
        gestures=$(yq ".swipe.\"$fingers\" // {}" "$file")
        [[ "$gestures" == "{}" ]] && gestures=$(yq ".pinch.\"$fingers\" // {}" "$file")
        [[ "$gestures" == "{}" ]] && continue
        echo "<b>--- Swipe/Pinch ($fingers fingers) ---</b>"

        for dir in left right up down in out; do
            cmd=$(echo "$gestures" | yq ".\"$dir\".command // empty")
            keypresses=$(echo "$gestures" | yq ".\"$dir\".keypress // {}")

            # Main gesture command
            if [[ -n "$cmd" ]]; then
                name=$(grep -Po '#\s*n:\s*\K.*' <<< "$cmd")
                [[ -z "$name" ]] && name="$cmd"
                echo "$dir: $name"
            fi

            # Keypress variants
            if [[ "$keypresses" != "{}" ]]; then
                keys=$(echo "$keypresses" | yq 'keys | .[]')
                for k in $keys; do
                    # Wrap key in quotes for yq
                    k_escaped="\"$k\""
                    k_clean=$(pretty_keys "$k")
                    subcmd=$(echo "$keypresses" | yq ".[$k_escaped].command")
                    subname=$(grep -Po '#\s*n:\s*\K.*' <<< "$subcmd")
                    [[ -z "$subname" ]] && subname="$subcmd"
                    echo "$dir + $k_clean: $subname"
                done
            fi

        done
    done
    echo ""
}

# ------------------------
# Run parsers
# ------------------------
parse_i3
parse_fusuma ~/.config/fusuma/config.yml
