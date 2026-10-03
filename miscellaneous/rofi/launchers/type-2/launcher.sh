#!/usr/bin/env bash

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
#
## Rofi   : Launcher (Modi Drun, Run, File Browser, Window)
#
## Available Styles
#
## style-1     style-2     style-3     style-4     style-5
## style-6     style-7     style-8     style-9     style-10
## style-11    style-12    style-13    style-14    style-15

dir="$HOME/.config/rofi/launchers/type-2"
theme='style-4'

## Run
rofi \
    -show combi \
    -modi power-menu:rofi-power-menu \
    -font 'JetBrains Mono 16'\
    -combi-modes power-menu,window,drun\
    -kb-cancel 'Escape,Super+space' \
    -theme ${dir}/${theme}.rasi
