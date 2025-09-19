#!/bin/bash

rofi_input() {
    local prompt="${1:-Input}"
    local message="${2:-Enter value}"
    local default_text="${3:-}"
    
    # Theme configuration
    local theme_config='
    window {
        transparency: "real";
        location: center;
        anchor: center;
        fullscreen: false;
        width: 450px;
        x-offset: 0px;
        y-offset: 0px;
        margin: 0px;
        padding: 0px;
        border: 1px solid;
        border-radius: 8px;
        border-color: #3daee9;
        cursor: "default";
        background-color: #1e1e2e;
    }
    
    mainbox {
        enabled: true;
        spacing: 15px;
        margin: 0px;
        padding: 25px;
        background-color: transparent;
        children: [ "inputbar", "message" ];
    }
    
    inputbar {
        enabled: true;
        spacing: 10px;
        padding: 0px;
        border: 0px;
        border-radius: 6px;
        border-color: #3daee9;
        background-color: transparent;
        text-color: #cdd6f4;
        children: [ "textbox-prompt-colon", "entry" ];
    }
    
    textbox-prompt-colon {
        enabled: true;
        expand: false;
        str: "";
        padding: 12px 15px;
        border-radius: 6px 0px 0px 6px;
        background-color: #3daee9;
        text-color: #1e1e2e;
        font: "JetBrains Mono Bold 10";
    }
    
    entry {
        enabled: true;
        expand: true;
        padding: 12px 15px;
        border-radius: 0px 6px 6px 0px;
        background-color: #313244;
        text-color: #cdd6f4;
        cursor: text;
        placeholder: "Type here...";
        placeholder-color: #6c7086;
        font: "JetBrains Mono 10";
    }
    
    message {
        enabled: true;
        margin: 0px;
        padding: 12px 15px;
        border: 0px solid;
        border-radius: 6px;
        border-color: #3daee9;
        background-color: #181825;
        text-color: #a6adc8;
    }
    
    textbox {
        background-color: inherit;
        text-color: inherit;
        vertical-align: 0.5;
        horizontal-align: 0.0;
        font: "JetBrains Mono 9";
    }
    '
    
    # Execute rofi with the input configuration
    echo "$default_text" | rofi \
        -dmenu \
        -p "$prompt" \
        -mesg "$message" \
        -theme-str "$theme_config" \
        -no-fixed-num-lines \
        -no-show-icons \
        -kb-accept-entry "Return" \
        -kb-cancel "Escape"
}

# Advanced version with validation and custom styling
rofi_input_advanced() {
    local prompt="${1:-Input}"
    local message="${2:-Enter value}"
    local default_text="${3:-}"
    local validate_cmd="${4:-}"  # Optional validation command
    local error_msg="${5:-Invalid input}"
    local color_scheme="${6:-blue}"  # blue, green, red, purple
    
    # Color schemes
    case "$color_scheme" in
        "green")
            local accent_color="#a6e3a1"
            local bg_color="#1e1e2e"
            ;;
        "red")
            local accent_color="#f38ba8"
            local bg_color="#1e1e2e"
            ;;
        "purple")
            local accent_color="#cba6f7"
            local bg_color="#1e1e2e"
            ;;
        *)  # blue (default)
            local accent_color="#3daee9"
            local bg_color="#1e1e2e"
            ;;
    esac
    
    local theme_config="
    window {
        transparency: \"real\";
        location: center;
        anchor: center;
        fullscreen: false;
        width: 450px;
        border: 2px solid;
        border-radius: 10px;
        border-color: $accent_color;
        background-color: $bg_color;
    }
    
    mainbox {
        spacing: 15px;
        padding: 25px;
        background-color: transparent;
        children: [ \"inputbar\", \"message\" ];
    }
    
    inputbar {
        spacing: 10px;
        background-color: transparent;
        text-color: #cdd6f4;
        children: [ \"textbox-prompt-colon\", \"entry\" ];
    }
    
    textbox-prompt-colon {
        expand: false;
        str: \"\";
        padding: 12px 15px;
        border-radius: 6px 0px 0px 6px;
        background-color: $accent_color;
        text-color: $bg_color;
        font: \"JetBrains Mono Bold 10\";
    }
    
    entry {
        expand: true;
        padding: 12px 15px;
        border-radius: 0px 6px 6px 0px;
        background-color: #313244;
        text-color: #cdd6f4;
        cursor: text;
        placeholder: \"Type here...\";
        placeholder-color: #6c7086;
    }
    
    message {
        padding: 12px 15px;
        border-radius: 6px;
        background-color: #181825;
        text-color: #a6adc8;
    }
    "
    
    while true; do
        local result
        result=$(echo "$default_text" | rofi \
            -dmenu \
            -p "$prompt" \
            -mesg "$message" \
            -theme-str "$theme_config" \
            -no-fixed-num-lines \
            -no-show-icons)
        
        # Check if user cancelled
        if [[ $? -ne 0 ]]; then
            return 1
        fi
        
        # If no validation command provided, return result
        if [[ -z "$validate_cmd" ]]; then
            echo "$result"
            return 0
        fi
        
        # Validate input
        if eval "$validate_cmd \"$result\""; then
            echo "$result"
            return 0
        else
            # Show error and retry
            message="$error_msg. Please try again."
            default_text="$result"
        fi
    done
}

# Take arguments with options
action="$1"
arg2="$2"
arg3="$3"
arg4="$4"
arg5="$5"
arg6="$6"

case "$action" in
    input)
        rofi_input "$arg2" "$arg3" "$arg4"
        ;;
esac
