#!/usr/bin/env bash

dir="$HOME/.config/rofi/launchers/type-3"
theme='style-1'

## Run Window
rofi \
    -show window \
    -theme ${dir}/${theme}.rasi \
    -kb-cancel "Super_L+space,Escape"
