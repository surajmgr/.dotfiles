#!/bin/bash

VERSION="2.0"
SCRIPT_NAME="$(basename "$0")"
CONFIG_DIR="$HOME/.config/ani-cli-wrapper"
CONFIG_FILE="$CONFIG_DIR/config"
MAL_CONFIG_DIR="$HOME/.config/mal-cli"
MAL_CONFIG_FILE="$MAL_CONFIG_DIR/config.yml"
HISTORY_FILE="$CONFIG_DIR/watch_history"
LOG_FILE="$CONFIG_DIR/wrapper.log"

# Colors and styling
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [PURPLE]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [WHITE]='\033[1;37m'
    [GRAY]='\033[0;37m'
    [BOLD]='\033[1m'
    [DIM]='\033[2m'
    [NC]='\033[0m'
)

# Box drawing characters
BOX_TOP_LEFT="┌"
BOX_TOP_RIGHT="┐"
BOX_BOTTOM_LEFT="└"
BOX_BOTTOM_RIGHT="┘"
BOX_HORIZONTAL="─"
BOX_VERTICAL="│"
BOX_CROSS="┼"

# Default settings
DEFAULT_QUALITY="1080"
DEFAULT_PLAYER="mpv"
DEFAULT_MODE="sub"
DEFAULT_DOWNLOAD_DIR="$HOME/Downloads/Anime"
DEFAULT_SKIP_INTRO="0"
DEFAULT_NO_DETACH="0"
DEFAULT_USE_ROFI="0"
DEFAULT_AUTO_NEXT="1"
DEFAULT_MAL_INTEGRATION="1"
DEFAULT_NOTIFICATIONS="1"
DEFAULT_RESUME_POSITION="1"

# Available players with their commands
declare -A PLAYERS=(
    [mpv]="mpv"
    [vlc]="vlc"
    [iina]="iina"
    [mplayer]="mplayer"
    [ffplay]="ffplay"
)

# Quality options
QUALITY_OPTIONS=("144" "240" "360" "480" "720" "1080" "best" "worst")

# Initialize directories and files
init_environment() {
    mkdir -p "$CONFIG_DIR" "$MAL_CONFIG_DIR"
    touch "$HISTORY_FILE" "$LOG_FILE"
    
    # Rotate log file if it gets too large (>1MB)
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt 1048576 ]]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
        touch "$LOG_FILE"
    fi
}

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

# Load configuration with validation
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log "INFO" "Configuration loaded from $CONFIG_FILE"
    else
        log "INFO" "Creating default configuration"
        set_defaults
        save_config
    fi
    
    # Validate settings
    validate_config
}

# Set default values
set_defaults() {
    QUALITY="$DEFAULT_QUALITY"
    PLAYER="$DEFAULT_PLAYER"
    MODE="$DEFAULT_MODE"
    DOWNLOAD_DIR="$DEFAULT_DOWNLOAD_DIR"
    SKIP_INTRO="$DEFAULT_SKIP_INTRO"
    NO_DETACH="$DEFAULT_NO_DETACH"
    USE_ROFI="$DEFAULT_USE_ROFI"
    AUTO_NEXT="$DEFAULT_AUTO_NEXT"
    MAL_INTEGRATION="$DEFAULT_MAL_INTEGRATION"
    NOTIFICATIONS="$DEFAULT_NOTIFICATIONS"
    RESUME_POSITION="$DEFAULT_RESUME_POSITION"
}

# Validate configuration
validate_config() {
    # Validate quality
    if [[ ! " ${QUALITY_OPTIONS[*]} " =~ " $QUALITY " ]]; then
        log "WARN" "Invalid quality '$QUALITY', using default"
        QUALITY="$DEFAULT_QUALITY"
    fi
    
    # Validate player
    if [[ -z "${PLAYERS[$PLAYER]}" ]]; then
        log "WARN" "Invalid player '$PLAYER', using default"
        PLAYER="$DEFAULT_PLAYER"
    fi
    
    # Validate mode
    if [[ "$MODE" != "sub" && "$MODE" != "dub" ]]; then
        log "WARN" "Invalid mode '$MODE', using default"
        MODE="$DEFAULT_MODE"
    fi
    
    # Validate boolean settings
    local bool_vars=("SKIP_INTRO" "NO_DETACH" "USE_ROFI" "AUTO_NEXT" "MAL_INTEGRATION" "NOTIFICATIONS" "RESUME_POSITION")
    for var in "${bool_vars[@]}"; do
        local value="${!var}"
        if [[ "$value" != "0" && "$value" != "1" ]]; then
            log "WARN" "Invalid boolean value for $var: '$value', setting to 0"
            declare -g "$var"="0"
        fi
    done
    
    # Validate download directory
    if [[ ! -d "$(dirname "$DOWNLOAD_DIR")" ]]; then
        log "WARN" "Download directory parent doesn't exist, using default"
        DOWNLOAD_DIR="$DEFAULT_DOWNLOAD_DIR"
    fi
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
# ani-cli wrapper configuration
# Generated on $(date)

QUALITY="$QUALITY"
PLAYER="$PLAYER"
MODE="$MODE"
DOWNLOAD_DIR="$DOWNLOAD_DIR"
SKIP_INTRO="$SKIP_INTRO"
NO_DETACH="$NO_DETACH"
USE_ROFI="$USE_ROFI"
AUTO_NEXT="$AUTO_NEXT"
MAL_INTEGRATION="$MAL_INTEGRATION"
NOTIFICATIONS="$NOTIFICATIONS"
RESUME_POSITION="$RESUME_POSITION"
EOF
    log "INFO" "Configuration saved"
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    # Check required dependencies
    if ! command -v ani-cli &> /dev/null; then
        missing+=("ani-cli")
    fi
    
    # Check optional dependencies
    if [[ "$MAL_INTEGRATION" == "1" ]] && ! command -v mal-cli &> /dev/null; then
        log "WARN" "mal-cli not found, MAL integration disabled"
        MAL_INTEGRATION="0"
    fi
    
    if [[ "$USE_ROFI" == "1" ]] && ! command -v rofi &> /dev/null; then
        log "WARN" "rofi not found, using built-in menus"
        USE_ROFI="0"
    fi
    
    if [[ "$NOTIFICATIONS" == "1" ]] && ! command -v notify-send &> /dev/null; then
        log "WARN" "notify-send not found, notifications disabled"
        NOTIFICATIONS="0"
    fi
    
    # Check if player is available
    if ! command -v "${PLAYERS[$PLAYER]}" &> /dev/null; then
        log "WARN" "Player '$PLAYER' not found, trying alternatives"
        for player in "${!PLAYERS[@]}"; do
            if command -v "${PLAYERS[$player]}" &> /dev/null; then
                PLAYER="$player"
                log "INFO" "Using alternative player: $player"
                break
            fi
        done
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${COLORS[RED]}Error: Missing required dependencies: ${missing[*]}${COLORS[NC]}"
        echo -e "${COLORS[YELLOW]}Please install the missing dependencies and try again.${COLORS[NC]}"
        exit 1
    fi
}

# Initialize MAL-CLI configuration if it doesn't exist
init_mal_cli() {
    if [[ "$MAL_INTEGRATION" != "1" ]]; then
        return
    fi
    
    if [[ ! -f "$MAL_CONFIG_FILE" ]]; then
        log "INFO" "Creating default MAL-CLI configuration"
        cat > "$MAL_CONFIG_FILE" << 'EOF'
keys:
  help: !char '?'
  back: !char 'q'
  search: !char '/'
  toggle: !char 's'
  next_state: !ctrl 'p'
  open_popup: !char 'r'
theme:
  mal_color: '#2E51A2'
  active: Cyan
  banner: '#2E51A2'
  hovered: Magenta
  text: White
  selected: LightCyan
  error_border: Red
  error_text: LightRed
  inactive: Gray
  status_completed: Green
  status_dropped: Gray
  status_on_hold: Yellow
  status_watching: Blue
  status_plan_to_watch: LightMagenta
  status_other: White
behavior:
  tick_rate_milliseconds: 500
  show_logger: false
nsfw: false
title_language: English
manga_display_type: Both
top_three_anime_types:
- airing
- all
- upcoming
- movie
- special
- ova
- tv
- popularity
- favorite
top_three_manga_types:
- all
- manga
- novels
- oneshots
- doujinshi
- manhwa
- manhua
- bypopularity
- favorite
navigation_stack_limit: 15
search_limit: 30
max_cached_images: 15
EOF
    fi
}

