#!/bin/bash
CM_LAUNCHER="rofi" CM_OUTPUT_CLIP=1 clipmenu -theme ~/.config/rofi/custom/clipmenu.rasi || exit 1

winclass=$(xdotool getactivewindow getwindowclassname)

case "$winclass" in
    sidepanel-term|Alacritty|URxvt|XTerm|Gnome-terminal|konsole)
        xdotool key Ctrl+Shift+v
        ;;
    *)
        xdotool key Ctrl+v
        ;;
esac
