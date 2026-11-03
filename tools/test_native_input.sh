#!/bin/bash
# Mouse and controller on the native build under Xvfb. Usage: tools/test_native_input.sh <exe> <outdir> (needs sudo for the virtual pad)
EXE=$1; O=$2; export DISPLAY=${DISPLAY:-:77}
shot(){ ffmpeg -hide_banner -v error -y -f x11grab -video_size 1280x720 -i "$DISPLAY" -frames:v 1 "$O/$1.png"; }
# --- mouse + keyboard: Create game with clicks, walk with WASD, look with the mouse
HC_NO_TRACK=1 stdbuf -oL "$EXE" -- --lobby=ws://127.0.0.1:8932 > "$O/mouse.log" 2>&1 &
P=$!; sleep 9; xdotool mousemove 230 352 click 1; sleep 3; shot m_create
xdotool key Return; sleep 1; xdotool mousemove 1100 660 click 1; sleep 20; shot m_game
xdotool mousemove 640 360 click 1; sleep 1; xdotool mousemove_relative -- 200 0; sleep 1; xdotool keydown w; sleep 2; xdotool keyup w; shot m_walk
kill $P; sleep 1