# Send notification if enabled
notify() {
    local title="$1"
    local message="$2"
    local icon="${3:-dialog-information}"
    
    if [[ "$NOTIFICATIONS" == "1" ]]; then
        notify-send -i "$icon" "$title" "$message" 2>/dev/null || true
    fi
}

show_status_bar() {
    local width=5
    # Repeat string function (safe for UTF-8)
    repeat() {
        local str=$1
        local num=$2
        local result=""
        for ((i=0;i<num;i++)); do
            result+="$str"
        done
        echo "$result"
    }
    # Draw centered title
    draw_title() {
        local title="$1"
        printf "%*s${COLORS[CYAN]}${title}${COLORS[NC]}\n"
    }
    # Draw separator line
    draw_separator() {
        echo -e "${COLORS[GRAY]}$(repeat "─" $width)${COLORS[NC]}"
    }
    # Clear screen first
    clear
    # Title
    draw_title "ANI-CLI WRAPPER v$VERSION"
    # Separator
    draw_separator
    # Settings line 1
    local skip_text="$([ "$SKIP_INTRO" = "1" ] && echo "On" || echo "Off")"
    local auto_text="$([ "$AUTO_NEXT" = "1" ] && echo "On" || echo "Off")"
    local mal_text="$([ "$MAL_INTEGRATION" = "1" ] && echo "On" || echo "Off")"
    local notify_text="$([ "$NOTIFICATIONS" = "1" ] && echo "On" || echo "Off")"
    # Use column for settings
    {
        printf "${COLORS[BOLD]}Quality:${COLORS[NC]}\t${COLORS[CYAN]}$QUALITY${COLORS[NC]}\t"
        printf "${COLORS[BOLD]}Player:${COLORS[NC]}\t${COLORS[CYAN]}$PLAYER${COLORS[NC]}\t"
        printf "${COLORS[BOLD]}Mode:${COLORS[NC]}\t${COLORS[CYAN]}$MODE${COLORS[NC]}\n"
        printf "${COLORS[BOLD]}Skip:${COLORS[NC]}\t${COLORS[CYAN]}$skip_text${COLORS[NC]}\t"
        printf "${COLORS[BOLD]}Auto:${COLORS[NC]}\t${COLORS[CYAN]}$auto_text${COLORS[NC]}\t"
        printf "${COLORS[BOLD]}MAL:${COLORS[NC]}\t${COLORS[CYAN]}$mal_text${COLORS[NC]}\t"
        printf "${COLORS[BOLD]}Notify:${COLORS[NC]}\t${COLORS[CYAN]}$notify_text${COLORS[NC]}\n"
    } | column -t -s $'\t'
    # Separator
    draw_separator
    # Command hints using column
    {
        printf "${COLORS[GRAY]}[s]${COLORS[NC]} Search\t"
        printf "${COLORS[GRAY]}[c]${COLORS[NC]} Continue\t"
        printf "${COLORS[GRAY]}[d]${COLORS[NC]} Download\t"
        printf "${COLORS[GRAY]}[e]${COLORS[NC]} Episode\t"
        printf "${COLORS[GRAY]}[b]${COLORS[NC]} Browse\n"
        printf "${COLORS[GRAY]}[m]${COLORS[NC]} MAL\t"
        printf "${COLORS[GRAY]}[u]${COLORS[NC]} Utils\t"
        printf "${COLORS[GRAY]}[o]${COLORS[NC]} Options\t"
        printf "${COLORS[GRAY]}[h]${COLORS[NC]} Help\t"
        printf "${COLORS[GRAY]}[q]${COLORS[NC]} Quit\n"
    } | column -t -s $'\t'
    # Leader key hints using column
    {
        printf "${COLORS[YELLOW]}Leader Keys (ALT+):${COLORS[NC]}\t"
        printf "${COLORS[GRAY]}1-8${COLORS[NC]} Quality\t"
        printf "${COLORS[GRAY]}p${COLORS[NC]} Player\t"
        printf "${COLORS[GRAY]}m${COLORS[NC]} Mode\t"
        printf "${COLORS[GRAY]}?${COLORS[NC]} Help\n"
    } | column -t -s $'\t'
    # Bottom separator
    draw_separator
}

# Enhanced help system
show_help() {
    clear
    local width=70
    
    echo -e "${COLORS[CYAN]}${BOX_TOP_LEFT}$(printf "%*s" $((width-2)) | tr ' ' "$BOX_HORIZONTAL")${BOX_TOP_RIGHT}${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}${BOX_VERTICAL}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BOX_VERTICAL}${COLORS[NC]}"
    
    local title="ANI-CLI WRAPPER HELP"
    local title_padding=$(((width - ${#title} - 2) / 2))
    printf "${COLORS[CYAN]}${BOX_VERTICAL}${COLORS[WHITE]}${COLORS[BOLD]}%*s%s%*s${COLORS[NC]}${COLORS[CYAN]}${BOX_VERTICAL}${COLORS[NC]}\n" \
           $title_padding "" "$title" $title_padding ""
    
    echo -e "${COLORS[CYAN]}${BOX_VERTICAL}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BOX_VERTICAL}${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}${BOX_VERTICAL}$(printf "%*s" $((width-2)) | tr ' ' "$BOX_HORIZONTAL")${BOX_VERTICAL}${COLORS[NC]}"
    
    # Main commands section
    echo -e "${COLORS[CYAN]}${BOX_VERTICAL} ${COLORS[YELLOW]}${COLORS[BOLD]}MAIN COMMANDS:${COLORS[NC]}$(printf "%*s" $((width-18)) "")${COLORS[CYAN]}${BOX_VERTICAL}${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}${BOX_VERTICAL}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BOX_VERTICAL}${COLORS[NC]}"
    
    local commands=(
        "s - Search and watch anime"
        "c - Continue from history"
        "d - Download episodes"
        "e - Quick episode selection"
        "b - Browse latest anime"
        "m - MyAnimeList integration"
        "u - Utilities menu"
        "o - Options and settings"
        "h - Show this help"
        "q - Quit application"
    )
    
    for cmd in "${commands[@]}"; do
        printf "${COLORS[CYAN]}${BOX_VERTICAL} ${COLORS[WHITE]}%-*s${COLORS[CYAN]}${BOX_VERTICAL}${COLORS[NC]}\n" $((width-4)) "$cmd"
    done
    
    echo -e "${COLORS[CYAN]}${BOX_VERTICAL}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BOX_VERTICAL}${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}${BOX_VERTICAL} ${COLORS[YELLOW]}${COLORS[BOLD]}LEADER KEYS (ALT+):${COLORS[NC]}$(printf "%*s" $((width-22)) "")${COLORS[CYAN]}${BOX_VERTICAL}${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}${BOX_VERTICAL}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BOX_VERTICAL}${COLORS[NC]}"
    
    local leader_commands=(
        "1-8 - Set quality (144p to best)"
        "p   - Cycle through players"
        "m   - Toggle sub/dub mode"
        "i   - Toggle intro skip"
        "a   - Toggle auto-next episode"
        "n   - Toggle notifications"
        "r   - Toggle resume position"
        "?   - Show this help"
    )
    
    for cmd in "${leader_commands[@]}"; do
        printf "${COLORS[CYAN]}${BOX_VERTICAL} ${COLORS[WHITE]}%-*s${COLORS[CYAN]}${BOX_VERTICAL}${COLORS[NC]}\n" $((width-4)) "$cmd"
    done
    
    echo -e "${COLORS[CYAN]}${BOX_VERTICAL}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BOX_VERTICAL}${COLORS[NC]}"
    echo -e "${COLORS[CYAN]}${BOX_BOTTOM_LEFT}$(printf "%*s" $((width-2)) | tr ' ' "$BOX_HORIZONTAL")${BOX_BOTTOM_RIGHT}${COLORS[NC]}"
    
    echo ""
    echo -n -e "${COLORS[YELLOW]}Press any key to return...${COLORS[NC]}"
    read -rsn1
}

# Enhanced key input handler with timeout
get_key() {
    local timeout="${1:-0}"
    local key
    
    if [[ "$timeout" -gt 0 ]]; then
        if ! IFS= read -rsn1 -t "$timeout" key 2>/dev/null; then
            echo "timeout"
            return
        fi
    else
        IFS= read -rsn1 key
    fi
    
    # Handle escape sequences
    if [[ "$key" == $'\e' ]]; then
        local next
        if IFS= read -rsn1 -t 0.1 next 2>/dev/null; then
            if [[ "$next" == "[" ]]; then
                # Arrow keys and function keys
                local more
                IFS= read -rsn1 -t 0.1 more 2>/dev/null
                case "$more" in
                    "A") echo "up" ;;
                    "B") echo "down" ;;
                    "C") echo "right" ;;
                    "D") echo "left" ;;
                    *) echo "escape" ;;
                esac
            else
                # ALT + key combination
                echo "alt-$next"
            fi
        else
            echo "escape"
        fi
    else
        echo "$key"
    fi
}

