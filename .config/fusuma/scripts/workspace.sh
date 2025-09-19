#!/usr/bin/env bash
action="$1"
arg2="$2"
arg3="$3"
rofi_path="$HOME/.config/fusuma/scripts/rofi.sh"

case "$action" in
    first)
        ws=$(i3-msg -t get_workspaces | jq -r 'sort_by(.num) | .[0].name')
        i3-msg workspace "$ws"
        ;;

    last)
        ws=$(i3-msg -t get_workspaces | jq -r 'sort_by(.num) | .[-1].name')
        i3-msg workspace "$ws"
        ;;

    next)
        current=$(i3-msg -t get_workspaces | jq '.[] | select(.focused==true) | .num')
        max=$(i3-msg -t get_workspaces | jq '[.[] | .num] | max')
        if [[ $current -eq $max ]]; then
            next=$((max + 1))
        else
            next="next"
        fi
        i3-msg workspace "$next"
        ;;

    prev)
        i3-msg workspace "prev"
        ;;

    move)
        target_ws="$arg2"
        if [[ -n "$target_ws" ]]; then
          if [[ "$target_ws" == "next" ]]; then
            current_ws=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true) | .num')
            max_ws=$(i3-msg -t get_workspaces | jq '[.[] | .num] | max')
            if [[ $current_ws -eq $max_ws ]]; then
              target_ws=$((max_ws + 1))
            else
              target_ws="next"
            fi
          elif [[ "$target_ws" == "prev" ]]; then
            target_ws="prev"
          fi
          i3-msg move container to workspace "$target_ws"
          i3-msg workspace "$target_ws"
        else
            echo "Usage: $0 move <workspace>"
        fi
        ;;

    rofi)
        ws=$("$rofi_path" input "Go to workspace:" "Enter workspace number or name" "")
        [[ -n "$ws" ]] && i3-msg workspace "$ws"
        ;;

    rename)
        current_ws=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true) | .name')
        new_name=$("$rofi_path" input "Rename workspace:" "Current name: $current_ws" "$current_ws")
        if [[ -n "$new_name" && "$new_name" != "$current_ws" ]]; then
            i3-msg "rename workspace \"$current_ws\" to \"$new_name\""
        fi
        ;;

    *)
        echo "Usage: $0 {first|last|next|prev|rofi}"
        ;;
esac
