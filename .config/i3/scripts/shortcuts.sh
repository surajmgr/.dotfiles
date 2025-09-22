#!/bin/bash
# ------------------------
# Enhanced Rofi Shortcuts Viewer with Proper Tabs
# ------------------------
# Modifier mappings for pretty display
declare -A MOD_MAP=(
    ["Mod1"]="Alt"
    ["Mod4"]="Super"
    ["Shift"]="Shift"
    ["Control"]="Ctrl"
    ["ctrl"]="Ctrl"
    ["\$mod"]="Super"
    ["\$modsec"]="Alt"
    ["XF86PowerOff"]="⏻"
    ["XF86AudioRaiseVolume"]="VolUp"
    ["XF86AudioLowerVolume"]="VolDown"
    ["XF86AudioMute"]="Mute"
    ["XF86MonBrightnessUp"]="BrightnessUp"
    ["XF86MonBrightnessDown"]="BrightnessDown"
)
# Pretty-print key combinations
pretty_keys() {
    local combo="$1"
   
    # Handle special function keys first
    if [[ "$combo" =~ XF86 ]]; then
        for key in "${!MOD_MAP[@]}"; do
            if [[ "$combo" == "$key" ]]; then
                echo "${MOD_MAP[$key]}"
                return
            fi
        done
    fi
   
    # Split by + and process each part
    IFS='+' read -ra parts <<< "$combo"
    local formatted_parts=()
   
    for part in "${parts[@]}"; do
        if [[ -n "${MOD_MAP[$part]}" ]]; then
            formatted_parts+=("${MOD_MAP[$part]}")
        else
            # Handle special key names
            case "$part" in
                "Return") formatted_parts+=("⏎") ;;
                "space") formatted_parts+=("Space") ;;
                "Tab") formatted_parts+=("⇥") ;;
                "Escape") formatted_parts+=("Esc") ;;
                "BackSpace") formatted_parts+=("⌫") ;;
                "Delete") formatted_parts+=("Del") ;;
                "Left") formatted_parts+=("←") ;;
                "Right") formatted_parts+=("→") ;;
                "Up") formatted_parts+=("↑") ;;
                "Down") formatted_parts+=("↓") ;;
                *) formatted_parts+=("$part") ;;
            esac
        fi
    done
   
    # Join with +
    IFS='+'; echo "${formatted_parts[*]}"
}
# Parse i3 configuration with proper description parsing
parse_i3_shortcuts() {
    declare -A shortcuts
    local prev_line=""
    # Debug: Print Bash version
    # echo "Debug: Bash version: $BASH_VERSION" >&2
    while IFS= read -r line; do
        # Remove carriage returns and trim whitespace
        line=$(echo "$line" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        # Debug: Print current line
        # echo "Debug: Processing line: '$line'" >&2
        # Skip empty lines
        [[ -z "$line" ]] && { prev_line="$line"; continue; }
        # Check for custom command format: # c_c: someCommand; commandDescription
        if [[ "$prev_line" =~ ^#[[:space:]]*c_c:[[:space:]]*([^[:space:]]+)[[:space:]]*\;[[:space:]]*(.*)$ ]]; then
            custom_command="${BASH_REMATCH[1]}"
            desc="${BASH_REMATCH[2]}"
            # echo "Debug: c_c match - command: '$custom_command', desc: '$desc'" >&2
            # Check if current line is a bindsym
            if [[ "$line" =~ ^bindsym[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
                bind_key="${BASH_REMATCH[1]}"
                # echo "Debug: bindsym match - key: '$bind_key'" >&2
                # Use custom_command as key and description from c_c
                if [[ -n "$desc" && -n "$custom_command" && -z "${shortcuts[$custom_command]}" ]]; then
                    shortcuts["$custom_command"]="$desc"
                fi
            fi
        # Check for regular comment format (no c_c:)
        elif [[ "$prev_line" =~ ^#[[:space:]]*(.+)$ ]]; then
            desc="${BASH_REMATCH[1]}"
            # echo "Debug: regular comment match - desc: '$desc'" >&2
            if [[ "$line" =~ ^bindsym[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
                bind_key="${BASH_REMATCH[1]}"
                # echo "Debug: bindsym match - key: '$bind_key'" >&2
                # Use bind_key as key and comment as description
                if [[ -n "$desc" && -n "$bind_key" && -z "${shortcuts[$bind_key]}" ]]; then
                    shortcuts["$bind_key"]="$desc"
                fi
            fi
        fi
        prev_line="$line"
    done < ~/.config/i3/config
    # Output formatted shortcuts
    for key in "${!shortcuts[@]}"; do
        local formatted_key
        formatted_key=$(pretty_keys "$key" 2>/dev/null || echo "$key")
        echo "⌨️ $formatted_key → ${shortcuts[$key]}"
    done
}
# Handle -s flag
if [[ "$1" == "-s" ]]; then
    parse_i3_shortcuts
fi
# Parse Fusuma gestures
parse_fusuma_shortcuts() {
    local file="$1"
    [[ ! -f "$file" ]] && return
   
    # Extract lines between ###START### and ###END###
    awk '/###START###/{flag=1;next}/###END###/{flag=0}flag' "$file" | while read -r line; do
        if [[ "$line" =~ ^#\ ([^:]+):\ (.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            desc="${BASH_REMATCH[2]}"
            local formatted_key=$(pretty_keys "$key")
            echo "👆 $formatted_key → $desc"
        fi
    done
}
# Rofi theme with proper tabs (mode-switcher)
get_rofi_theme() {
    cat << 'EOF'
* {
    border-colour: #89b4fa;
    handle-colour: #89b4fa;
    background-colour: rgba(30, 30, 46, 0.95);
    foreground-colour: #cdd6f4;
    alternate-background: rgba(49, 50, 68, 0.8);
    normal-background: transparent;
    normal-foreground: #cdd6f4;
    urgent-background: #f38ba8;
    urgent-foreground: #1e1e2e;
    active-background: #a6e3a1;
    active-foreground: #1e1e2e;
    selected-normal-background: rgba(137, 180, 250, 0.2);
    selected-normal-foreground: #89b4fa;
    selected-urgent-background: #f38ba8;
    selected-urgent-foreground: #1e1e2e;
    selected-active-background: #a6e3a1;
    selected-active-foreground: #1e1e2e;
    alternate-normal-background: rgba(69, 71, 90, 0.3);
    alternate-normal-foreground: #cdd6f4;
    alternate-urgent-background: #f38ba8;
    alternate-urgent-foreground: #1e1e2e;
    alternate-active-background: #a6e3a1;
    alternate-active-foreground: #1e1e2e;
}
window {
    transparency: "real";
    location: center;
    anchor: center;
    fullscreen: true;
    width: 1000px;
    x-offset: 0px;
    y-offset: 0px;
    enabled: true;
    margin: 0px;
    padding: 0px;
    border: 2px solid;
    border-radius: 16px;
    border-color: @border-colour;
    cursor: "default";
    background-color: @background-colour;
}
mainbox {
    enabled: true;
    spacing: 15px;
    margin: 0px;
    padding: 25px;
    border: 0px solid;
    border-radius: 0px;
    border-color: @border-colour;
    background-color: transparent;
    children: [ "inputbar", "message", "custombox" ];
}
custombox {
    spacing: 0px;
    background-color: @background-colour;
    text-color: @foreground-colour;
    orientation: horizontal;
    children: [ "mode-switcher", "listview" ];
}
inputbar {
    enabled: true;
    spacing: 15px;
    margin: 0px;
    padding: 18px 25px;
    border: 1px solid;
    border-radius: 12px;
    border-color: #45475a;
    background-color: @background-colour;
    text-color: @foreground-colour;
    children: [ "textbox-prompt-colon", "entry" ];
}
prompt {
    enabled: true;
    background-color: inherit;
    text-color: inherit;
    font: "JetBrains Mono Nerd Font Bold 12";
}
textbox-prompt-colon {
    enabled: true;
    padding: 0px;
    expand: false;
    str: "🔍";
    background-color: inherit;
    text-color: @border-colour;
    font: "JetBrains Mono Nerd Font Bold 14";
}
entry {
    enabled: true;
    padding: 0px;
    background-color: inherit;
    text-color: inherit;
    cursor: text;
    placeholder: "Search shortcuts...";
    placeholder-color: #6c7086;
    font: "JetBrains Mono Nerd Font Medium 12";
}
listview {
    enabled: true;
    columns: 1;
    lines: 15;
    cycle: false;
    dynamic: true;
    scrollbar: true;
    layout: vertical;
    reverse: false;
    fixed-height: true;
    fixed-columns: true;
    spacing: 3px;
    margin: 0px;
    padding: 15px;
    border: 1px solid;
    border-radius: 0px 12px 12px 0px;
    border-color: #45475a;
    background-color: rgba(24, 24, 37, 0.6);
    text-color: @foreground-colour;
    cursor: "default";
}
scrollbar {
    handle-width: 6px;
    handle-color: @handle-colour;
    border-radius: 3px;
    background-color: rgba(69, 71, 90, 0.5);
}
element {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 12px 15px;
    border: 0px solid;
    border-radius: 8px;
    border-color: @border-colour;
    background-color: transparent;
    text-color: @foreground-colour;
    cursor: pointer;
}
element normal.normal {
    background-color: var(normal-background);
    text-color: var(normal-foreground);
}
element normal.urgent {
    background-color: var(urgent-background);
    text-color: var(urgent-foreground);
}
element normal.active {
    background-color: var(active-background);
    text-color: var(active-foreground);
}
element selected.normal {
    background-color: var(selected-normal-background);
    text-color: var(selected-normal-foreground);
    border: 1px solid;
    border-color: rgba(137, 180, 250, 0.5);
}
element selected.urgent {
    background-color: var(selected-urgent-background);
    text-color: var(selected-urgent-foreground);
}
element selected.active {
    background-color: var(selected-active-background);
    text-color: var(selected-active-foreground);
}
element-icon {
    background-color: transparent;
    text-color: inherit;
    size: 24px;
    cursor: inherit;
}
element-text {
    background-color: transparent;
    text-color: inherit;
    highlight: bold #f9e2af;
    cursor: inherit;
    vertical-align: 0.5;
    horizontal-align: 0.0;
    font: "JetBrains Mono Nerd Font Medium 11";
}
mode-switcher {
    enabled: true;
    expand: false;
    orientation: vertical;
    spacing: 0px;
    margin: 0px;
    padding: 0px;
    border: 1px solid;
    border-radius: 12px 0px 0px 12px;
    border-color: #45475a;
    background-color: @alternate-background;
    text-color: @foreground-colour;
}
button {
    padding: 15px 20px;
    border: 0px 1px 0px 0px;
    border-radius: 0px;
    border-color: #45475a;
    background-color: transparent;
    text-color: #a6adc8;
    vertical-align: 0.5;
    horizontal-align: 0.5;
    cursor: pointer;
    font: "JetBrains Mono Nerd Font Bold 11";
}
button selected {
    border: 0px 2px 0px 0px;
    border-color: @border-colour;
    background-color: rgba(137, 180, 250, 0.15);
    text-color: @border-colour;
}
message {
    enabled: true;
    margin: 0px;
    padding: 0px;
    border: 0px solid;
    border-radius: 0px;
    border-color: @border-colour;
    background-color: transparent;
    text-color: @foreground-colour;
}
textbox {
    padding: 12px;
    border: 1px solid;
    border-radius: 8px;
    border-color: rgba(137, 180, 250, 0.3);
    background-color: rgba(137, 180, 250, 0.1);
    text-color: @foreground-colour;
    vertical-align: 0.5;
    horizontal-align: 0.0;
    highlight: none;
    placeholder-color: @foreground-colour;
    blink: true;
    markup: true;
    font: "JetBrains Mono Nerd Font Medium 10";
}
error-message {
    padding: 15px;
    border: 1px solid;
    border-radius: 8px;
    border-color: #f38ba8;
    background-color: rgba(243, 139, 168, 0.1);
    text-color: #f38ba8;
}
EOF
}
# Keyboard shortcuts mode
keyboard_mode() {
    local cache_file="$HOME/.cache/i3_shortcuts.txt"
    local config_file="$HOME/.config/i3/config"
    if [ -f "$cache_file" ] && [ -f "$config_file" ] && [ "$config_file" -ot "$cache_file" ]; then
        cat "$cache_file"
    else
        mkdir -p "${cache_file%/*}"
        parse_i3_shortcuts | sort > "$cache_file"
        cat "$cache_file"
    fi
}
# Gestures mode
gestures_mode() {
    local cache_file="$HOME/.cache/fusuma_gestures.txt"
    local config_file="$HOME/.config/fusuma/config.yml"
    if [ -f "$cache_file" ] && [ -f "$config_file" ] && [ "$config_file" -ot "$cache_file" ]; then
        cat "$cache_file"
    else
        mkdir -p "${cache_file%/*}"
        local gestures_output
        gestures_output=$(parse_fusuma_shortcuts "$config_file" | sort)
        if [[ -z "$gestures_output" ]]; then
            {
                echo "👆 No gestures configured"
                echo ""
                echo "Configure touch gestures in ~/.config/fusuma/config.yml"
                echo ""
                echo "Example format:"
                echo "###START###"
                echo "# 3finger_swipe_left: Switch to next workspace"
                echo "# 3finger_swipe_right: Switch to previous workspace"
                echo "# 4finger_swipe_up: Show applications"
                echo "###END###"
            } > "$cache_file"
        else
            echo "$gestures_output" > "$cache_file"
        fi
        cat "$cache_file"
    fi
}
# Main display function with proper tabs
show_shortcuts() {
    local temp_file=$(mktemp)
    local theme_file=$(mktemp)
   
    # Write theme to temporary file
    get_rofi_theme > "$theme_file"
   
    # Use rofi with proper modi configuration for tabs
    rofi -show Keyboard \
        -modi "Keyboard:$0 --rofi-keyboard,Gestures:$0 --rofi-gestures" \
        -i \
        -theme "$theme_file" \
        -markup-rows \
        -mesg "💡 Navigate: <b>↑/↓</b> • Switch tabs: <b>Tab</b> • Search: <b>Type</b> • Close: <b>Esc</b>" \
        -no-custom \
        -kb-accept-entry "" \
        -kb-cancel "Super_L+backslash,Escape"
   
    # Cleanup
    rm -f "$temp_file" "$theme_file"
}
# Rofi modi handlers (internal use)
rofi_keyboard_handler() {
    keyboard_mode
}
rofi_gestures_handler() {
    gestures_mode
}
# Show raw output (for debugging/terminal use)
show_raw() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════════╗"
    echo "║ ⌨️ KEYBOARD SHORTCUTS ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════════╝"
    echo ""
   
    keyboard_mode | while IFS= read -r line; do
        echo " $line"
    done
   
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════════╗"
    echo "║ 👆 TOUCH GESTURES ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════════╝"
    echo ""
   
    gestures_mode | while IFS= read -r line; do
        echo " $line"
    done
   
    echo ""
}
# Help function
show_help() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════════╗"
    echo "║ 🚀 Enhanced Rofi Shortcuts Viewer ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo " show, -s, --show Show shortcuts with tabs (default)"
    echo " raw, -r, --raw Show formatted shortcuts in terminal"
    echo " help, -h, --help Show this help message"
    echo ""
    echo "✨ Features:"
    echo " • Beautiful tabbed interface like rofi's built-in modes"
    echo " • Real-time filtering and search"
    echo " • Proper description parsing from comments"
    echo " • Custom command support with c_c: syntax"
    echo " • Icon-rich display for better readability"
    echo ""
    echo "🎮 Navigation:"
    echo " • Type to search/filter shortcuts"
    echo " • ↑/↓ arrow keys to navigate"
    echo " • Tab to switch between Keyboard/Gestures"
    echo " • Escape to close"
    echo ""
    echo "🛠️ Custom Commands:"
    echo " Add above your i3 bindings:"
    echo " # c_c: \$mod+Shift+[ws]; Move container to workspace [ws]"
    echo " bindsym \$mod+Shift+1 move container to workspace number 1"
    echo ""
    echo " Or use regular comments:"
    echo " # Open terminal"
    echo " bindsym \$mod+Return exec alacritty"
    echo ""
}
# Parse command line arguments
case "${1:-show}" in
    "show"|"-s"|"--show"|"")
        show_shortcuts
        ;;
    "--rofi-keyboard")
        rofi_keyboard_handler
        ;;
    "--rofi-gestures")
        rofi_gestures_handler
        ;;
    "raw"|"-r"|"--raw")
        show_raw
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "❌ Unknown option: $1"
        echo "Use '$0 help' for usage information."
        exit 1
        ;;
esac