# Enhanced leader command handler
handle_leader_command() {
    local key="$1"
    local message=""
    
    case "$key" in
        "1") QUALITY="144"; message="Quality: $QUALITY" ;;
        "2") QUALITY="240"; message="Quality: $QUALITY" ;;
        "3") QUALITY="360"; message="Quality: $QUALITY" ;;
        "4") QUALITY="480"; message="Quality: $QUALITY" ;;
        "5") QUALITY="720"; message="Quality: $QUALITY" ;;
        "6") QUALITY="1080"; message="Quality: $QUALITY" ;;
        "7") QUALITY="best"; message="Quality: $QUALITY" ;;
        "8") QUALITY="worst"; message="Quality: $QUALITY" ;;
        "p"|"P")
            # Cycle through available players
            local players_list=($(printf '%s\n' "${!PLAYERS[@]}" | sort))
            local current_index=-1
            for i in "${!players_list[@]}"; do
                if [[ "${players_list[$i]}" == "$PLAYER" ]]; then
                    current_index=$i
                    break
                fi
            done
            
            local next_index=$(( (current_index + 1) % ${#players_list[@]} ))
            PLAYER="${players_list[$next_index]}"
            message="Player: $PLAYER"
            ;;
        "m"|"M")
            MODE=$([ "$MODE" == "sub" ] && echo "dub" || echo "sub")
            message="Mode: $MODE"
            ;;
        "i"|"I")
            SKIP_INTRO=$([ "$SKIP_INTRO" == "1" ] && echo "0" || echo "1")
            message="Skip Intro: $([ "$SKIP_INTRO" == "1" ] && echo "On" || echo "Off")"
            ;;
        "a"|"A")
            AUTO_NEXT=$([ "$AUTO_NEXT" == "1" ] && echo "0" || echo "1")
            message="Auto Next: $([ "$AUTO_NEXT" == "1" ] && echo "On" || echo "Off")"
            ;;
        "n"|"N")
            NOTIFICATIONS=$([ "$NOTIFICATIONS" == "1" ] && echo "0" || echo "1")
            message="Notifications: $([ "$NOTIFICATIONS" == "1" ] && echo "On" || echo "Off")"
            ;;
        "r"|"R")
            RESUME_POSITION=$([ "$RESUME_POSITION" == "1" ] && echo "0" || echo "1")
            message="Resume Position: $([ "$RESUME_POSITION" == "1" ] && echo "On" || echo "Off")"
            ;;
        "?"|"/")
            show_help
            return
            ;;
        *)
            message="Unknown command: ALT+$key"
            echo -e "\n${COLORS[RED]}$message${COLORS[NC]}"
            sleep 1
            return
            ;;
    esac
    
    if [[ -n "$message" ]]; then
        save_config
        echo -e "\n${COLORS[GREEN]}$message${COLORS[NC]}"
        log "INFO" "Setting changed: $message"
        sleep 0.8
    fi
}

# Build ani-cli command with all options
build_ani_cli_command() {
    local base_cmd="$1"
    local cmd="ani-cli"
    
    # Add base command flags
    if [[ -n "$base_cmd" ]]; then
        cmd="$cmd $base_cmd"
    fi
    
    # Add quality option
    cmd="$cmd -q $QUALITY"
    
    # Add player option
    case "$PLAYER" in
        "vlc") cmd="$cmd -v" ;;
        "mpv") ;; # Default, no flag needed
        *) 
            export ANI_CLI_PLAYER="${PLAYERS[$PLAYER]}"
            ;;
    esac
    
    # Add mode (sub/dub)
    if [[ "$MODE" == "dub" ]]; then
        cmd="$cmd --dub"
    fi
    
    # Add skip intro if enabled
    if [[ "$SKIP_INTRO" == "1" ]]; then
        cmd="$cmd --skip"
    fi
    
    # Add no detach if enabled
    if [[ "$NO_DETACH" == "1" ]]; then
        cmd="$cmd --no-detach"
    fi
    
    # Add rofi if enabled and available
    if [[ "$USE_ROFI" == "1" ]] && command -v rofi &> /dev/null; then
        cmd="$cmd --rofi"
    fi
    
    echo "$cmd"
}

search_and_watch() {
    while true; do
        clear
        show_status_bar
        echo ""
        
        echo -e "${COLORS[CYAN]}${COLORS[BOLD]}🔍 SEARCH & WATCH ANIME${COLORS[NC]}"
        echo ""
        
        # Offer MAL search if available
        if [[ "$MAL_INTEGRATION" == "1" ]]; then
            echo -e "${COLORS[YELLOW]}Search options:${COLORS[NC]}"
            echo -e "  ${COLORS[WHITE]}[1]${COLORS[NC]} Direct search (enter anime name)"
            echo -e "  ${COLORS[WHITE]}[2]${COLORS[NC]} Browse with MyAnimeList"
            echo -e "  ${COLORS[WHITE]}[3]${COLORS[NC]} Latest anime"
            echo ""
            echo -n -e "${COLORS[YELLOW]}Choose option [1-3] or ESC to go back: ${COLORS[NC]}"
            
            local choice=$(get_key)
            case "$choice" in
                "1")
                    echo -e "\n${COLORS[CYAN]}Direct Search${COLORS[NC]}"
                    echo -n -e "${COLORS[YELLOW]}Enter anime name: ${COLORS[NC]}"
                    read -r anime_name
                    ;;
                "2")
                    echo -e "\n${COLORS[CYAN]}Opening MyAnimeList browser...${COLORS[NC]}"
                    mal-cli
                    echo -n -e "${COLORS[YELLOW]}Enter anime name from MAL: ${COLORS[NC]}"
                    read -r anime_name
                    ;;
                "3")
                    echo -e "\n${COLORS[CYAN]}Browsing latest anime...${COLORS[NC]}"
                    anime_name=""
                    ;;
                "escape"|"q"|"Q")
                    return
                    ;;
                *)
                    continue
                    ;;
            esac
        else
            echo -n -e "${COLORS[YELLOW]}Enter anime name (empty for latest): ${COLORS[NC]}"
            read -r anime_name
        fi
        
        echo ""
        
        # Build and execute command
        local cmd=$(build_ani_cli_command)
        
        if [[ -z "$anime_name" ]]; then
            cmd="$cmd -n"
            echo -e "${COLORS[CYAN]}Browsing latest anime...${COLORS[NC]}"
            notify "Ani-CLI" "Browsing latest anime"
        else
            cmd="$cmd \"$anime_name\""
            echo -e "${COLORS[CYAN]}Searching for: $anime_name${COLORS[NC]}"
            notify "Ani-CLI" "Searching for: $anime_name"
        fi
        
        execute_ani_cli "$cmd" "$anime_name"
        
        echo ""
        echo -e "${COLORS[YELLOW]}Options: ${COLORS[WHITE]}[r]${COLORS[NC]}etry ${COLORS[WHITE]}[n]${COLORS[NC]}ew search ${COLORS[WHITE]}[ESC]${COLORS[NC]} back"
        echo -n -e "${COLORS[YELLOW]}Choose: ${COLORS[NC]}"
        
        local key=$(get_key)
        case "$key" in
            "r"|"R") continue ;;
            "n"|"N") continue ;;
            "escape"|"q"|"Q") break ;;
            *) break ;;
        esac
    done
}

