#!/bin/bash
# Get current brightness
current=$(xrandr --verbose | grep -i brightness | cut -f2 -d ' ')
# Decrease brightness by 0.1, floor at 0.2 to avoid blackout
new=$(echo "$current - 0.1" | bc)
if [ $(echo "$new < 0.2" | bc) -eq 1 ]; then
  new=0.2
fi
xrandr --output eDP-1 --brightness $new
