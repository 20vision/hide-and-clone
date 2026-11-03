#!/bin/bash
# Captures Store screenshots from the real game at 1920x1080 under Xvfb :78. Usage: tools/store_shots.sh <exe> <outdir>
EXE=$1; O=$2; export DISPLAY=:78 LIBGL_ALWAYS_SOFTWARE=1 HC_NO_TRACK=1 HC_HQ=1 HC_WEB=$PWD/web_extra/
shot(){ ffmpeg -hide_banner -v error -y -f x11grab -video_size 1920x1080 -i :78 -frames:v 1 "$O/$1.png"; }
R="--resolution 1920x1080 --position 0,0"
"$EXE" $R -- --lobby=ws://127.0.0.1:8932 >/dev/null 2>&1 & P=$!
sleep 12; xdotool mousemove 960 1050; shot menu
xdotool mousemove 340 528 click 1; sleep 5; xdotool mousemove 960 1050; shot create; xdotool key Escape; sleep 2
xdotool mousemove 340 640 click 1; sleep 12; xdotool mousemove 1300 500; shot builder; kill $P; sleep 1
"$EXE" $R -- --lobby=ws://127.0.0.1:8932 --auto=host --bots=5 --ai=1 --force=seeker --start=auto --hide=3 --map=2 >/dev/null 2>&1 & P=$!
sleep 14; xdotool mousemove 960 540 click 1; sleep 1; for i in 1 2 3 4 5 6 7 8; do shot seek$i; sleep 4; done; kill $P; sleep 1
"$EXE" $R -- --lobby=ws://127.0.0.1:8932 --auto=host --bots=5 --force=hider --start=auto --hide=50 --map=0 >/dev/null 2>&1 & P=$!
sleep 14; xdotool mousemove 960 540 click 1; sleep 1; shot lobby; sleep 14; xdotool keydown w; sleep 3; xdotool keyup w; sleep 4; for i in 1 2 3; do shot hide$i; xdotool keydown d; sleep 1; xdotool keyup d; sleep 4; done; xdotool keydown s; sleep 2; xdotool keyup s; sleep 4; for i in 4 5 6; do shot hide$i; xdotool mousemove_relative -- 180 0; sleep 3; done; kill $P