# Enhanced execution with better error handling
execute_ani_cli() {
    local cmd="$1"
    local anime_name="$2"
    
    log "INFO" "Executing: $cmd"
    echo -e "${COLORS[GREEN]}Executing: ${COLORS[DIM]}$cmd${COLORS[NC]}"
    echo ""
    
    # Record in history if anime name provided
    if [[ -n "$anime_name" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $anime_name" >> "$HISTORY_FILE"
    fi
    
    # Execute with error handling
    if eval "$cmd"; then
        local exit_code=$?
        log "INFO" "Command completed successfully"
        notify "Ani-CLI" "Playback completed" "dialog-information"
        
        # Offer to continue next episode if auto-next is enabled
        if [[ "$AUTO_NEXT" == "1" && -n "$anime_name" ]]; then
            echo ""
            echo -n -e "${COLORS[YELLOW]}Continue to next episode? [Y/n]: ${COLORS[NC]}"
            local continue_choice=$(get_key 5)
            if [[ "$continue_choice" != "n" && "$continue_choice" != "N" && "$continue_choice" != "timeout" ]]; then
                local next_cmd="$cmd"
                eval "$next_cmd"
            fi
        fi
    else
        local exit_code=$?
        log "ERROR" "Command failed with exit code: $exit_code"
        echo -e "${COLORS[RED]}Command failed with exit code: $exit_code${COLORS[NC]}"
        
        # Offer fallback options
        if [[ "$MODE" == "dub" ]]; then
            echo ""
            echo -n -e "${COLORS[YELLOW]}Dub not found. Try sub version? [Y/n]: ${COLORS[NC]}"
            local fallback_choice=$(get_key 10)
            if [[ "$fallback_choice" != "n" && "$fallback_choice" != "N" && "$fallback_choice" != "timeout" ]]; then
                echo -e "${COLORS[CYAN]}Retrying with sub version...${COLORS[NC]}"
                local fallback_cmd=$(echo "$cmd" | sed 's/--dub//g')
                log "INFO" "Retrying with sub: $fallback_cmd"
                eval "$fallback_cmd"
            fi
        fi
        
        notify "Ani-CLI" "Playback failed" "dialog-error"
    fi
}

# Continue from history with enhanced features
continue_from_history() {
    clear
    show_status_bar
    echo ""
    
    echo -e "${COLORS[CYAN]}${COLORS[BOLD]}📺 CONTINUE WATCHING${COLORS[NC]}"
    echo ""
    
    if [[ "$RESUME_POSITION" == "1" ]]; then
        echo -e "${COLORS[GREEN]}Resume position enabled${COLORS[NC]}"
        echo ""
    fi
    
    local cmd=$(build_ani_cli_command "-c")
    
    echo -e "${COLORS[CYAN]}Loading watch history...${COLORS[NC]}"
    notify "Ani-CLI" "Loading watch history"
    
    execute_ani_cli "$cmd"
    
    echo ""
    echo -n -e "${COLORS[YELLOW]}Press any key to return...${COLORS[NC]}"
    read -rsn1
}

download_episodes() {
    while true; do
        clear
        show_status_bar
        echo ""
        
        echo -e "${COLORS[CYAN]}${COLORS[BOLD]}⬇️  DOWNLOAD EPISODES${COLORS[NC]}"
        echo ""
        echo -e "${COLORS[GREEN]}Download directory: ${COLORS[YELLOW]}$DOWNLOAD_DIR${COLORS[NC]}"
        
        # Create download directory if it doesn't exist
        mkdir -p "$DOWNLOAD_DIR"
        
        # Check available space
        local available_space=$(df -h "$DOWNLOAD_DIR" 2>/dev/null | awk 'NR==2 {print $4}' || echo "Unknown")
        echo -e "${COLORS[GREEN]}Available space: ${COLORS[YELLOW]}$available_space${COLORS[NC]}"
        echo ""
        
        # Offer MAL search for downloads too
        if [[ "$MAL_INTEGRATION" == "1" ]]; then
            echo -e "${COLORS[YELLOW]}Download options:${COLORS[NC]}"
            echo -e "  ${COLORS[WHITE]}[1]${COLORS[NC]} Direct download (enter anime name)"
            echo -e "  ${COLORS[WHITE]}[2]${COLORS[NC]} Browse with MyAnimeList"
            echo ""
            echo -n -e "${COLORS[YELLOW]}Choose option [1-2] or ESC to go back: ${COLORS[NC]}"
            
            local choice=$(get_key)
            case "$choice" in
                "1")
                    echo -e "\n${COLORS[CYAN]}Direct Download${COLORS[NC]}"
                    ;;
                "2")
                    echo -e "\n${COLORS[CYAN]}Opening MyAnimeList browser...${COLORS[NC]}"
                    mal-cli
                    ;;
                "escape"|"q"|"Q")
                    return
                    ;;
                *)
                    continue
                    ;;
            esac
        fi
        
        echo -n -e "${COLORS[YELLOW]}Enter anime name: ${COLORS[NC]}"
        read -r anime_name
        
        if [[ -z "$anime_name" ]]; then
            echo -e "${COLORS[RED]}Error: Anime name is required for download${COLORS[NC]}"
            echo -n -e "${COLORS[YELLOW]}Press any key to continue...${COLORS[NC]}"
            read -rsn1
            continue
        fi
        
        echo ""
        echo -n -e "${COLORS[YELLOW]}Enter episode range (e.g., 1-12, 5, 1,3,5) or empty for all: ${COLORS[NC]}"
        read -r episode_range
        
        echo ""
        echo -n -e "${COLORS[YELLOW]}Download quality [current: $QUALITY]: ${COLORS[NC]}"
        read -r download_quality
        
        # Use current quality if not specified
        if [[ -z "$download_quality" ]]; then
            download_quality="$QUALITY"
        fi
        
        local cmd=$(build_ani_cli_command "-d")
        
        # Override quality for this download
        cmd=$(echo "$cmd" | sed "s/-q $QUALITY/-q $download_quality/")
        
        if [[ -n "$episode_range" ]]; then
            cmd="$cmd -r \"$episode_range\""
        fi
        
        cmd="$cmd \"$anime_name\""
        
        # Set download directory
        export ANI_CLI_DOWNLOAD_DIR="$DOWNLOAD_DIR"
        
        echo ""
        echo -e "${COLORS[CYAN]}Starting download...${COLORS[NC]}"
        notify "Ani-CLI" "Starting download: $anime_name"
        
        execute_ani_cli "$cmd" "$anime_name"
        
        # Show download completion notification
        notify "Ani-CLI" "Download completed: $anime_name" "dialog-information"
        
        echo ""
        echo -e "${COLORS[YELLOW]}Options: ${COLORS[WHITE]}[r]${COLORS[NC]}etry ${COLORS[WHITE]}[n]${COLORS[NC]}ew download ${COLORS[WHITE]}[ESC]${COLORS[NC]} back"
        echo -n -e "${COLORS[YELLOW]}Choose: ${COLORS[NC]}"
        
        local key=$(get_key)
        case "$key" in
            "r"|"R") continue ;;
            "n"|"N") continue ;;
            "escape"|"q"|"Q") break ;;
            *) break ;;
        esac
    done
}

