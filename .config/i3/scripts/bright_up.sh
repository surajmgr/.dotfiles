#!/bin/bash
# Get current brightness
current=$(xrandr --verbose | grep -i brightness | cut -f2 -d ' ')
# Increase brightness by 0.1, cap at 1.0
new=$(echo "$current + 0.1" | bc)
if [ $(echo "$new > 1.0" | bc) -eq 1 ]; then
  new=1.0
fi
xrandr --output eDP-1 --brightness $new
