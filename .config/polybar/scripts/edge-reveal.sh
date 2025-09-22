#!/usr/bin/env bash

last_state=hidden

while true; do
    eval $(xdotool getmouselocation --shell)
    if [ "$Y" -le 2 ]; then
        if [ "$last_state" != "shown" ]; then
            polybar-msg cmd show
            last_state=shown
        fi
    else
        if [ "$last_state" != "hidden" ]; then
            polybar-msg cmd hide
            last_state=hidden
        fi
    fi
    sleep 0.2
done