quick_episode() {
    while true; do
        clear
        show_status_bar
        echo ""
        
        echo -e "${COLORS[CYAN]}${COLORS[BOLD]}🎯 QUICK EPISODE SELECTION${COLORS[NC]}"
        echo ""
        
        echo -n -e "${COLORS[YELLOW]}Enter anime name: ${COLORS[NC]}"
        read -r anime_name
        
        if [[ -z "$anime_name" ]]; then
            echo -e "${COLORS[RED]}Error: Anime name is required${COLORS[NC]}"
            echo -n -e "${COLORS[YELLOW]}Press any key to continue...${COLORS[NC]}"
            read -rsn1
            continue
        fi
        
        echo ""
        echo -n -e "${COLORS[YELLOW]}Enter episode number or range (e.g., 5 or 5-8): ${COLORS[NC]}"
        read -r episode
        
        local cmd=$(build_ani_cli_command)
        
        if [[ -n "$episode" ]]; then
            cmd="$cmd -e \"$episode\""
        fi
        
        cmd="$cmd \"$anime_name\""
        
        echo ""
        echo -e "${COLORS[CYAN]}Loading episode...${COLORS[NC]}"
        notify "Ani-CLI" "Loading episode $episode of $anime_name"
        
        execute_ani_cli "$cmd" "$anime_name"
        
        echo ""
        echo -e "${COLORS[YELLOW]}Options: ${COLORS[WHITE]}[r]${COLORS[NC]}etry ${COLORS[WHITE]}[n]${COLORS[NC]}ew episode ${COLORS[WHITE]}[ESC]${COLORS[NC]} back"
        echo -n -e "${COLORS[YELLOW]}Choose: ${COLORS[NC]}"
        
        local key=$(get_key)
        case "$key" in
            "r"|"R") continue ;;
            "n"|"N") continue ;;
            "escape"|"q"|"Q") break ;;
            *) break ;;
        esac
    done
}

browse_latest() {
    clear
    show_status_bar
    echo ""
    
    echo -e "${COLORS[CYAN]}${COLORS[BOLD]}🔥 BROWSE LATEST ANIME${COLORS[NC]}"
    echo ""
    
    if [[ "$MAL_INTEGRATION" == "1" ]]; then
        echo -e "${COLORS[YELLOW]}Browse options:${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}[1]${COLORS[NC]} Latest/Popular (ani-cli)"
        echo -e "  ${COLORS[WHITE]}[2]${COLORS[NC]} MyAnimeList rankings"
        echo -e "  ${COLORS[WHITE]}[3]${COLORS[NC]} Currently airing"
        echo ""
        echo -n -e "${COLORS[YELLOW]}Choose option [1-3]: ${COLORS[NC]}"
        
        local choice=$(get_key)
        case "$choice" in
            "1")
                echo -e "\n${COLORS[CYAN]}Loading popular anime...${COLORS[NC]}"
                local cmd=$(build_ani_cli_command "-n")
                ;;
            "2")
                echo -e "\n${COLORS[CYAN]}Opening MyAnimeList rankings...${COLORS[NC]}"
                mal-cli
                echo -n -e "\n${COLORS[YELLOW]}Press any key to return...${COLORS[NC]}"
                read -rsn1
                return
                ;;
            "3")
                echo -e "\n${COLORS[CYAN]}Loading currently airing anime...${COLORS[NC]}"
                local cmd=$(build_ani_cli_command "-n")
                ;;
            *)
                return
                ;;
        esac
    else
        echo -e "${COLORS[CYAN]}Loading latest anime...${COLORS[NC]}"
        local cmd=$(build_ani_cli_command "-n")
    fi
    
    notify "Ani-CLI" "Browsing latest anime"
    execute_ani_cli "$cmd"
    
    echo ""
    echo -n -e "${COLORS[YELLOW]}Press any key to return...${COLORS[NC]}"
    read -rsn1
}

mal_integration() {
    if [[ "$MAL_INTEGRATION" != "1" ]]; then
        echo -e "${COLORS[RED]}MAL integration is disabled${COLORS[NC]}"
        sleep 2
        return
    fi
    
    while true; do
        clear
        show_status_bar
        echo ""
        
        echo -e "${COLORS[CYAN]}${COLORS[BOLD]}📊 MYANIMELIST INTEGRATION${COLORS[NC]}"
        echo ""
        
        echo -e "${COLORS[YELLOW]}MAL Options:${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}[1]${COLORS[NC]} Browse anime rankings"
        echo -e "  ${COLORS[WHITE]}[2]${COLORS[NC]} Search anime database"
        echo -e "  ${COLORS[WHITE]}[3]${COLORS[NC]} View your list"
        echo -e "  ${COLORS[WHITE]}[4]${COLORS[NC]} Currently airing"
        echo -e "  ${COLORS[WHITE]}[5]${COLORS[NC]} Popular anime"
        echo -e "  ${COLORS[WHITE]}[c]${COLORS[NC]} Configure MAL-CLI"
        echo -e "  ${COLORS[WHITE]}[ESC]${COLORS[NC]} Back to main menu"
        echo ""
        echo -n -e "${COLORS[YELLOW]}Choose option: ${COLORS[NC]}"
        
        local choice=$(get_key)
        case "$choice" in
            "1"|"2"|"3"|"4"|"5")
                echo -e "\n${COLORS[CYAN]}Opening MAL-CLI...${COLORS[NC]}"
                mal-cli
                echo -n -e "\n${COLORS[YELLOW]}Press any key to continue...${COLORS[NC]}"
                read -rsn1
                ;;
            "c"|"C")
                echo -e "\n${COLORS[CYAN]}MAL-CLI Configuration:${COLORS[NC]}"
                echo -e "${COLORS[GREEN]}Config file: ${COLORS[YELLOW]}$MAL_CONFIG_FILE${COLORS[NC]}"
                echo ""
                echo -e "${COLORS[WHITE]}Edit configuration? [y/N]: ${COLORS[NC]}"
                local edit_choice=$(get_key)
                if [[ "$edit_choice" =~ ^[Yy]$ ]]; then
                    ${EDITOR:-nano} "$MAL_CONFIG_FILE"
                fi
                ;;
            "escape"|"q"|"Q")
                break
                ;;
        esac
    done
}

handle_utilities() {
    while true; do
        clear
        show_status_bar
        echo ""
        
        echo -e "${COLORS[CYAN]}${COLORS[BOLD]}🔧 UTILITIES${COLORS[NC]}"
        echo ""
        
        echo -e "${COLORS[YELLOW]}Utility Options:${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}[h]${COLORS[NC]} View watch history"
        echo -e "  ${COLORS[WHITE]}[l]${COLORS[NC]} View ani-cli history"
        echo -e "  ${COLORS[WHITE]}[x]${COLORS[NC]} Clear ani-cli history"
        echo -e "  ${COLORS[WHITE]}[w]${COLORS[NC]} Clear wrapper history"
        echo -e "  ${COLORS[WHITE]}[L]${COLORS[NC]} View wrapper logs"
        echo -e "  ${COLORS[WHITE]}[u]${COLORS[NC]} Update ani-cli"
        echo -e "  ${COLORS[WHITE]}[t]${COLORS[NC]} Test media player"
        echo -e "  ${COLORS[WHITE]}[d]${COLORS[NC]} Change download directory"
        echo -e "  ${COLORS[WHITE]}[c]${COLORS[NC]} Clean cache"
        echo -e "  ${COLORS[WHITE]}[ESC]${COLORS[NC]} Back to main menu"
        echo ""
        echo -n -e "${COLORS[YELLOW]}Choose option: ${COLORS[NC]}"
        
        local key=$(get_key)
        if [[ "$key" =~ ^alt-(.)$ ]]; then
            handle_leader_command "${BASH_REMATCH[1]}"
            continue
        fi
        
        case "$key" in
            "h"|"H")
                echo -e "\n${COLORS[CYAN]}Watch History:${COLORS[NC]}"
                echo ""
                if [[ -s "$HISTORY_FILE" ]]; then
                    tail -n 20 "$HISTORY_FILE" | while IFS= read -r line; do
                        echo -e "${COLORS[WHITE]}$line${COLORS[NC]}"
                    done
                else
                    echo -e "${COLORS[GRAY]}No watch history found${COLORS[NC]}"
                fi
                echo -n -e "\n${COLORS[YELLOW]}Press any key to continue...${COLORS[NC]}"
                get_key
                ;;
            "l"|"L")
                if [[ "$key" == "l" ]]; then
                    echo -e "\n${COLORS[CYAN]}Ani-CLI History:${COLORS[NC]}"
                    ani-cli -l
                else
                    echo -e "\n${COLORS[CYAN]}Wrapper Logs (last 50 lines):${COLORS[NC]}"
                    echo ""
                    tail -n 50 "$LOG_FILE" 2>/dev/null || echo -e "${COLORS[GRAY]}No logs found${COLORS[NC]}"
                fi
                echo -n -e "\n${COLORS[YELLOW]}Press any key to continue...${COLORS[NC]}"
                get_key
                ;;
            "x"|"X")
                echo -n -e "\n${COLORS[RED]}Clear ani-cli history? [y/N]: ${COLORS[NC]}"
                local confirm=$(get_key)
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    ani-cli -D
                    echo -e "${COLORS[GREEN]}Ani-CLI history cleared${COLORS[NC]}"
                    log "INFO" "Ani-CLI history cleared"
                else
                    echo -e "${COLORS[YELLOW]}Cancelled${COLORS[NC]}"
                fi
                sleep 1
                ;;
            "w"|"W")
                echo -n -e "\n${COLORS[RED]}Clear wrapper history? [y/N]: ${COLORS[NC]}"
                local confirm=$(get_key)
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    > "$HISTORY_FILE"
                    echo -e "${COLORS[GREEN]}Wrapper history cleared${COLORS[NC]}"
                    log "INFO" "Wrapper history cleared"
                else
                    echo -e "${COLORS[YELLOW]}Cancelled${COLORS[NC]}"
                fi
                sleep 1
                ;;
            "u"|"U")
                echo -e "\n${COLORS[CYAN]}Updating ani-cli...${COLORS[NC]}"
                ani-cli -U
                echo -n -e "\n${COLORS[YELLOW]}Press any key to continue...${COLORS[NC]}"
                get_key
                ;;
            "t"|"T")
                echo -e "\n${COLORS[CYAN]}Testing media player: $PLAYER${COLORS[NC]}"
                echo ""
                if command -v "${PLAYERS[$PLAYER]}" &> /dev/null; then
                    echo -e "${COLORS[GREEN]}✓ $PLAYER is available${COLORS[NC]}"
                    echo -e "${COLORS[GREEN]}  Path: $(which "${PLAYERS[$PLAYER]}")${COLORS[NC]}"
                    
                    # Test version if possible
                    local version_output
                    case "$PLAYER" in
                        "mpv")
                            version_output=$(mpv --version 2>/dev/null | head -n1)
                            ;;
                        "vlc")
                            version_output=$(vlc --version 2>/dev/null | head -n1)
                            ;;
                    esac
                    
                    if [[ -n "$version_output" ]]; then
                        echo -e "${COLORS[GREEN]}  Version: $version_output${COLORS[NC]}"
                    fi
                else
                    echo -e "${COLORS[RED]}✗ $PLAYER is not available${COLORS[NC]}"
                    echo -e "${COLORS[YELLOW]}Available players:${COLORS[NC]}"
                    for player in "${!PLAYERS[@]}"; do
                        if command -v "${PLAYERS[$player]}" &> /dev/null; then
                            echo -e "  ${COLORS[GREEN]}✓ $player${COLORS[NC]}"
                        else
                            echo -e "  ${COLORS[RED]}✗ $player${COLORS[NC]}"
                        fi
                    done
                fi
                sleep 3
                ;;
            "d"|"D")
                echo -e "\n${COLORS[CYAN]}Current download directory: ${COLORS[YELLOW]}$DOWNLOAD_DIR${COLORS[NC]}"
                echo -n -e "${COLORS[YELLOW]}Enter new download directory: ${COLORS[NC]}"
                read -r new_dir
                if [[ -n "$new_dir" ]]; then
                    DOWNLOAD_DIR="${new_dir/#\~/$HOME}"
                    mkdir -p "$DOWNLOAD_DIR" 2>/dev/null
                    if [[ -d "$DOWNLOAD_DIR" ]]; then
                        save_config
                        echo -e "${COLORS[GREEN]}Download directory set to: $DOWNLOAD_DIR${COLORS[NC]}"
                        log "INFO" "Download directory changed to: $DOWNLOAD_DIR"
                    else
                        echo -e "${COLORS[RED]}Failed to create directory: $DOWNLOAD_DIR${COLORS[NC]}"
                    fi
                fi
                sleep 2
                ;;
            "c"|"C")
                echo -e "\n${COLORS[CYAN]}Cleaning cache...${COLORS[NC]}"
                
                # Clean ani-cli cache
                if command -v ani-cli &> /dev/null; then
                    local cache_dir="$HOME/.cache/ani-cli"
                    if [[ -d "$cache_dir" ]]; then
                        local cache_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
                        echo -e "${COLORS[YELLOW]}Cache size: $cache_size${COLORS[NC]}"
                        echo -n -e "${COLORS[RED]}Clear cache? [y/N]: ${COLORS[NC]}"
                        local confirm=$(get_key)
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            rm -rf "$cache_dir"/*
                            echo -e "${COLORS[GREEN]}Cache cleared${COLORS[NC]}"
                            log "INFO" "Cache cleared"
                        fi
                    else
                        echo -e "${COLORS[GRAY]}No cache found${COLORS[NC]}"
                    fi
                fi
                
                # Clean MAL-CLI cache if available
                if [[ "$MAL_INTEGRATION" == "1" ]]; then
                    local mal_cache_dir="$HOME/.cache/mal-cli"
                    if [[ -d "$mal_cache_dir" ]]; then
                        echo -n -e "${COLORS[RED]}Clear MAL cache too? [y/N]: ${COLORS[NC]}"
                        local confirm=$(get_key)
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            rm -rf "$mal_cache_dir"/*
                            echo -e "${COLORS[GREEN]}MAL cache cleared${COLORS[NC]}"
                        fi
                    fi
                fi
                sleep 2
                ;;
            "escape"|"q"|"Q")
                break
                ;;
        esac
    done
}

options_menu() {
    while true; do
        clear
        show_status_bar
        echo ""
        
        echo -e "${COLORS[CYAN]}${COLORS[BOLD]}⚙️  OPTIONS & SETTINGS${COLORS[NC]}"
        echo ""
        
        echo -e "${COLORS[YELLOW]}Current Settings:${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}Quality:${COLORS[NC]} ${COLORS[CYAN]}$QUALITY${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}Player:${COLORS[NC]} ${COLORS[CYAN]}$PLAYER${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}Mode:${COLORS[NC]} ${COLORS[CYAN]}$MODE${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}Skip Intro:${COLORS[NC]} ${COLORS[CYAN]}$([ "$SKIP_INTRO" = "1" ] && echo "On" || echo "Off")${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}Auto Next:${COLORS[NC]} ${COLORS[CYAN]}$([ "$AUTO_NEXT" = "1" ] && echo "On" || echo "Off")${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}Notifications:${COLORS[NC]} ${COLORS[CYAN]}$([ "$NOTIFICATIONS" = "1" ] && echo "On" || echo "Off")${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}MAL Integration:${COLORS[NC]} ${COLORS[CYAN]}$([ "$MAL_INTEGRATION" = "1" ] && echo "On" || echo "Off")${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}Resume Position:${COLORS[NC]} ${COLORS[CYAN]}$([ "$RESUME_POSITION" = "1" ] && echo "On" || echo "Off")${COLORS[NC]}"
        echo ""
        
        echo -e "${COLORS[YELLOW]}Options:${COLORS[NC]}"
        echo -e "  ${COLORS[WHITE]}[q]${COLORS[NC]} Quality settings"
        echo -e "  ${COLORS[WHITE]}[p]${COLORS[NC]} Player settings"
        echo -e "  ${COLORS[WHITE]}[m]${COLORS[NC]} Toggle sub/dub mode"
        echo -e "  ${COLORS[WHITE]}[s]${COLORS[NC]} Toggle skip intro"
        echo -e "  ${COLORS[WHITE]}[a]${COLORS[NC]} Toggle auto-next episode"
        echo -e "  ${COLORS[WHITE]}[n]${COLORS[NC]} Toggle notifications"
        echo -e "  ${COLORS[WHITE]}[M]${COLORS[NC]} Toggle MAL integration"
        echo -e "  ${COLORS[WHITE]}[r]${COLORS[NC]} Toggle resume position"
        echo -e "  ${COLORS[WHITE]}[d]${COLORS[NC]} Download directory"
        echo -e "  ${COLORS[WHITE]}[R]${COLORS[NC]} Reset to defaults"
        echo -e "  ${COLORS[WHITE]}[ESC]${COLORS[NC]} Back to main menu"
        echo ""
        echo -n -e "${COLORS[YELLOW]}Choose option: ${COLORS[NC]}"
        
        local key=$(get_key)
        case "$key" in
            "q"|"Q")
                echo -e "\n${COLORS[CYAN]}Quality Options:${COLORS[NC]}"
                echo ""
                for i in "${!QUALITY_OPTIONS[@]}"; do
                    local quality="${QUALITY_OPTIONS[$i]}"
                    local marker=""
                    if [[ "$quality" == "$QUALITY" ]]; then
                        marker=" ${COLORS[GREEN]}(current)${COLORS[NC]}"
                    fi
                    echo -e "  ${COLORS[WHITE]}[$((i+1))]${COLORS[NC]} $quality$marker"
                done
                echo ""
                echo -n -e "${COLORS[YELLOW]}Choose quality [1-${#QUALITY_OPTIONS[@]}]: ${COLORS[NC]}"
                
                local choice=$(get_key)
                if [[ "$choice" =~ ^[1-8]$ ]]; then
                    local index=$((choice - 1))
                    if [[ $index -ge 0 && $index -lt ${#QUALITY_OPTIONS[@]} ]]; then
                        QUALITY="${QUALITY_OPTIONS[$index]}"
                        save_config
                        echo -e "\n${COLORS[GREEN]}Quality set to: $QUALITY${COLORS[NC]}"
                        sleep 1
                    fi
                fi
                ;;
            "p"|"P")
                echo -e "\n${COLORS[CYAN]}Player Options:${COLORS[NC]}"
                echo ""
                local i=1
                for player in $(printf '%s\n' "${!PLAYERS[@]}" | sort); do
                    local marker=""
                    local status="${COLORS[RED]}(not available)${COLORS[NC]}"
                    
                    if command -v "${PLAYERS[$player]}" &> /dev/null; then
                        status="${COLORS[GREEN]}(available)${COLORS[NC]}"
                    fi
                    
                    if [[ "$player" == "$PLAYER" ]]; then
                        marker=" ${COLORS[CYAN]}(current)${COLORS[NC]}"
                    fi
                    
                    echo -e "  ${COLORS[WHITE]}[$i]${COLORS[NC]} $player $status$marker"
                    ((i++))
                done
                echo ""
                echo -n -e "${COLORS[YELLOW]}Choose player [1-$((i-1))]: ${COLORS[NC]}"
                
                local choice=$(get_key)
                if [[ "$choice" =~ ^[1-9]$ ]]; then
                    local players_array=($(printf '%s\n' "${!PLAYERS[@]}" | sort))
                    local index=$((choice - 1))
                    if [[ $index -ge 0 && $index -lt ${#players_array[@]} ]]; then
                        local selected_player="${players_array[$index]}"
                        if command -v "${PLAYERS[$selected_player]}" &> /dev/null; then
                            PLAYER="$selected_player"
                            save_config
                            echo -e "\n${COLORS[GREEN]}Player set to: $PLAYER${COLORS[NC]}"
                        else
                            echo -e "\n${COLORS[RED]}Player $selected_player is not available${COLORS[NC]}"
                        fi
                        sleep 1
                    fi
                fi
                ;;
            "m"|"M")
                if [[ "$key" == "m" ]]; then
                    MODE=$([ "$MODE" == "sub" ] && echo "dub" || echo "sub")
                    save_config
                    echo -e "\n${COLORS[GREEN]}Mode set to: $MODE${COLORS[NC]}"
                else
                    MAL_INTEGRATION=$([ "$MAL_INTEGRATION" == "1" ] && echo "0" || echo "1")
                    save_config
                    echo -e "\n${COLORS[GREEN]}MAL integration: $([ "$MAL_INTEGRATION" == "1" ] && echo "enabled" || echo "disabled")${COLORS[NC]}"
                fi
                sleep 1
                ;;
            "s"|"S")
                SKIP_INTRO=$([ "$SKIP_INTRO" == "1" ] && echo "0" || echo "1")
                save_config
                echo -e "\n${COLORS[GREEN]}Skip intro: $([ "$SKIP_INTRO" == "1" ] && echo "enabled" || echo "disabled")${COLORS[NC]}"
                sleep 1
                ;;
            "a"|"A")
                AUTO_NEXT=$([ "$AUTO_NEXT" == "1" ] && echo "0" || echo "1")
                save_config
                echo -e "\n${COLORS[GREEN]}Auto-next episode: $([ "$AUTO_NEXT" == "1" ] && echo "enabled" || echo "disabled")${COLORS[NC]}"
                sleep 1
                ;;
            "n"|"N")
                NOTIFICATIONS=$([ "$NOTIFICATIONS" == "1" ] && echo "0" || echo "1")
                save_config
                echo -e "\n${COLORS[GREEN]}Notifications: $([ "$NOTIFICATIONS" == "1" ] && echo "enabled" || echo "disabled")${COLORS[NC]}"
                sleep 1
                ;;
            "r"|"R")
                if [[ "$key" == "r" ]]; then
                    RESUME_POSITION=$([ "$RESUME_POSITION" == "1" ] && echo "0" || echo "1")
                    save_config
                    echo -e "\n${COLORS[GREEN]}Resume position: $([ "$RESUME_POSITION" == "1" ] && echo "enabled" || echo "disabled")${COLORS[NC]}"
                    sleep 1
                else
                    echo -n -e "\n${COLORS[RED]}Reset all settings to defaults? [y/N]: ${COLORS[NC]}"
                    local confirm=$(get_key)
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        set_defaults
                        save_config
                        echo -e "\n${COLORS[GREEN]}Settings reset to defaults${COLORS[NC]}"
                        log "INFO" "Settings reset to defaults"
                    else
                        echo -e "\n${COLORS[YELLOW]}Reset cancelled${COLORS[NC]}"
                    fi
                    sleep 2
                fi
                ;;
            "d"|"D")
                echo -e "\n${COLORS[CYAN]}Current download directory: ${COLORS[YELLOW]}$DOWNLOAD_DIR${COLORS[NC]}"
                echo -n -e "${COLORS[YELLOW]}Enter new download directory: ${COLORS[NC]}"
                read -r new_dir
                if [[ -n "$new_dir" ]]; then
                    DOWNLOAD_DIR="${new_dir/#\~/$HOME}"
                    mkdir -p "$DOWNLOAD_DIR" 2>/dev/null
                    if [[ -d "$DOWNLOAD_DIR" ]]; then
                        save_config
                        echo -e "${COLORS[GREEN]}Download directory set to: $DOWNLOAD_DIR${COLORS[NC]}"
                        log "INFO" "Download directory changed to: $DOWNLOAD_DIR"
                    else
                        echo -e "${COLORS[RED]}Failed to create directory: $DOWNLOAD_DIR${COLORS[NC]}"
                    fi
                    sleep 2
                fi
                ;;
            "escape"|"q"|"Q")
                break
                ;;
        esac
    done
}

main() {
    # Initialize environment
    init_environment
    
    # Check dependencies
    check_dependencies
    
    # Load configuration
    load_config
    
    # Initialize MAL-CLI if enabled
    init_mal_cli
    
    # Log startup
    log "INFO" "ani-cli wrapper v$VERSION started"
    
    # Main loop
    while true; do
        clear
        show_status_bar
        echo ""
        
        echo -n -e "${COLORS[YELLOW]}Choose an option: ${COLORS[NC]}"
        
        local key=$(get_key)
        
        # Handle leader commands (ALT + key)
        if [[ "$key" =~ ^alt-(.)$ ]]; then
            handle_leader_command "${BASH_REMATCH[1]}"
            continue
        fi
        
        # Handle regular commands
        case "$key" in
            "s"|"S")
                search_and_watch
                ;;
            "c"|"C")
                continue_from_history
                ;;
            "d"|"D")
                download_episodes
                ;;
            "e"|"E")
                quick_episode
                ;;
            "b"|"B")
                browse_latest
                ;;
            "m"|"M")
                mal_integration
                ;;
            "u"|"U")
                handle_utilities
                ;;
            "o"|"O")
                options_menu
                ;;
            "h"|"H"|"?")
                show_help
                ;;
            "q"|"Q"|"escape")
                echo -e "\n${COLORS[GREEN]}Thank you for using ani-cli wrapper!${COLORS[NC]}"
                log "INFO" "ani-cli wrapper exited normally"
                notify "Ani-CLI" "Goodbye!" "dialog-information"
                exit 0
                ;;
            # Arrow key navigation (future enhancement)
            "up"|"down"|"left"|"right")
                echo -e "\n${COLORS[GRAY]}Arrow key navigation coming soon...${COLORS[NC]}"
                sleep 0.5
                ;;
            *)
                # Unknown key - show brief help
                echo -e "\n${COLORS[RED]}Unknown command: $key${COLORS[NC]}"
                echo -e "${COLORS[YELLOW]}Press 'h' for help or '?' for quick reference${COLORS[NC]}"
                sleep 1
                ;;
        esac
    done
}

# Command line argument handling
show_usage() {
    echo "Enhanced ani-cli Interactive Wrapper v$VERSION"
    echo ""
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo "  -c, --config   Show configuration file location"
    echo "  -l, --log      Show log file location"
    echo "  -r, --reset    Reset configuration to defaults"
    echo "  --check        Check dependencies"
    echo ""
    echo "Interactive Features:"
    echo "  • Enhanced UI with status bar and progress indicators"
    echo "  • MyAnimeList integration for better browsing"
    echo "  • Leader key system (ALT+key) for quick settings"
    echo "  • Auto-fallback from dub to sub when unavailable"
    echo "  • Download progress tracking and notifications"
    echo "  • Watch history and resume functionality"
    echo "  • Configurable quality presets and player options"
    echo ""
    echo "Key Commands:"
    echo "  Main: s(earch), c(ontinue), d(ownload), e(pisode), b(rowse)"
    echo "        m(al), u(tils), o(ptions), h(elp), q(uit)"
    echo "  Leader: ALT+1-8 (quality), ALT+p (player), ALT+m (mode)"
    echo "          ALT+i (skip), ALT+a (auto-next), ALT+? (help)"
    echo ""
    echo "Configuration: $CONFIG_FILE"
    echo "Logs: $LOG_FILE"
}

# Handle command line arguments
case "${1:-}" in
    "-h"|"--help")
        show_usage
        exit 0
        ;;
    "-v"|"--version")
        echo "ani-cli wrapper v$VERSION"
        echo "Dependencies:"
        command -v ani-cli >/dev/null && echo "  ✓ ani-cli $(ani-cli --version 2>/dev/null | head -1)" || echo "  ✗ ani-cli (not found)"
        command -v mal-cli >/dev/null && echo "  ✓ mal-cli" || echo "  ✗ mal-cli (optional)"
        command -v notify-send >/dev/null && echo "  ✓ notify-send" || echo "  ✗ notify-send (optional)"
        command -v rofi >/dev/null && echo "  ✓ rofi" || echo "  ✗ rofi (optional)"
        exit 0
        ;;
    "-c"|"--config")
        echo "Configuration file: $CONFIG_FILE"
        echo "MAL configuration: $MAL_CONFIG_FILE"
        echo "History file: $HISTORY_FILE"
        echo "Log file: $LOG_FILE"
        exit 0
        ;;
    "-l"|"--log")
        if [[ -f "$LOG_FILE" ]]; then
            echo "=== ani-cli wrapper log ==="
            tail -n 50 "$LOG_FILE"
        else
            echo "No log file found at: $LOG_FILE"
        fi
        exit 0
        ;;
    "-r"|"--reset")
        echo -n "Reset configuration to defaults? [y/N]: "
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -f "$CONFIG_FILE"
            echo "Configuration reset. Restart the wrapper to use defaults."
        else
            echo "Reset cancelled."
        fi
        exit 0
        ;;
    "--check")
        echo "Checking dependencies..."
        echo ""
        
        # Required
        echo "Required:"
        if command -v ani-cli >/dev/null; then
            echo "  ✓ ani-cli"
        else
            echo "  ✗ ani-cli (REQUIRED - install from https://github.com/pystardust/ani-cli)"
        fi
        
        # Optional
        echo ""
        echo "Optional:"
        command -v mal-cli >/dev/null && echo "  ✓ mal-cli" || echo "  ✗ mal-cli (for MyAnimeList integration)"
        command -v notify-send >/dev/null && echo "  ✓ notify-send" || echo "  ✗ notify-send (for notifications)"
        command -v rofi >/dev/null && echo "  ✓ rofi" || echo "  ✗ rofi (for enhanced menus)"
        
        # Players
        echo ""
        echo "Media Players:"
        for player in mpv vlc iina mplayer ffplay; do
            if command -v "$player" >/dev/null; then
                echo "  ✓ $player"
            else
                echo "  ✗ $player"
            fi
        done
        
        echo ""
        echo "Directories:"
        echo "  Config: $CONFIG_DIR $([ -d "$CONFIG_DIR" ] && echo "✓" || echo "✗")"
        echo "  MAL Config: $MAL_CONFIG_DIR $([ -d "$MAL_CONFIG_DIR" ] && echo "✓" || echo "✗")"
        
        exit 0
        ;;
    "")
        # No arguments - start interactive mode
        main
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
